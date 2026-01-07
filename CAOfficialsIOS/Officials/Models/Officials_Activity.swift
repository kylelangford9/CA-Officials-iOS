//
//  Officials_Activity.swift
//  CA Officials
//
//  Model for activity feed items
//

import Foundation

/// Represents an activity event in the official's dashboard
struct Officials_Activity: Codable, Identifiable, Equatable {
    let id: UUID
    let officialId: UUID
    let activityType: String
    let metadata: [String: String]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case officialId = "official_id"
        case activityType = "activity_type"
        case metadata
        case createdAt = "created_at"
    }

    // MARK: - Activity Types

    static let typeProfileView = "profile_view"
    static let typePostLike = "post_like"
    static let typePostComment = "post_comment"
    static let typePostShare = "post_share"
    static let typeNewFollower = "new_follower"
    static let typeUnfollow = "unfollow"
    static let typePostCreated = "post_created"
    static let typePollVote = "poll_vote"
    static let typeEventRsvp = "event_rsvp"
}

// MARK: - Preview Data

#if DEBUG
extension Officials_Activity {
    static let previewProfileView = Officials_Activity(
        id: UUID(),
        officialId: UUID(),
        activityType: typeProfileView,
        metadata: nil,
        createdAt: Date().addingTimeInterval(-300)
    )

    static let previewPostLike = Officials_Activity(
        id: UUID(),
        officialId: UUID(),
        activityType: typePostLike,
        metadata: ["post_id": UUID().uuidString],
        createdAt: Date().addingTimeInterval(-600)
    )

    static let previewNewFollower = Officials_Activity(
        id: UUID(),
        officialId: UUID(),
        activityType: typeNewFollower,
        metadata: ["follower_name": "John D."],
        createdAt: Date().addingTimeInterval(-1800)
    )

    static let previewPostComment = Officials_Activity(
        id: UUID(),
        officialId: UUID(),
        activityType: typePostComment,
        metadata: ["post_id": UUID().uuidString, "comment_preview": "Great work!"],
        createdAt: Date().addingTimeInterval(-3600)
    )

    static let previewArray: [Officials_Activity] = [
        previewProfileView,
        previewPostLike,
        previewNewFollower,
        previewPostComment
    ]
}
#endif
