//
//  Officials_VerificationViewModel.swift
//  CA Officials
//
//  ViewModel for the verification flow
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class Officials_VerificationViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var state: Officials_VerificationState = .idle
    @Published var selectedOffice: Officials_GovernmentOffice?
    @Published var selectedMethod: Officials_VerificationMethod?

    // Office search
    @Published var searchQuery = ""
    @Published var searchResults: [Officials_GovernmentOffice] = []
    @Published var isSearching = false

    // Email verification
    @Published var verificationCode = ""
    @Published var canResendCode = false
    @Published var resendCountdown = 0

    // Document upload
    @Published var selectedDocumentType: DocumentType = .governmentId
    @Published var uploadedDocumentUrl: String?
    @Published var documentNotes = ""

    // Website verification
    @Published var websiteToken = ""

    // Profile completion
    @Published var profileName = ""
    @Published var profileTitle = ""
    @Published var profileBio = ""

    @Published var errorMessage: String?

    enum DocumentType: String, CaseIterable {
        case governmentId = "Government ID"
        case officialLetter = "Official Letter"
        case electionCertificate = "Election Certificate"
        case appointmentDocument = "Appointment Document"

        var description: String {
            switch self {
            case .governmentId:
                return "A government-issued photo ID"
            case .officialLetter:
                return "Official letterhead from your office"
            case .electionCertificate:
                return "Certificate of election"
            case .appointmentDocument:
                return "Official appointment documentation"
            }
        }
    }

    // MARK: - Services

    private let verificationService = Officials_VerificationService.shared
    private let officeSearchService = Officials_OfficeSearchService.shared
    private let profileService = Officials_ProfileService.shared

    private var searchTask: Task<Void, Never>?
    private var resendTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var currentStep: Int {
        switch state {
        case .idle, .searchingOffice: return 1
        case .selectingMethod: return 2
        case .awaitingCode, .submittingCode, .uploadingDocuments: return 3
        case .awaitingReview: return 4
        case .success: return 5
        case .error: return 0
        }
    }

    var totalSteps: Int { 4 }

    var canProceed: Bool {
        switch state {
        case .idle, .searchingOffice:
            return selectedOffice != nil
        case .selectingMethod:
            return selectedMethod != nil
        case .awaitingCode:
            return verificationCode.count >= 6
        case .submittingCode, .uploadingDocuments:
            return false
        default:
            return true
        }
    }

    var availableMethods: [Officials_VerificationMethod] {
        guard let office = selectedOffice else { return [] }

        var methods: [Officials_VerificationMethod] = []

        // Government email is always available (they'll need to provide it)
        methods.append(.governmentEmail)

        // Website verification if office has website
        if let website = office.websiteUrl, !website.isEmpty {
            methods.append(.websiteToken)
        }

        // Document upload is always available as fallback
        methods.append(.documentUpload)

        return methods
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { await self?.performSearch(query) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Office Search

    func performSearch(_ query: String) async {
        guard !query.isEmpty, query.count >= 2 else {
            searchResults = []
            return
        }

        searchTask?.cancel()

        searchTask = Task {
            isSearching = true
            state = .searchingOffice

            await officeSearchService.search(query: query)
            searchResults = officeSearchService.searchResults

            isSearching = false

            if searchResults.isEmpty {
                state = .idle
            }
        }
    }

    func selectOffice(_ office: Officials_GovernmentOffice) {
        selectedOffice = office
        HapticManager.shared.selectionChanged()

        #if DEBUG
        print("[VerificationVM] Selected office: \(office.title)")
        #endif
    }

    func proceedToMethodSelection() {
        guard selectedOffice != nil else { return }
        state = .selectingMethod
        HapticManager.shared.light()
    }

    // MARK: - Method Selection

    func selectMethod(_ method: Officials_VerificationMethod) {
        selectedMethod = method
        HapticManager.shared.selectionChanged()

        #if DEBUG
        print("[VerificationVM] Selected method: \(method)")
        #endif
    }

    func proceedWithSelectedMethod() async {
        guard let method = selectedMethod, let office = selectedOffice else { return }

        state = .submittingCode
        errorMessage = nil

        switch method {
        case .governmentEmail:
            await initiateEmailVerification(office: office)
        case .websiteToken:
            await initiateWebsiteVerification(office: office)
        case .documentUpload:
            state = .uploadingDocuments
        }
    }

    // MARK: - Email Verification

    private func initiateEmailVerification(office: Officials_GovernmentOffice) async {
        guard let userId = await getCurrentUserId() else {
            errorMessage = "Not authenticated"
            state = .error(.unauthorized)
            return
        }

        // Construct an email domain based on jurisdiction
        let domain = office.jurisdiction.lowercased().replacingOccurrences(of: " ", with: "")
        let email = "official@\(domain).ca.gov"

        let success = await verificationService.sendVerificationCode(
            to: email,
            officialId: userId,
            officeId: office.id
        )

        if success {
            state = .awaitingCode
            startResendCountdown()
            HapticManager.shared.success()
        } else {
            errorMessage = "Failed to send verification code"
            state = .error(.networkError(errorMessage ?? "Unknown error"))
            HapticManager.shared.error()
        }
    }

    func verifyEmailCode() async {
        guard verificationCode.count >= 6, selectedOffice != nil else { return }
        guard await getCurrentUserId() != nil else { return }

        state = .submittingCode
        errorMessage = nil

        let success = await verificationService.verifyCode(verificationCode)

        if success {
            await completeVerification()
        } else {
            errorMessage = "Invalid verification code"
            state = .error(.invalidCode)
            HapticManager.shared.error()
        }
    }

    func resendVerificationCode() async {
        guard canResendCode, let office = selectedOffice else { return }
        guard let userId = await getCurrentUserId() else { return }

        canResendCode = false

        // Construct an email domain based on jurisdiction
        let domain = office.jurisdiction.lowercased().replacingOccurrences(of: " ", with: "")
        let email = "official@\(domain).ca.gov"

        let success = await verificationService.sendVerificationCode(
            to: email,
            officialId: userId,
            officeId: office.id
        )

        if success {
            startResendCountdown()
            HapticManager.shared.success()
        } else {
            canResendCode = true
            HapticManager.shared.error()
        }
    }

    private func startResendCountdown() {
        resendCountdown = 60
        canResendCode = false

        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                self.resendCountdown -= 1

                if self.resendCountdown <= 0 {
                    timer.invalidate()
                    self.canResendCode = true
                }
            }
        }
    }

    // MARK: - Website Verification

    private func initiateWebsiteVerification(office: Officials_GovernmentOffice) async {
        guard let userId = await getCurrentUserId() else {
            errorMessage = "Not authenticated"
            state = .error(.unauthorized)
            return
        }

        if let token = await verificationService.generateWebsiteToken(
            officialId: userId,
            officeId: office.id,
            websiteUrl: office.websiteUrl ?? ""
        ) {
            websiteToken = token
            state = .awaitingCode
        } else {
            errorMessage = "Failed to generate verification token"
            state = .error(.networkError(errorMessage!))
            HapticManager.shared.error()
        }
    }

    func verifyWebsiteToken() async {
        guard let office = selectedOffice else { return }
        guard await getCurrentUserId() != nil else { return }

        state = .submittingCode
        errorMessage = nil

        let success = await verificationService.verifyWebsiteToken(
            websiteUrl: office.websiteUrl ?? "",
            token: websiteToken
        )

        if success {
            await completeVerification()
        } else {
            errorMessage = "Token not found on website. Please ensure you've added it correctly."
            state = .error(.networkError(errorMessage!))
            HapticManager.shared.error()
        }
    }

    // MARK: - Document Verification

    func uploadDocument(imageData: Data) async {
        guard selectedOffice != nil else { return }
        guard let userId = await getCurrentUserId() else { return }

        state = .uploadingDocuments
        errorMessage = nil

        let url = await verificationService.uploadDocument(
            imageData: imageData,
            officialId: userId,
            index: 0  // First document
        )

        if let url = url {
            uploadedDocumentUrl = url
            state = .awaitingReview
            HapticManager.shared.success()
        } else {
            errorMessage = "Failed to upload document"
            state = .error(.networkError(errorMessage!))
            HapticManager.shared.error()
        }
    }

    // MARK: - Complete Verification

    private func completeVerification() async {
        state = .success
        HapticManager.shared.success()

        // Refresh profile
        await profileService.fetchProfile()
    }

    // MARK: - Profile Completion

    func completeProfile() async {
        guard !profileName.isEmpty else {
            errorMessage = "Please enter your name"
            return
        }

        state = .submittingCode

        let success = await profileService.updateProfile(
            name: profileName,
            title: profileTitle.isEmpty ? nil : profileTitle,
            bio: profileBio.isEmpty ? nil : profileBio
        )

        if success {
            await completeVerification()
        } else {
            errorMessage = "Failed to update profile"
            state = .error(.networkError(errorMessage!))
            HapticManager.shared.error()
        }
    }

    // MARK: - Navigation

    func goBack() {
        switch state {
        case .selectingMethod:
            state = .idle
            selectedOffice = nil
        case .awaitingCode, .uploadingDocuments:
            state = .selectingMethod
            verificationCode = ""
        case .error:
            if selectedMethod != nil {
                state = .selectingMethod
            } else {
                state = .idle
            }
        default:
            break
        }

        errorMessage = nil
        HapticManager.shared.light()
    }

    func reset() {
        state = .idle
        selectedOffice = nil
        selectedMethod = nil
        searchQuery = ""
        searchResults = []
        verificationCode = ""
        uploadedDocumentUrl = nil
        documentNotes = ""
        websiteToken = ""
        errorMessage = nil

        resendTimer?.invalidate()
        searchTask?.cancel()
    }

    // MARK: - Helpers

    private func getCurrentUserId() async -> UUID? {
        // In a real app, this would get from auth service
        // For now, return from RoleManager or create profile
        return nil
    }

    deinit {
        resendTimer?.invalidate()
        searchTask?.cancel()
    }
}
