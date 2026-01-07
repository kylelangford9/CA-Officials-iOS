//
//  Officials_VerificationState.swift
//  CA Officials
//
//  State machine for verification flow
//

import Foundation

/// State machine for the verification flow
/// Follows the CA Voters pattern from LocationRequestState
enum Officials_VerificationState: Equatable {
    case idle
    case searchingOffice
    case selectingMethod
    case awaitingCode
    case submittingCode
    case uploadingDocuments
    case awaitingReview
    case success
    case error(Officials_VerificationError)

    /// Whether the state indicates an in-progress operation
    var isInProgress: Bool {
        switch self {
        case .searchingOffice, .selectingMethod, .awaitingCode, .submittingCode, .uploadingDocuments:
            return true
        default:
            return false
        }
    }

    /// Whether the state indicates loading
    var isLoading: Bool {
        switch self {
        case .searchingOffice, .submittingCode, .uploadingDocuments:
            return true
        default:
            return false
        }
    }

    /// Whether the state is terminal (success or error)
    var isTerminal: Bool {
        switch self {
        case .success, .awaitingReview:
            return true
        case .error:
            return true
        default:
            return false
        }
    }

    /// Display title for the current state
    var title: String {
        switch self {
        case .idle:
            return "Get Verified"
        case .searchingOffice:
            return "Finding Your Office"
        case .selectingMethod:
            return "Choose Verification Method"
        case .awaitingCode:
            return "Enter Verification Code"
        case .submittingCode:
            return "Verifying Code"
        case .uploadingDocuments:
            return "Uploading Documents"
        case .awaitingReview:
            return "Under Review"
        case .success:
            return "Verification Complete"
        case .error:
            return "Verification Failed"
        }
    }

    /// Progress percentage (0-100)
    var progress: Int {
        switch self {
        case .idle:
            return 0
        case .searchingOffice:
            return 20
        case .selectingMethod:
            return 40
        case .awaitingCode, .uploadingDocuments:
            return 60
        case .submittingCode:
            return 80
        case .awaitingReview:
            return 90
        case .success:
            return 100
        case .error:
            return 0
        }
    }
}

/// Errors that can occur during verification
enum Officials_VerificationError: Equatable, Error {
    case networkError(String)
    case invalidCode
    case expiredCode
    case documentRejected(String)
    case officeAlreadyClaimed
    case officeNotFound
    case unauthorized
    case timeout
    case unknown(String)

    var message: String {
        switch self {
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidCode:
            return "Invalid verification code. Please check and try again."
        case .expiredCode:
            return "Verification code expired. Please request a new one."
        case .documentRejected(let reason):
            return "Document rejected: \(reason)"
        case .officeAlreadyClaimed:
            return "This office has already been claimed by another official."
        case .officeNotFound:
            return "Could not find the specified office."
        case .unauthorized:
            return "You are not authorized to claim this office."
        case .timeout:
            return "Request timed out. Please try again."
        case .unknown(let msg):
            return msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout:
            return true
        case .invalidCode, .expiredCode:
            return true
        default:
            return false
        }
    }
}

/// Verification method options
enum Officials_VerificationMethod: String, CaseIterable, Identifiable {
    case governmentEmail = "government_email"
    case websiteToken = "website_token"
    case documentUpload = "document_upload"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .governmentEmail:
            return "Government Email"
        case .websiteToken:
            return "Website Verification"
        case .documentUpload:
            return "Document Upload"
        }
    }

    var description: String {
        switch self {
        case .governmentEmail:
            return "Verify using your official .gov email address"
        case .websiteToken:
            return "Add a verification token to your official website"
        case .documentUpload:
            return "Upload official documentation for manual review"
        }
    }

    var icon: String {
        switch self {
        case .governmentEmail:
            return "envelope.badge.shield.half.filled"
        case .websiteToken:
            return "globe"
        case .documentUpload:
            return "doc.badge.plus"
        }
    }

    var estimatedTime: String {
        switch self {
        case .governmentEmail:
            return "Instant"
        case .websiteToken:
            return "1-2 hours"
        case .documentUpload:
            return "1-3 business days"
        }
    }

    var isInstant: Bool {
        self == .governmentEmail
    }
}
