//
//  Officials_ProfileService.swift
//  CA Officials
//
//  Service for managing official profiles
//

import Foundation
import SwiftUI
import Supabase

/// Service for managing official profiles
/// Follows CA Voters singleton pattern
@MainActor
final class Officials_ProfileService: ObservableObject {
    static let shared = Officials_ProfileService()

    // MARK: - Published Properties

    @Published private(set) var currentProfile: Officials_Official?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    /// Alias for currentProfile (used by ViewModels)
    var profile: Officials_Official? {
        currentProfile
    }

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    private init() {
        #if DEBUG
        print("📋 [ProfileService] Initialized")
        #endif
    }

    // MARK: - Profile CRUD

    /// Fetch the current user's official profile (alias)
    func fetchProfile() async {
        await fetchCurrentProfile()
    }

    /// Fetch the current user's official profile
    func fetchCurrentProfile() async {
        guard let userId = await getCurrentUserId() else {
            #if DEBUG
            print("📋 [ProfileService] No authenticated user")
            #endif
            return
        }

        isLoading = true
        error = nil

        do {
            let response: Officials_Official = try await supabase
                .from("officials")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            currentProfile = response
            #if DEBUG
            print("📋 [ProfileService] Profile fetched: \(response.name)")
            #endif
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error fetching profile: \(error.localizedDescription)")
            #endif
            // Profile may not exist yet
            self.error = nil
            self.currentProfile = nil
        }

        isLoading = false
    }

    /// Fetch a profile by ID
    func fetchProfile(id: UUID) async -> Officials_Official? {
        do {
            let response: Officials_Official = try await supabase
                .from("officials")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            return response
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error fetching profile \(id): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetch an official by ID (alias for fetchProfile)
    func fetchOfficialById(_ id: UUID) async -> Officials_Official? {
        return await fetchProfile(id: id)
    }

    /// Create a new official profile
    func createProfile(name: String, officeId: UUID?) async -> Officials_Official? {
        guard let userId = await getCurrentUserId() else {
            error = "Not authenticated"
            return nil
        }

        isLoading = true
        error = nil

        do {
            let newProfile = CreateOfficialRequest(
                userId: userId,
                officeId: officeId,
                name: name,
                verificationStatus: "unverified",
                isActive: true
            )

            let response: Officials_Official = try await supabase
                .from("officials")
                .insert(newProfile)
                .select()
                .single()
                .execute()
                .value

            currentProfile = response
            isLoading = false

            #if DEBUG
            print("📋 [ProfileService] Profile created: \(response.id)")
            #endif

            return response
        } catch {
            self.error = error.localizedDescription
            isLoading = false

            #if DEBUG
            print("📋 [ProfileService] Error creating profile: \(error.localizedDescription)")
            #endif

            return nil
        }
    }

    /// Update the current profile
    func updateProfile(_ updates: ProfileUpdateRequest) async -> Bool {
        guard let profileId = currentProfile?.id else {
            error = "No profile to update"
            return false
        }

        isLoading = true
        error = nil

        do {
            let response: Officials_Official = try await supabase
                .from("officials")
                .update(updates)
                .eq("id", value: profileId.uuidString)
                .select()
                .single()
                .execute()
                .value

            currentProfile = response
            isLoading = false

            #if DEBUG
            print("📋 [ProfileService] Profile updated")
            #endif

            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false

            #if DEBUG
            print("📋 [ProfileService] Error updating profile: \(error.localizedDescription)")
            #endif

            return false
        }
    }

    /// Update profile with individual parameters (convenience method)
    func updateProfile(
        name: String? = nil,
        title: String? = nil,
        bio: String? = nil,
        party: String? = nil,
        photoUrl: String? = nil,
        websiteUrl: String? = nil,
        contactInfo: Officials_Official.ContactInfo? = nil,
        socialLinks: Officials_Official.SocialLinks? = nil
    ) async -> Bool {
        var updates = ProfileUpdateRequest()
        updates.name = name
        updates.title = title
        updates.bio = bio
        updates.party = party
        updates.photoUrl = photoUrl

        if let contactInfo = contactInfo {
            updates.contactInfo = contactInfo
        }
        if let socialLinks = socialLinks {
            updates.socialLinks = socialLinks
        }

        return await updateProfile(updates)
    }

    /// Update profile photo
    func updatePhoto(imageData: Data) async -> String? {
        guard let profileId = currentProfile?.id else {
            return nil
        }

        do {
            let fileName = "\(profileId.uuidString)/profile.jpg"

            // Upload to Supabase Storage
            try await supabase.storage
                .from("official-photos")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            // Get public URL
            let publicURL = try supabase.storage
                .from("official-photos")
                .getPublicURL(path: fileName)

            // Update profile with new URL
            let updates = ProfileUpdateRequest(photoUrl: publicURL.absoluteString)
            _ = await updateProfile(updates)

            return publicURL.absoluteString
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error uploading photo: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Upload profile photo (alias)
    func uploadProfilePhoto(_ imageData: Data) async -> String? {
        return await updatePhoto(imageData: imageData)
    }

    // MARK: - Policy Positions

    /// Fetch policy positions for a profile
    func fetchPolicyPositions(officialId: UUID) async -> [Officials_PolicyPosition] {
        do {
            let response: [Officials_PolicyPosition] = try await supabase
                .from("policy_positions")
                .select()
                .eq("official_id", value: officialId.uuidString)
                .order("display_order")
                .execute()
                .value

            return response
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error fetching policy positions: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Add or update a policy position
    func savePolicyPosition(_ position: Officials_PolicyPosition) async -> Bool {
        do {
            try await supabase
                .from("policy_positions")
                .upsert(position)
                .execute()

            return true
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error saving policy position: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Add a new policy position
    func addPolicyPosition(
        officialId: UUID,
        topic: String,
        stance: String,
        description: String
    ) async -> Officials_PolicyPosition? {
        do {
            let request = AddPolicyPositionRequest(
                officialId: officialId,
                topic: topic,
                stance: stance,
                summary: description,
                isFeatured: false,
                displayOrder: 0
            )

            let response: Officials_PolicyPosition = try await supabase
                .from("policy_positions")
                .insert(request)
                .select()
                .single()
                .execute()
                .value

            return response
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error adding policy position: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Delete a policy position
    func deletePolicyPosition(id: UUID) async -> Bool {
        do {
            try await supabase
                .from("policy_positions")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            return true
        } catch {
            #if DEBUG
            print("📋 [ProfileService] Error deleting policy position: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Cache Management

    /// Clear all cached data (call on sign out)
    func clearCache() {
        currentProfile = nil
        error = nil
        isLoading = false

        #if DEBUG
        print("📋 [ProfileService] Cache cleared")
        #endif
    }

    // MARK: - Helpers

    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            return nil
        }
    }
}

// MARK: - Request Types

struct CreateOfficialRequest: Encodable {
    let userId: UUID
    let officeId: UUID?
    let name: String
    let verificationStatus: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case officeId = "office_id"
        case name
        case verificationStatus = "verification_status"
        case isActive = "is_active"
    }
}

struct ProfileUpdateRequest: Encodable {
    var name: String?
    var title: String?
    var bio: String?
    var pronouns: String?
    var party: String?
    var photoUrl: String?
    var bannerUrl: String?
    var contactInfo: Officials_Official.ContactInfo?
    var socialLinks: Officials_Official.SocialLinks?

    enum CodingKeys: String, CodingKey {
        case name, title, bio, pronouns, party
        case photoUrl = "photo_url"
        case bannerUrl = "banner_url"
        case contactInfo = "contact_info"
        case socialLinks = "social_links"
    }

    init(
        name: String? = nil,
        title: String? = nil,
        bio: String? = nil,
        pronouns: String? = nil,
        party: String? = nil,
        photoUrl: String? = nil,
        bannerUrl: String? = nil,
        contactInfo: Officials_Official.ContactInfo? = nil,
        socialLinks: Officials_Official.SocialLinks? = nil
    ) {
        self.name = name
        self.title = title
        self.bio = bio
        self.pronouns = pronouns
        self.party = party
        self.photoUrl = photoUrl
        self.bannerUrl = bannerUrl
        self.contactInfo = contactInfo
        self.socialLinks = socialLinks
    }
}

// MARK: - Add Policy Position Request

struct AddPolicyPositionRequest: Encodable {
    let officialId: UUID
    let topic: String
    let stance: String
    let summary: String
    let isFeatured: Bool
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case officialId = "official_id"
        case topic, stance, summary
        case isFeatured = "is_featured"
        case displayOrder = "display_order"
    }
}
