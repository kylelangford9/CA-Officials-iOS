//
//  Connect_Follow.swift
//  CA Officials
//
//  Model for follow relationships
//

import Foundation

/// Represents a follow relationship between a user and an official
struct Connect_Follow: Codable, Identifiable, Equatable {
    let id: UUID
    let followerUserId: UUID
    let officialId: UUID

    // Notification preferences
    var notifyPosts: Bool
    var notifyEvents: Bool
    var notifyPolicy: Bool

    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case followerUserId = "follower_user_id"
        case officialId = "official_id"
        case notifyPosts = "notify_posts"
        case notifyEvents = "notify_events"
        case notifyPolicy = "notify_policy"
        case createdAt = "created_at"
    }
}

/// Model for displaying an official that can be followed
struct Connect_FollowableOfficial: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let title: String?
    let photoUrl: String?
    let party: String?
    let verificationStatus: String
    var followerCount: Int

    // Current user's follow state
    var isFollowing: Bool
    var followId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, title, party
        case photoUrl = "photo_url"
        case verificationStatus = "verification_status"
        case followerCount = "follower_count"
        case isFollowing = "is_following"
        case followId = "follow_id"
    }

    var isVerified: Bool {
        verificationStatus == "verified"
    }

    var partyAbbreviation: String {
        guard let party = party?.lowercased() else { return "" }
        switch party {
        case "democratic": return "D"
        case "republican": return "R"
        case "independent": return "I"
        case "libertarian": return "L"
        case "green": return "G"
        case "nonpartisan": return "NP"
        default: return ""
        }
    }
}

/// Notification preference updates
struct Connect_FollowPreferences: Codable {
    var notifyPosts: Bool
    var notifyEvents: Bool
    var notifyPolicy: Bool

    enum CodingKeys: String, CodingKey {
        case notifyPosts = "notify_posts"
        case notifyEvents = "notify_events"
        case notifyPolicy = "notify_policy"
    }
}

// MARK: - Preview Data

#if DEBUG
extension Connect_Follow {
    static let preview = Connect_Follow(
        id: UUID(),
        followerUserId: UUID(),
        officialId: UUID(),
        notifyPosts: true,
        notifyEvents: true,
        notifyPolicy: false,
        createdAt: Date()
    )
}

extension Connect_FollowableOfficial {
    static let preview = Connect_FollowableOfficial(
        id: UUID(),
        name: "Jane Smith",
        title: "State Senator, District 15",
        photoUrl: nil,
        party: "democratic",
        verificationStatus: "verified",
        followerCount: 3892,
        isFollowing: true,
        followId: UUID()
    )

    static let previewArray: [Connect_FollowableOfficial] = [
        preview,
        Connect_FollowableOfficial(
            id: UUID(),
            name: "John Doe",
            title: "Assembly Member, District 42",
            photoUrl: nil,
            party: "republican",
            verificationStatus: "verified",
            followerCount: 2156,
            isFollowing: false,
            followId: nil
        ),
        Connect_FollowableOfficial(
            id: UUID(),
            name: "Maria Garcia",
            title: "Mayor of San Jose",
            photoUrl: nil,
            party: "democratic",
            verificationStatus: "verified",
            followerCount: 8934,
            isFollowing: true,
            followId: UUID()
        )
    ]
}
#endif
