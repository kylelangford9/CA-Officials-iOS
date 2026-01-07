//
//  Officials_ProfileAnalytics.swift
//  CA Officials
//
//  Model for profile analytics data
//

import Foundation

/// Analytics data for an official's profile
struct Officials_ProfileAnalytics: Codable, Identifiable, Equatable {
    let id: UUID
    let officialId: UUID
    var totalViews: Int
    var uniqueVisitors: Int
    var followers: Int
    var postViews: Int
    var profileShares: Int
    var periodStart: Date?
    var periodEnd: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case officialId = "official_id"
        case totalViews = "total_views"
        case uniqueVisitors = "unique_visitors"
        case followers
        case postViews = "post_views"
        case profileShares = "profile_shares"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var engagementRate: Double {
        guard totalViews > 0 else { return 0 }
        return Double(postViews + profileShares) / Double(totalViews) * 100
    }

    var averageViewsPerFollower: Double {
        guard followers > 0 else { return 0 }
        return Double(totalViews) / Double(followers)
    }
}

// MARK: - Analytics Summary

struct Officials_AnalyticsSummary: Codable {
    let totalViews: Int
    let viewsChange: Double
    let totalFollowers: Int
    let followersChange: Double
    let totalEngagement: Int
    let engagementChange: Double
    let profileReach: Int
    let reachChange: Double

    enum CodingKeys: String, CodingKey {
        case totalViews = "total_views"
        case viewsChange = "views_change"
        case totalFollowers = "total_followers"
        case followersChange = "followers_change"
        case totalEngagement = "total_engagement"
        case engagementChange = "engagement_change"
        case profileReach = "profile_reach"
        case reachChange = "reach_change"
    }
}

// MARK: - Daily Analytics

struct Officials_DailyAnalytics: Codable, Identifiable {
    var id: String { date }
    let date: String
    let views: Int
    let uniqueVisitors: Int
    let newFollowers: Int
    let postEngagement: Int

    enum CodingKeys: String, CodingKey {
        case date
        case views
        case uniqueVisitors = "unique_visitors"
        case newFollowers = "new_followers"
        case postEngagement = "post_engagement"
    }
}

// MARK: - Preview Data

#if DEBUG
extension Officials_ProfileAnalytics {
    static let preview = Officials_ProfileAnalytics(
        id: UUID(),
        officialId: UUID(),
        totalViews: 12543,
        uniqueVisitors: 8234,
        followers: 3892,
        postViews: 45678,
        profileShares: 234,
        periodStart: Date().addingTimeInterval(-86400 * 30),
        periodEnd: Date(),
        createdAt: Date(),
        updatedAt: nil
    )
}

extension Officials_AnalyticsSummary {
    static let preview = Officials_AnalyticsSummary(
        totalViews: 12543,
        viewsChange: 12.5,
        totalFollowers: 3892,
        followersChange: 8.3,
        totalEngagement: 45912,
        engagementChange: -2.1,
        profileReach: 8234,
        reachChange: 15.7
    )
}
#endif
