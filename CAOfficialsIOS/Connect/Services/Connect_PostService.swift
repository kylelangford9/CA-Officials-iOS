//
//  Connect_PostService.swift
//  CA Officials
//
//  Service for creating and managing posts
//

import Foundation
import SwiftUI
import Supabase

/// Service for creating and managing posts
@MainActor
final class Connect_PostService: ObservableObject {
    static let shared = Connect_PostService()

    // MARK: - Published Properties

    @Published private(set) var isPosting = false
    @Published private(set) var error: String?

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    private init() {
        #if DEBUG
        print("✍️ [PostService] Initialized")
        #endif
    }

    // MARK: - Create Post

    /// Create a new post
    func createPost(
        officialId: UUID,
        content: String,
        postType: Connect_Post.PostType = .update,
        mediaUrls: [String] = [],
        linkUrl: String? = nil,
        eventDate: Date? = nil,
        eventLocation: String? = nil,
        pollOptions: [String]? = nil,
        pollEndsAt: Date? = nil,
        scheduledFor: Date? = nil
    ) async -> Connect_Post? {
        isPosting = true
        error = nil

        do {
            var request = CreatePostRequest(
                officialId: officialId,
                postType: postType.rawValue,
                content: content,
                mediaUrls: mediaUrls,
                isPublished: scheduledFor == nil,
                scheduledFor: scheduledFor
            )

            request.linkUrl = linkUrl
            request.eventDate = eventDate
            request.eventLocation = eventLocation

            if let options = pollOptions {
                request.pollOptions = options.enumerated().map { index, text in
                    ["index": index, "text": text, "vote_count": 0]
                }
                request.pollEndsAt = pollEndsAt
            }

            let response: Connect_Post = try await supabase
                .from("posts")
                .insert(request)
                .select()
                .single()
                .execute()
                .value

            isPosting = false

            #if DEBUG
            print("✍️ [PostService] Post created: \(response.id)")
            #endif

            return response

        } catch {
            self.error = error.localizedDescription
            isPosting = false

            #if DEBUG
            print("✍️ [PostService] Error creating post: \(error.localizedDescription)")
            #endif

            return nil
        }
    }

    /// Upload media for a post
    func uploadMedia(imageData: Data, officialId: UUID) async -> String? {
        do {
            let fileName = "\(officialId.uuidString)/\(UUID().uuidString).jpg"

            try await supabase.storage
                .from("post-media")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )

            let publicURL = try supabase.storage
                .from("post-media")
                .getPublicURL(path: fileName)

            return publicURL.absoluteString

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error uploading media: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Update Post

    /// Update an existing post
    func updatePost(
        postId: UUID,
        content: String? = nil,
        isPinned: Bool? = nil,
        isPublished: Bool? = nil
    ) async -> Bool {
        do {
            struct PostUpdate: Encodable {
                var content: String?
                var is_pinned: Bool?
                var is_published: Bool?
            }

            let updates = PostUpdate(
                content: content,
                is_pinned: isPinned,
                is_published: isPublished
            )

            try await supabase
                .from("posts")
                .update(updates)
                .eq("id", value: postId.uuidString)
                .execute()

            return true

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error updating post: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Delete a post (soft delete)
    func deletePost(postId: UUID) async -> Bool {
        do {
            try await supabase
                .from("posts")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: postId.uuidString)
                .execute()

            return true

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error deleting post: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Interactions

    /// Like a post
    func likePost(postId: UUID) async -> Bool {
        return await addInteraction(postId: postId, type: .like)
    }

    /// Unlike a post
    func unlikePost(postId: UUID) async -> Bool {
        return await removeInteraction(postId: postId, type: .like)
    }

    /// Bookmark a post
    func bookmarkPost(postId: UUID) async -> Bool {
        return await addInteraction(postId: postId, type: .bookmark)
    }

    /// Remove bookmark
    func unbookmarkPost(postId: UUID) async -> Bool {
        return await removeInteraction(postId: postId, type: .bookmark)
    }

    /// Share a post (record the share)
    func sharePost(postId: UUID) async -> Bool {
        return await addInteraction(postId: postId, type: .share)
    }

    private func addInteraction(postId: UUID, type: Connect_InteractionType) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }

        do {
            try await supabase
                .from("post_interactions")
                .insert([
                    "post_id": postId.uuidString,
                    "user_id": userId.uuidString,
                    "interaction_type": type.rawValue
                ])
                .execute()

            return true

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error adding interaction: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    private func removeInteraction(postId: UUID, type: Connect_InteractionType) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }

        do {
            try await supabase
                .from("post_interactions")
                .delete()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .eq("interaction_type", value: type.rawValue)
                .execute()

            return true

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error removing interaction: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Comments

    /// Add a comment to a post
    func addComment(postId: UUID, content: String, parentId: UUID? = nil) async -> Connect_Comment? {
        guard let userId = await getCurrentUserId() else { return nil }

        do {
            struct CommentInsert: Encodable {
                let post_id: String
                let user_id: String
                let content: String
                let parent_id: String?
            }

            let request = CommentInsert(
                post_id: postId.uuidString,
                user_id: userId.uuidString,
                content: content,
                parent_id: parentId?.uuidString
            )

            let response: Connect_Comment = try await supabase
                .from("comments")
                .insert(request)
                .select()
                .single()
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error adding comment: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetch comments for a post
    func fetchComments(postId: UUID) async -> [Connect_Comment] {
        do {
            let response: [Connect_Comment] = try await supabase
                .from("comments")
                .select()
                .eq("post_id", value: postId.uuidString)
                .is("parent_id", value: nil)  // Top-level comments only
                .order("created_at", ascending: true)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error fetching comments: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Like a comment
    func likeComment(commentId: UUID) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }

        do {
            try await supabase
                .from("comment_likes")
                .insert([
                    "comment_id": commentId.uuidString,
                    "user_id": userId.uuidString
                ])
                .execute()

            return true

        } catch {
            return false
        }
    }

    // MARK: - Polls

    /// Vote on a poll
    func votePoll(postId: UUID, optionIndex: Int) async -> Bool {
        guard let userId = await getCurrentUserId() else { return false }

        do {
            struct PollVoteInsert: Encodable {
                let post_id: String
                let user_id: String
                let option_index: Int
            }

            try await supabase
                .from("poll_votes")
                .insert(PollVoteInsert(
                    post_id: postId.uuidString,
                    user_id: userId.uuidString,
                    option_index: optionIndex
                ))
                .execute()

            return true

        } catch {
            #if DEBUG
            print("✍️ [PostService] Error voting: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Get user's poll vote
    func getUserVote(postId: UUID) async -> Int? {
        guard let userId = await getCurrentUserId() else { return nil }

        do {
            let response: Connect_PollVote = try await supabase
                .from("poll_votes")
                .select()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            return response.optionIndex

        } catch {
            return nil
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

    // MARK: - Cache Management

    /// Clear all cached data (call on sign out)
    func clearCache() {
        error = nil
        isPosting = false

        #if DEBUG
        print("✍️ [PostService] Cache cleared")
        #endif
    }
}

// MARK: - Request Types

struct CreatePostRequest: Encodable {
    let officialId: UUID
    let postType: String
    let content: String
    var mediaUrls: [String]
    var linkUrl: String?
    var eventDate: Date?
    var eventLocation: String?
    var eventUrl: String?
    var pollOptions: [[String: Any]]?
    var pollEndsAt: Date?
    var isPublished: Bool
    var scheduledFor: Date?

    enum CodingKeys: String, CodingKey {
        case officialId = "official_id"
        case postType = "post_type"
        case content
        case mediaUrls = "media_urls"
        case linkUrl = "link_url"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case eventUrl = "event_url"
        case pollOptions = "poll_options"
        case pollEndsAt = "poll_ends_at"
        case isPublished = "is_published"
        case scheduledFor = "scheduled_for"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(officialId, forKey: .officialId)
        try container.encode(postType, forKey: .postType)
        try container.encode(content, forKey: .content)
        try container.encode(mediaUrls, forKey: .mediaUrls)
        try container.encodeIfPresent(linkUrl, forKey: .linkUrl)
        try container.encodeIfPresent(eventDate, forKey: .eventDate)
        try container.encodeIfPresent(eventLocation, forKey: .eventLocation)
        try container.encodeIfPresent(eventUrl, forKey: .eventUrl)
        try container.encodeIfPresent(pollEndsAt, forKey: .pollEndsAt)
        try container.encode(isPublished, forKey: .isPublished)
        try container.encodeIfPresent(scheduledFor, forKey: .scheduledFor)

        // Poll options need special handling
        if let options = pollOptions {
            let jsonData = try JSONSerialization.data(withJSONObject: options)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try container.encode(jsonString, forKey: .pollOptions)
            }
        }
    }
}
