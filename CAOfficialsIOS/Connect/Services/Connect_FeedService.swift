//
//  Connect_FeedService.swift
//  CA Officials
//
//  Service for fetching and managing the social feed
//

import Foundation
import SwiftUI
import Supabase

/// Service for managing the social feed
@MainActor
final class Connect_FeedService: ObservableObject {
    static let shared = Connect_FeedService()

    // MARK: - Published Properties

    @Published private(set) var posts: [Connect_Post] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasMorePosts = true
    @Published private(set) var error: String?

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    private let pageSize = 20
    private var currentOffset = 0

    private init() {
        #if DEBUG
        print("📰 [FeedService] Initialized")
        #endif
    }

    // MARK: - Feed Operations

    /// Fetch the main feed
    func fetchFeed(refresh: Bool = false) async {
        if refresh {
            isRefreshing = true
            currentOffset = 0
        } else if isLoading {
            return
        } else {
            isLoading = true
        }

        error = nil

        do {
            // Use the feed_view for optimized querying
            let response: [Connect_Post] = try await supabase
                .from("feed_view")
                .select()
                .order("is_pinned", ascending: false)
                .order("created_at", ascending: false)
                .range(from: currentOffset, to: currentOffset + pageSize - 1)
                .execute()
                .value

            if refresh {
                posts = response
            } else {
                posts.append(contentsOf: response)
            }

            hasMorePosts = response.count >= pageSize
            currentOffset += response.count

            #if DEBUG
            print("📰 [FeedService] Fetched \(response.count) posts, total: \(posts.count)")
            #endif

        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("📰 [FeedService] Error fetching feed: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
        isRefreshing = false
    }

    /// Load more posts (pagination)
    func loadMore() async {
        guard hasMorePosts, !isLoading else { return }
        await fetchFeed()
    }

    /// Refresh the feed
    func refresh() async {
        await fetchFeed(refresh: true)
    }

    // MARK: - Filtered Feeds

    /// Fetch posts from followed officials only
    func fetchFollowingFeed() async -> [Connect_Post] {
        guard let userId = await getCurrentUserId() else { return [] }

        do {
            // Get followed official IDs
            let follows: [Connect_Follow] = try await supabase
                .from("follows")
                .select("official_id")
                .eq("follower_user_id", value: userId.uuidString)
                .execute()
                .value

            let officialIds = follows.map { $0.officialId.uuidString }

            guard !officialIds.isEmpty else { return [] }

            // Fetch posts from followed officials
            let response: [Connect_Post] = try await supabase
                .from("feed_view")
                .select()
                .in("official_id", values: officialIds)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("📰 [FeedService] Error fetching following feed: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Fetch posts by type
    func fetchPostsByType(_ type: Connect_Post.PostType) async -> [Connect_Post] {
        do {
            let response: [Connect_Post] = try await supabase
                .from("feed_view")
                .select()
                .eq("post_type", value: type.rawValue)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("📰 [FeedService] Error fetching posts by type: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Fetch posts from a specific official
    func fetchOfficialPosts(officialId: UUID) async -> [Connect_Post] {
        do {
            let response: [Connect_Post] = try await supabase
                .from("feed_view")
                .select()
                .eq("official_id", value: officialId.uuidString)
                .order("is_pinned", ascending: false)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("📰 [FeedService] Error fetching official posts: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Single Post

    /// Fetch a single post by ID
    func fetchPost(id: UUID) async -> Connect_Post? {
        do {
            let response: Connect_Post = try await supabase
                .from("feed_view")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("📰 [FeedService] Error fetching post: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Interactions

    /// Check if current user has interacted with a post
    func getUserInteractions(postId: UUID) async -> Set<Connect_InteractionType> {
        guard let userId = await getCurrentUserId() else { return [] }

        do {
            let response: [Connect_PostInteraction] = try await supabase
                .from("post_interactions")
                .select()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            return Set(response.map { $0.interactionType })

        } catch {
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

    /// Update a post in the local cache
    func updatePostInCache(_ updatedPost: Connect_Post) {
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[index] = updatedPost
        }
    }

    // MARK: - Cache Management

    /// Clear all cached data (call on sign out)
    func clearCache() {
        posts = []
        hasMorePosts = true
        currentOffset = 0
        error = nil
        isLoading = false
        isRefreshing = false

        #if DEBUG
        print("📡 [FeedService] Cache cleared")
        #endif
    }
}
