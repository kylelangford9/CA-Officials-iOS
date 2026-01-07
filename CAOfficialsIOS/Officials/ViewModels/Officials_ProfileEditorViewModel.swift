//
//  Officials_ProfileEditorViewModel.swift
//  CA Officials
//
//  ViewModel for the profile editor
//

import Foundation
import SwiftUI
import PhotosUI
import Combine

@MainActor
final class Officials_ProfileEditorViewModel: ObservableObject {

    // MARK: - Published Properties

    // Basic Info
    @Published var name = ""
    @Published var title = ""
    @Published var bio = ""
    @Published var party = ""

    // Photo
    @Published var photoItem: PhotosPickerItem?
    @Published var photoImage: UIImage?
    @Published var photoUrl: String?
    @Published var isUploadingPhoto = false

    // Contact Info
    @Published var email = ""
    @Published var phone = ""
    @Published var officeAddress = ""
    @Published var mailingAddress = ""

    // Social Links
    @Published var twitter = ""
    @Published var facebook = ""
    @Published var instagram = ""
    @Published var linkedin = ""
    @Published var youtube = ""
    @Published var website = ""

    // Policy Positions
    @Published var policyPositions: [Officials_PolicyPosition] = []
    @Published var isLoadingPositions = false

    // State
    @Published var hasChanges = false
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var showingSaveSuccess = false

    // MARK: - Services

    private let profileService = Officials_ProfileService.shared

    private var cancellables = Set<AnyCancellable>()
    private var originalProfile: Officials_Official?

    // MARK: - Computed Properties

    var canSave: Bool {
        hasChanges && !name.isEmpty && !isSaving
    }

    var bioCharacterCount: Int {
        bio.count
    }

    var bioCharacterLimit: Int {
        500
    }

    var isBioValid: Bool {
        bioCharacterCount <= bioCharacterLimit
    }

    var availableParties: [String] {
        ["Democratic", "Republican", "Independent", "Libertarian", "Green", "Nonpartisan", "Other"]
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Track changes to any field
        Publishers.CombineLatest4(
            $name, $title, $bio, $party
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.checkForChanges()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $email, $phone, $officeAddress, $mailingAddress
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.checkForChanges()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $twitter, $facebook, $instagram, $linkedin
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.checkForChanges()
        }
        .store(in: &cancellables)

        // Handle photo selection
        $photoItem
            .compactMap { $0 }
            .sink { [weak self] item in
                Task { await self?.loadPhoto(from: item) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Profile

    func loadProfile() async {
        guard let profile = profileService.profile else {
            await profileService.fetchProfile()
            if let profile = profileService.profile {
                populateFromProfile(profile)
            }
            return
        }

        populateFromProfile(profile)
    }

    private func populateFromProfile(_ profile: Officials_Official) {
        originalProfile = profile

        name = profile.name
        title = profile.title ?? ""
        bio = profile.bio ?? ""
        party = profile.party ?? ""
        photoUrl = profile.photoUrl

        // Contact info
        if let contact = profile.contactInfo {
            email = contact.officeEmail ?? ""
            phone = contact.officePhone ?? ""
            officeAddress = contact.officeAddress ?? ""
            mailingAddress = contact.mailingAddress ?? ""
        }

        // Social links
        if let social = profile.socialLinks {
            website = social.websiteUrl ?? ""
            twitter = social.twitterHandle ?? ""
            facebook = social.facebookUrl ?? ""
            instagram = social.instagramHandle ?? ""
            linkedin = social.linkedinUrl ?? ""
            youtube = social.youtubeUrl ?? ""
        }

        hasChanges = false
    }

    // MARK: - Photo Handling

    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photoImage = image
                hasChanges = true
            }
        } catch {
            #if DEBUG
            print("[ProfileEditorVM] Error loading photo: \(error)")
            #endif
        }
    }

    func removePhoto() {
        photoImage = nil
        photoItem = nil
        photoUrl = nil
        hasChanges = true
    }

    private func uploadPhotoIfNeeded() async -> String? {
        guard let image = photoImage,
              let data = image.jpegData(compressionQuality: 0.8) else {
            return photoUrl
        }

        isUploadingPhoto = true
        let url = await profileService.uploadProfilePhoto(data)
        isUploadingPhoto = false

        return url
    }

    // MARK: - Save Profile

    func saveProfile() async {
        guard canSave else { return }

        isSaving = true
        saveError = nil

        // Upload photo first if changed
        let finalPhotoUrl = await uploadPhotoIfNeeded()

        // Build contact info
        let contactInfo = Officials_Official.ContactInfo(
            officePhone: phone.isEmpty ? nil : phone,
            officeEmail: email.isEmpty ? nil : email,
            officeAddress: officeAddress.isEmpty ? nil : officeAddress,
            mailingAddress: mailingAddress.isEmpty ? nil : mailingAddress
        )

        // Build social links
        let socialLinks = Officials_Official.SocialLinks(
            websiteUrl: website.isEmpty ? nil : website,
            twitterHandle: twitter.isEmpty ? nil : twitter,
            facebookUrl: facebook.isEmpty ? nil : facebook,
            instagramHandle: instagram.isEmpty ? nil : instagram,
            linkedinUrl: linkedin.isEmpty ? nil : linkedin,
            youtubeUrl: youtube.isEmpty ? nil : youtube
        )

        // Update profile
        let success = await profileService.updateProfile(
            name: name,
            title: title.isEmpty ? nil : title,
            bio: bio.isEmpty ? nil : bio,
            party: party.isEmpty ? nil : party,
            photoUrl: finalPhotoUrl,
            contactInfo: contactInfo,
            socialLinks: socialLinks
        )

        isSaving = false

        if success {
            hasChanges = false
            showingSaveSuccess = true
            HapticManager.shared.success()

            // Update original profile reference
            if let profile = profileService.profile {
                originalProfile = profile
            }
        } else {
            saveError = profileService.error ?? "Failed to save profile"
            HapticManager.shared.error()
        }
    }

    // MARK: - Policy Positions

    func loadPolicyPositions() async {
        guard let profile = profileService.profile else { return }

        isLoadingPositions = true
        policyPositions = await profileService.fetchPolicyPositions(officialId: profile.id)
        isLoadingPositions = false
    }

    func addPolicyPosition(topic: String, stance: String, description: String) async {
        guard let profile = profileService.profile else { return }

        let position = await profileService.addPolicyPosition(
            officialId: profile.id,
            topic: topic,
            stance: stance,
            description: description
        )

        if let position = position {
            policyPositions.append(position)
            HapticManager.shared.success()
        } else {
            HapticManager.shared.error()
        }
    }

    func deletePolicyPosition(at offsets: IndexSet) async {
        for index in offsets {
            let position = policyPositions[index]
            let success = await profileService.deletePolicyPosition(id: position.id)

            if success {
                policyPositions.remove(at: index)
            }
        }
    }

    // MARK: - Helpers

    private func checkForChanges() {
        guard let original = originalProfile else {
            hasChanges = !name.isEmpty
            return
        }

        hasChanges =
            name != original.name ||
            title != (original.title ?? "") ||
            bio != (original.bio ?? "") ||
            party != (original.party ?? "") ||
            email != (original.contactInfo?.officeEmail ?? "") ||
            phone != (original.contactInfo?.officePhone ?? "") ||
            officeAddress != (original.contactInfo?.officeAddress ?? "") ||
            mailingAddress != (original.contactInfo?.mailingAddress ?? "") ||
            twitter != (original.socialLinks?.twitterHandle ?? "") ||
            facebook != (original.socialLinks?.facebookUrl ?? "") ||
            instagram != (original.socialLinks?.instagramHandle ?? "") ||
            linkedin != (original.socialLinks?.linkedinUrl ?? "") ||
            youtube != (original.socialLinks?.youtubeUrl ?? "") ||
            website != (original.socialLinks?.websiteUrl ?? "") ||
            photoImage != nil
    }

    func discardChanges() {
        if let original = originalProfile {
            populateFromProfile(original)
        }
        photoImage = nil
        photoItem = nil
    }

    // MARK: - Validation

    func validateEmail() -> Bool {
        guard !email.isEmpty else { return true }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    func validatePhone() -> Bool {
        guard !phone.isEmpty else { return true }
        let digitsOnly = phone.filter { $0.isNumber }
        return digitsOnly.count >= 10
    }

    func validateWebsite() -> Bool {
        guard !website.isEmpty else { return true }
        return URL(string: website) != nil
    }

    func validateSocialHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty else { return true }
        // Remove @ if present and check for valid characters
        let cleanHandle = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return cleanHandle.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }
}
