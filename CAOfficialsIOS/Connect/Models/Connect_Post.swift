//
//  Connect_Post.swift
//  CA Officials
//
//  Model for social feed posts
//

import Foundation

/// Represents a post in the Connect social feed
struct Connect_Post: Codable, Identifiable, Equatable {
    let id: UUID
    let officialId: UUID
    var postType: PostType
    var content: String
    var mediaUrls: [String]
    var linkUrl: String?
    var linkPreview: LinkPreview?

    // Event-specific
    var eventDate: Date?
    var eventLocation: String?
    var eventUrl: String?

    // Poll-specific
    var pollOptions: [PollOption]?
    var pollEndsAt: Date?

    // Engagement counts
    var likeCount: Int
    var commentCount: Int
    var shareCount: Int
    var bookmarkCount: Int

    // Status
    var isPinned: Bool
    var isPublished: Bool
    var scheduledFor: Date?

    // Metadata
    var postedBy: UUID?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    // Joined data
    var official: PostOfficial?

    // MARK: - Nested Types

    enum PostType: String, Codable, CaseIterable {
        case update
        case announcement
        case event
        case policy
        case media
        case poll

        var icon: String {
            switch self {
            case .update: return "text.bubble"
            case .announcement: return "megaphone"
            case .event: return "calendar"
            case .policy: return "doc.text"
            case .media: return "photo"
            case .poll: return "chart.bar"
            }
        }

        var displayName: String {
            switch self {
            case .update: return "Update"
            case .announcement: return "Announcement"
            case .event: return "Event"
            case .policy: return "Policy"
            case .media: return "Media"
            case .poll: return "Poll"
            }
        }
    }

    struct LinkPreview: Codable, Equatable {
        var title: String?
        var description: String?
        var imageUrl: String?
        var siteName: String?
    }

    struct PollOption: Codable, Equatable, Identifiable {
        var id: Int { index }
        let index: Int
        var text: String
        var voteCount: Int

        enum CodingKeys: String, CodingKey {
            case index, text
            case voteCount = "vote_count"
        }
    }

    struct PostOfficial: Codable, Equatable {
        let name: String
        let title: String?
        let photoUrl: String?
        let party: String?
        let verificationStatus: String

        enum CodingKeys: String, CodingKey {
            case name, title, party
            case photoUrl = "photo_url"
            case verificationStatus = "verification_status"
        }

        var isVerified: Bool {
            verificationStatus == "verified"
        }
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case officialId = "official_id"
        case postType = "post_type"
        case content
        case mediaUrls = "media_urls"
        case linkUrl = "link_url"
        case linkPreview = "link_preview"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case eventUrl = "event_url"
        case pollOptions = "poll_options"
        case pollEndsAt = "poll_ends_at"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case bookmarkCount = "bookmark_count"
        case isPinned = "is_pinned"
        case isPublished = "is_published"
        case scheduledFor = "scheduled_for"
        case postedBy = "posted_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case official
    }

    // MARK: - Computed Properties

    var totalEngagement: Int {
        likeCount + commentCount + shareCount
    }

    var isPoll: Bool {
        postType == .poll && pollOptions != nil
    }

    var isEvent: Bool {
        postType == .event && eventDate != nil
    }

    var hasMedia: Bool {
        !mediaUrls.isEmpty
    }

    var timeAgo: String {
        guard let createdAt = createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Preview Data

#if DEBUG
extension Connect_Post {
    static let preview = Connect_Post(
        id: UUID(),
        officialId: UUID(),
        postType: .update,
        content: "Excited to announce that we've secured additional funding for local schools in District 15. This investment will help upgrade facilities and expand after-school programs for thousands of students. Education remains my top priority!",
        mediaUrls: [],
        linkUrl: nil,
        linkPreview: nil,
        eventDate: nil,
        eventLocation: nil,
        eventUrl: nil,
        pollOptions: nil,
        pollEndsAt: nil,
        likeCount: 234,
        commentCount: 45,
        shareCount: 67,
        bookmarkCount: 23,
        isPinned: false,
        isPublished: true,
        scheduledFor: nil,
        postedBy: UUID(),
        createdAt: Date().addingTimeInterval(-3600 * 2),
        updatedAt: nil,
        deletedAt: nil,
        official: PostOfficial(
            name: "Jane Smith",
            title: "State Senator, District 15",
            photoUrl: nil,
            party: "democratic",
            verificationStatus: "verified"
        )
    )

    static let previewEvent = Connect_Post(
        id: UUID(),
        officialId: UUID(),
        postType: .event,
        content: "Join me for a Town Hall meeting to discuss the upcoming state budget and how it affects our community.",
        mediaUrls: [],
        linkUrl: "https://example.com/rsvp",
        linkPreview: nil,
        eventDate: Date().addingTimeInterval(86400 * 7),
        eventLocation: "Sacramento Community Center, 123 Main St",
        eventUrl: "https://example.com/rsvp",
        pollOptions: nil,
        pollEndsAt: nil,
        likeCount: 156,
        commentCount: 32,
        shareCount: 89,
        bookmarkCount: 45,
        isPinned: true,
        isPublished: true,
        scheduledFor: nil,
        postedBy: UUID(),
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: nil,
        deletedAt: nil,
        official: PostOfficial(
            name: "Jane Smith",
            title: "State Senator, District 15",
            photoUrl: nil,
            party: "democratic",
            verificationStatus: "verified"
        )
    )

    static let previewPoll = Connect_Post(
        id: UUID(),
        officialId: UUID(),
        postType: .poll,
        content: "What issue matters most to you for the upcoming legislative session?",
        mediaUrls: [],
        linkUrl: nil,
        linkPreview: nil,
        eventDate: nil,
        eventLocation: nil,
        eventUrl: nil,
        pollOptions: [
            PollOption(index: 0, text: "Education Funding", voteCount: 234),
            PollOption(index: 1, text: "Healthcare Access", voteCount: 189),
            PollOption(index: 2, text: "Climate Action", voteCount: 156),
            PollOption(index: 3, text: "Housing Affordability", voteCount: 298)
        ],
        pollEndsAt: Date().addingTimeInterval(86400 * 3),
        likeCount: 45,
        commentCount: 23,
        shareCount: 12,
        bookmarkCount: 8,
        isPinned: false,
        isPublished: true,
        scheduledFor: nil,
        postedBy: UUID(),
        createdAt: Date().addingTimeInterval(-86400 * 2),
        updatedAt: nil,
        deletedAt: nil,
        official: PostOfficial(
            name: "Jane Smith",
            title: "State Senator, District 15",
            photoUrl: nil,
            party: "democratic",
            verificationStatus: "verified"
        )
    )

    static let previewArray: [Connect_Post] = [
        previewEvent,
        preview,
        previewPoll
    ]
}
#endif
