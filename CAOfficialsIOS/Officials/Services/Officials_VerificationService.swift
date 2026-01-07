//
//  Officials_VerificationService.swift
//  CA Officials
//
//  Service for handling verification flow
//

import Foundation
import SwiftUI
import Supabase

/// Service for handling official verification
@MainActor
final class Officials_VerificationService: ObservableObject {
    static let shared = Officials_VerificationService()

    // MARK: - Published Properties

    @Published private(set) var state: Officials_VerificationState = .idle
    @Published private(set) var currentRequest: Officials_VerificationRequest?
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    private var verificationCode: String?
    private var codeExpiresAt: Date?

    private init() {
        #if DEBUG
        print("✅ [VerificationService] Initialized")
        #endif
    }

    // MARK: - Email Verification

    /// Send verification code to government email
    func sendVerificationCode(to email: String, officialId: UUID, officeId: UUID) async -> Bool {
        state = .submittingCode
        isLoading = true

        do {
            // Generate 6-digit code
            let code = String(format: "%06d", Int.random(in: 0...999999))
            let expiresAt = Date().addingTimeInterval(15 * 60) // 15 minutes

            // Store verification request
            let request = CreateVerificationRequest(
                officialId: officialId,
                officeId: officeId,
                method: "government_email",
                status: "pending",
                verificationCode: code,
                codeExpiresAt: expiresAt,
                verificationEmail: email
            )

            let response: Officials_VerificationRequest = try await supabase
                .from("verification_requests")
                .insert(request)
                .select()
                .single()
                .execute()
                .value

            currentRequest = response
            verificationCode = code
            codeExpiresAt = expiresAt

            // In production, this would trigger an Edge Function to send email
            // For now, we store the code locally for testing
            #if DEBUG
            print("✅ [VerificationService] Code sent to \(email): \(code)")
            #endif

            state = .awaitingCode
            isLoading = false
            return true

        } catch {
            #if DEBUG
            print("✅ [VerificationService] Error sending code: \(error.localizedDescription)")
            #endif
            state = .error(.networkError(error.localizedDescription))
            isLoading = false
            return false
        }
    }

    /// Verify the entered code
    func verifyCode(_ enteredCode: String) async -> Bool {
        state = .submittingCode
        isLoading = true

        // Check expiration
        if let expiresAt = codeExpiresAt, Date() > expiresAt {
            state = .error(.expiredCode)
            isLoading = false
            return false
        }

        // Verify code
        guard let storedCode = verificationCode, enteredCode == storedCode else {
            state = .error(.invalidCode)
            isLoading = false
            return false
        }

        // Update verification request status
        guard let requestId = currentRequest?.id else {
            state = .error(.unknown("No verification request found"))
            isLoading = false
            return false
        }

        do {
            // Update request to verified
            try await supabase
                .from("verification_requests")
                .update(["status": "verified", "reviewed_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: requestId.uuidString)
                .execute()

            // Update official status
            if let officialId = currentRequest?.officialId {
                try await supabase
                    .from("officials")
                    .update([
                        "verification_status": "verified",
                        "verified_at": ISO8601DateFormatter().string(from: Date()),
                        "verification_method": "government_email"
                    ])
                    .eq("id", value: officialId.uuidString)
                    .execute()
            }

            state = .success
            isLoading = false

            #if DEBUG
            print("✅ [VerificationService] Verification successful")
            #endif

            return true

        } catch {
            state = .error(.networkError(error.localizedDescription))
            isLoading = false
            return false
        }
    }

    // MARK: - Document Verification

    /// Submit documents for manual review
    func submitDocuments(
        officialId: UUID,
        officeId: UUID,
        documentUrls: [String],
        documentTypes: [String]
    ) async -> Bool {
        state = .uploadingDocuments
        isLoading = true

        do {
            let request = CreateVerificationRequest(
                officialId: officialId,
                officeId: officeId,
                method: "document_upload",
                status: "pending",
                documentUrls: documentUrls,
                documentTypes: documentTypes
            )

            let response: Officials_VerificationRequest = try await supabase
                .from("verification_requests")
                .insert(request)
                .select()
                .single()
                .execute()
                .value

            currentRequest = response

            // Update official status to pending
            try await supabase
                .from("officials")
                .update(["verification_status": "pending"])
                .eq("id", value: officialId.uuidString)
                .execute()

            state = .awaitingReview
            isLoading = false

            #if DEBUG
            print("✅ [VerificationService] Documents submitted for review")
            #endif

            return true

        } catch {
            state = .error(.networkError(error.localizedDescription))
            isLoading = false
            return false
        }
    }

    /// Upload a document to storage
    func uploadDocument(imageData: Data, officialId: UUID, index: Int) async -> String? {
        do {
            let fileName = "\(officialId.uuidString)/doc_\(index)_\(Date().timeIntervalSince1970).jpg"

            try await supabase.storage
                .from("verification-documents")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )

            let publicURL = try supabase.storage
                .from("verification-documents")
                .getPublicURL(path: fileName)

            return publicURL.absoluteString

        } catch {
            #if DEBUG
            print("✅ [VerificationService] Error uploading document: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Website Verification

    /// Generate website verification token
    func generateWebsiteToken(officialId: UUID, officeId: UUID, websiteUrl: String) async -> String? {
        let token = UUID().uuidString.prefix(8).uppercased()

        do {
            let request = CreateVerificationRequest(
                officialId: officialId,
                officeId: officeId,
                method: "website_token",
                status: "pending",
                websiteToken: String(token),
                websiteUrl: websiteUrl
            )

            let response: Officials_VerificationRequest = try await supabase
                .from("verification_requests")
                .insert(request)
                .select()
                .single()
                .execute()
                .value

            currentRequest = response
            state = .awaitingCode

            return String(token)

        } catch {
            #if DEBUG
            print("✅ [VerificationService] Error generating token: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Verify website token
    func verifyWebsiteToken(websiteUrl: String, token: String) async -> Bool {
        state = .submittingCode
        isLoading = true

        // In production, this would:
        // 1. Fetch the website HTML
        // 2. Parse and find the meta tag
        // 3. Verify the token matches

        // For demo, simulate verification
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            // Update request and official status
            if let requestId = currentRequest?.id {
                try await supabase
                    .from("verification_requests")
                    .update(["status": "pending", "reviewed_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: requestId.uuidString)
                    .execute()
            }

            if let officialId = currentRequest?.officialId {
                try await supabase
                    .from("officials")
                    .update(["verification_status": "pending"])
                    .eq("id", value: officialId.uuidString)
                    .execute()
            }

            state = .awaitingReview
            isLoading = false
            return true

        } catch {
            state = .error(.networkError(error.localizedDescription))
            isLoading = false
            return false
        }
    }

    // MARK: - Status Check

    /// Check verification status
    func checkVerificationStatus(officialId: UUID) async -> VerificationStatus {
        do {
            let response: Officials_Official = try await supabase
                .from("officials")
                .select("verification_status")
                .eq("id", value: officialId.uuidString)
                .single()
                .execute()
                .value

            return VerificationStatus(rawValue: response.verificationStatus) ?? .unverified

        } catch {
            return .unverified
        }
    }

    /// Reset verification state
    func reset() {
        state = .idle
        currentRequest = nil
        verificationCode = nil
        codeExpiresAt = nil
        isLoading = false
    }
}

// MARK: - Request Types

struct CreateVerificationRequest: Encodable {
    let officialId: UUID
    let officeId: UUID
    let method: String
    let status: String
    var verificationCode: String?
    var codeExpiresAt: Date?
    var verificationEmail: String?
    var websiteToken: String?
    var websiteUrl: String?
    var documentUrls: [String]?
    var documentTypes: [String]?

    enum CodingKeys: String, CodingKey {
        case officialId = "official_id"
        case officeId = "office_id"
        case method, status
        case verificationCode = "verification_code"
        case codeExpiresAt = "code_expires_at"
        case verificationEmail = "verification_email"
        case websiteToken = "website_token"
        case websiteUrl = "website_url"
        case documentUrls = "document_urls"
        case documentTypes = "document_types"
    }
}

// MARK: - Verification Request Model

struct Officials_VerificationRequest: Codable, Identifiable {
    let id: UUID
    let officialId: UUID
    let officeId: UUID?
    let method: String
    let status: String
    var verificationCode: String?
    var codeExpiresAt: Date?
    var verificationEmail: String?
    var websiteToken: String?
    var websiteUrl: String?
    var documentUrls: [String]?
    var documentTypes: [String]?
    var submittedAt: Date?
    var reviewedAt: Date?
    var reviewerNotes: String?
    var rejectionReason: String?
    var attemptCount: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case officialId = "official_id"
        case officeId = "office_id"
        case method, status
        case verificationCode = "verification_code"
        case codeExpiresAt = "code_expires_at"
        case verificationEmail = "verification_email"
        case websiteToken = "website_token"
        case websiteUrl = "website_url"
        case documentUrls = "document_urls"
        case documentTypes = "document_types"
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case reviewerNotes = "reviewer_notes"
        case rejectionReason = "rejection_reason"
        case attemptCount = "attempt_count"
        case createdAt = "created_at"
    }
}
