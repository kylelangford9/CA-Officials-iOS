//
//  Connect_Comment.swift
//  CA Officials
//
//  Model for post comments
//

import Foundation

/// Represents a comment on a post
struct Connect_Comment: Codable, Identifiable, Equatable {
    let id: UUID
    let postId: UUID
    let parentId: UUID?  // For nested replies
    let userId: UUID
    var content: String
    var likeCount: Int
    var isHidden: Bool
    var hiddenReason: String?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    // Joined user data
    var user: CommentUser?

    // Nested replies (for display)
    var replies: [Connect_Comment]?

    struct CommentUser: Codable, Equatable {
        let id: UUID
        var displayName: String?
        var avatarUrl: String?
        var isOfficial: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
            case isOfficial = "is_official"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case parentId = "parent_id"
        case userId = "user_id"
        case content
        case likeCount = "like_count"
        case isHidden = "is_hidden"
        case hiddenReason = "hidden_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case user
        case replies
    }

    // MARK: - Computed Properties

    var timeAgo: String {
        guard let createdAt = createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var isReply: Bool {
        parentId != nil
    }

    var hasReplies: Bool {
        !(replies?.isEmpty ?? true)
    }
}

// MARK: - Interaction Types

/// Types of interactions users can have with posts
enum Connect_InteractionType: String, Codable {
    case like
    case bookmark
    case share
}

/// Represents a user's interaction with a post
struct Connect_PostInteraction: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let interactionType: Connect_InteractionType
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case interactionType = "interaction_type"
        case createdAt = "created_at"
    }
}

/// Represents a user's like on a comment
struct Connect_CommentLike: Codable, Identifiable {
    let id: UUID
    let commentId: UUID
    let userId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case commentId = "comment_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

/// Represents a vote on a poll
struct Connect_PollVote: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let optionIndex: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case optionIndex = "option_index"
        case createdAt = "created_at"
    }
}

// MARK: - Preview Data

#if DEBUG
extension Connect_Comment {
    static let preview = Connect_Comment(
        id: UUID(),
        postId: UUID(),
        parentId: nil,
        userId: UUID(),
        content: "Thank you Senator Smith for your continued focus on education! My kids' school really needs these upgrades.",
        likeCount: 12,
        isHidden: false,
        hiddenReason: nil,
        createdAt: Date().addingTimeInterval(-1800),
        updatedAt: nil,
        deletedAt: nil,
        user: CommentUser(
            id: UUID(),
            displayName: "John D.",
            avatarUrl: nil,
            isOfficial: false
        ),
        replies: nil
    )

    static let previewWithReplies = Connect_Comment(
        id: UUID(),
        postId: UUID(),
        parentId: nil,
        userId: UUID(),
        content: "When will the funding be distributed to schools?",
        likeCount: 8,
        isHidden: false,
        hiddenReason: nil,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: nil,
        deletedAt: nil,
        user: CommentUser(
            id: UUID(),
            displayName: "Sarah M.",
            avatarUrl: nil,
            isOfficial: false
        ),
        replies: [
            Connect_Comment(
                id: UUID(),
                postId: UUID(),
                parentId: UUID(),
                userId: UUID(),
                content: "The funding will be distributed starting next quarter. Schools should receive notification in the coming weeks.",
                likeCount: 15,
                isHidden: false,
                hiddenReason: nil,
                createdAt: Date().addingTimeInterval(-1800),
                updatedAt: nil,
                deletedAt: nil,
                user: CommentUser(
                    id: UUID(),
                    displayName: "Sen. Smith's Office",
                    avatarUrl: nil,
                    isOfficial: true
                ),
                replies: nil
            )
        ]
    )

    static let previewArray: [Connect_Comment] = [
        previewWithReplies,
        preview,
        Connect_Comment(
            id: UUID(),
            postId: UUID(),
            parentId: nil,
            userId: UUID(),
            content: "Great news for our community!",
            likeCount: 5,
            isHidden: false,
            hiddenReason: nil,
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: nil,
            deletedAt: nil,
            user: CommentUser(
                id: UUID(),
                displayName: "Mike R.",
                avatarUrl: nil,
                isOfficial: false
            ),
            replies: nil
        )
    ]
}
#endif
