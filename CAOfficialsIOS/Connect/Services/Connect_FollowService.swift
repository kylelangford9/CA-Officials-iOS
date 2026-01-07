//
//  Connect_FollowService.swift
//  CA Officials
//
//  Service for managing follow relationships
//

import Foundation
import SwiftUI
import Supabase

/// Service for managing follow relationships between users and officials
@MainActor
final class Connect_FollowService: ObservableObject {
    static let shared = Connect_FollowService()

    // MARK: - Published Properties

    @Published private(set) var followedOfficials: [Connect_FollowableOfficial] = []
    @Published private(set) var suggestedOfficials: [Connect_FollowableOfficial] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    private var followedIds: Set<UUID> = []

    private init() {
        #if DEBUG
        print("👥 [FollowService] Initialized")
        #endif
    }

    // MARK: - Follow Operations

    /// Follow an official
    func followOfficial(officialId: UUID) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }

        do {
            let follow = FollowRequest(
                followerUserId: userId,
                officialId: officialId,
                notifyPosts: true,
                notifyEvents: true,
                notifyPolicy: false
            )

            try await supabase
                .from("follows")
                .insert(follow)
                .execute()

            followedIds.insert(officialId)
            updateLocalFollowState(officialId: officialId, isFollowing: true)

            #if DEBUG
            print("👥 [FollowService] Followed official: \(officialId)")
            #endif

            return true

        } catch {
            #if DEBUG
            print("👥 [FollowService] Error following: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Unfollow an official
    func unfollowOfficial(officialId: UUID) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }

        do {
            try await supabase
                .from("follows")
                .delete()
                .eq("follower_user_id", value: userId.uuidString)
                .eq("official_id", value: officialId.uuidString)
                .execute()

            followedIds.remove(officialId)
            updateLocalFollowState(officialId: officialId, isFollowing: false)

            #if DEBUG
            print("👥 [FollowService] Unfollowed official: \(officialId)")
            #endif

            return true

        } catch {
            #if DEBUG
            print("👥 [FollowService] Error unfollowing: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Check if currently following an official
    func isFollowing(officialId: UUID) -> Bool {
        followedIds.contains(officialId)
    }

    // MARK: - Fetch Operations

    /// Fetch officials the user is following
    func fetchFollowedOfficials() async {
        guard let userId = await getCurrentUserId() else { return }

        isLoading = true
        error = nil

        do {
            let response: [Connect_FollowableOfficial] = try await supabase
                .from("followable_officials_view")
                .select()
                .eq("follower_user_id", value: userId.uuidString)
                .eq("is_following", value: true)
                .order("name", ascending: true)
                .execute()
                .value

            followedOfficials = response
            followedIds = Set(response.map { $0.id })

            #if DEBUG
            print("👥 [FollowService] Fetched \(response.count) followed officials")
            #endif

        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("👥 [FollowService] Error fetching followed: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
    }

    /// Fetch suggested officials to follow
    func fetchSuggestedOfficials(limit: Int = 10) async {
        guard let userId = await getCurrentUserId() else { return }

        do {
            // Fetch officials not yet followed, prioritizing verified ones
            let response: [Connect_FollowableOfficial] = try await supabase
                .from("followable_officials_view")
                .select()
                .eq("follower_user_id", value: userId.uuidString)
                .eq("is_following", value: false)
                .order("follower_count", ascending: false)
                .limit(limit)
                .execute()
                .value

            suggestedOfficials = response

            #if DEBUG
            print("👥 [FollowService] Fetched \(response.count) suggested officials")
            #endif

        } catch {
            #if DEBUG
            print("👥 [FollowService] Error fetching suggestions: \(error.localizedDescription)")
            #endif
        }
    }

    /// Search for officials to follow
    func searchOfficials(query: String) async -> [Connect_FollowableOfficial] {
        guard !query.isEmpty else { return [] }

        do {
            let response: [Connect_FollowableOfficial] = try await supabase
                .from("followable_officials_view")
                .select()
                .ilike("name", pattern: "%\(query)%")
                .order("follower_count", ascending: false)
                .limit(20)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("👥 [FollowService] Error searching: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Notification Preferences

    /// Update notification preferences for a follow
    func updateNotificationPreferences(
        followId: UUID,
        notifyPosts: Bool? = nil,
        notifyEvents: Bool? = nil,
        notifyPolicy: Bool? = nil
    ) async -> Bool {
        do {
            var updates: [String: Bool] = [:]

            if let notifyPosts = notifyPosts {
                updates["notify_posts"] = notifyPosts
            }
            if let notifyEvents = notifyEvents {
                updates["notify_events"] = notifyEvents
            }
            if let notifyPolicy = notifyPolicy {
                updates["notify_policy"] = notifyPolicy
            }

            guard !updates.isEmpty else { return true }

            try await supabase
                .from("follows")
                .update(updates)
                .eq("id", value: followId.uuidString)
                .execute()

            return true

        } catch {
            #if DEBUG
            print("👥 [FollowService] Error updating preferences: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Get follow details including notification preferences
    func getFollowDetails(officialId: UUID) async -> Connect_Follow? {
        guard let userId = await getCurrentUserId() else { return nil }

        do {
            let response: Connect_Follow = try await supabase
                .from("follows")
                .select()
                .eq("follower_user_id", value: userId.uuidString)
                .eq("official_id", value: officialId.uuidString)
                .single()
                .execute()
                .value

            return response

        } catch {
            return nil
        }
    }

    // MARK: - Follower Stats

    /// Get follower count for an official
    func getFollowerCount(officialId: UUID) async -> Int {
        do {
            let response: [FollowerCountResponse] = try await supabase
                .from("follows")
                .select("id", head: false, count: .exact)
                .eq("official_id", value: officialId.uuidString)
                .execute()
                .value

            return response.count

        } catch {
            return 0
        }
    }

    /// Get list of followers for an official (for official's dashboard)
    func getFollowers(officialId: UUID, limit: Int = 50) async -> [FollowerInfo] {
        do {
            let response: [FollowerInfo] = try await supabase
                .from("follower_details_view")
                .select()
                .eq("official_id", value: officialId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("👥 [FollowService] Error fetching followers: \(error.localizedDescription)")
            #endif
            return []
        }
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

    private func updateLocalFollowState(officialId: UUID, isFollowing: Bool) {
        // Update in followed officials list
        if let index = followedOfficials.firstIndex(where: { $0.id == officialId }) {
            followedOfficials[index].isFollowing = isFollowing
            if !isFollowing {
                followedOfficials.remove(at: index)
            }
        }

        // Update in suggested officials list
        if let index = suggestedOfficials.firstIndex(where: { $0.id == officialId }) {
            suggestedOfficials[index].isFollowing = isFollowing
            if isFollowing {
                suggestedOfficials.remove(at: index)
            }
        }
    }

    // MARK: - Cache Management

    /// Clear all cached data (call on sign out)
    func clearCache() {
        followedOfficials = []
        suggestedOfficials = []
        followedIds = []
        error = nil
        isLoading = false

        #if DEBUG
        print("👥 [FollowService] Cache cleared")
        #endif
    }
}

// MARK: - Request/Response Types

private struct FollowRequest: Encodable {
    let followerUserId: UUID
    let officialId: UUID
    let notifyPosts: Bool
    let notifyEvents: Bool
    let notifyPolicy: Bool

    enum CodingKeys: String, CodingKey {
        case followerUserId = "follower_user_id"
        case officialId = "official_id"
        case notifyPosts = "notify_posts"
        case notifyEvents = "notify_events"
        case notifyPolicy = "notify_policy"
    }
}

private struct FollowerCountResponse: Decodable {
    let id: UUID
}

/// Information about a follower (for official's view)
struct FollowerInfo: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let displayName: String?
    let avatarUrl: String?
    let followedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case followedAt = "followed_at"
    }
}
