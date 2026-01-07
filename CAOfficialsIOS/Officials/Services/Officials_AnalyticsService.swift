//
//  Officials_AnalyticsService.swift
//  CA Officials
//
//  Service for fetching and managing analytics data
//

import Foundation
import SwiftUI
import Supabase

/// Service for managing official analytics
@MainActor
final class Officials_AnalyticsService: ObservableObject {
    static let shared = Officials_AnalyticsService()

    // MARK: - Published Properties

    @Published private(set) var todayStats: Officials_DailyStats?
    @Published private(set) var weeklyStats: [Officials_DailyStats] = []
    @Published private(set) var monthlyStats: [Officials_DailyStats] = []
    @Published private(set) var analytics: Officials_ProfileAnalytics?
    @Published private(set) var recentActivity: [Officials_Activity] = []
    @Published private(set) var isLoading = false
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
        print("📊 [AnalyticsService] Initialized")
        #endif
    }

    // MARK: - Fetch Analytics

    /// Fetch today's stats
    func fetchTodayStats(officialId: UUID) async {
        isLoading = true

        do {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

            let response: Officials_DailyStats = try await supabase
                .from("official_analytics")
                .select()
                .eq("official_id", value: officialId.uuidString)
                .eq("date", value: String(today))
                .single()
                .execute()
                .value

            todayStats = response

        } catch {
            // No stats for today yet, create placeholder
            todayStats = Officials_DailyStats.empty(officialId: officialId, date: Date())
            #if DEBUG
            print("📊 [AnalyticsService] No stats for today yet")
            #endif
        }

        isLoading = false
    }

    /// Fetch stats for date range
    func fetchStats(officialId: UUID, days: Int) async -> [Officials_DailyStats] {
        isLoading = true

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let formatter = ISO8601DateFormatter()
        let startDateStr = String(formatter.string(from: startDate).prefix(10))
        let endDateStr = String(formatter.string(from: endDate).prefix(10))

        do {
            let response: [Officials_DailyStats] = try await supabase
                .from("official_analytics")
                .select()
                .eq("official_id", value: officialId.uuidString)
                .gte("date", value: startDateStr)
                .lte("date", value: endDateStr)
                .order("date", ascending: true)
                .execute()
                .value

            isLoading = false
            return response

        } catch {
            #if DEBUG
            print("📊 [AnalyticsService] Error fetching stats: \(error.localizedDescription)")
            #endif
            isLoading = false
            return []
        }
    }

    /// Fetch profile analytics
    func fetchAnalytics(officialId: UUID) async {
        isLoading = true

        do {
            let response: Officials_ProfileAnalytics = try await supabase
                .from("official_profile_analytics")
                .select()
                .eq("official_id", value: officialId.uuidString)
                .single()
                .execute()
                .value

            analytics = response
        } catch {
            // Create default analytics if none exist
            analytics = Officials_ProfileAnalytics(
                id: UUID(),
                officialId: officialId,
                totalViews: 0,
                uniqueVisitors: 0,
                followers: 0,
                postViews: 0,
                profileShares: 0,
                periodStart: nil,
                periodEnd: nil,
                createdAt: Date(),
                updatedAt: nil
            )
            #if DEBUG
            print("📊 [AnalyticsService] No analytics found, using defaults")
            #endif
        }

        isLoading = false
    }

    /// Fetch recent activity
    func fetchRecentActivity(limit: Int = 20) async {
        guard let userId = await getCurrentUserId() else { return }

        do {
            let response: [Officials_Activity] = try await supabase
                .from("official_activity")
                .select()
                .eq("official_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            recentActivity = response
        } catch {
            #if DEBUG
            print("📊 [AnalyticsService] Error fetching activity: \(error.localizedDescription)")
            #endif
            recentActivity = []
        }
    }

    /// Record an event
    func recordEvent(officialId: UUID, eventType: String, metadata: [String: String]? = nil) async {
        do {
            let activity = [
                "official_id": officialId.uuidString,
                "activity_type": eventType
            ]

            try await supabase
                .from("official_activity")
                .insert(activity)
                .execute()
        } catch {
            #if DEBUG
            print("📊 [AnalyticsService] Error recording event: \(error.localizedDescription)")
            #endif
        }
    }

    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            return nil
        }
    }

    /// Fetch weekly stats
    func fetchWeeklyStats(officialId: UUID) async {
        weeklyStats = await fetchStats(officialId: officialId, days: 7)
    }

    /// Fetch monthly stats
    func fetchMonthlyStats(officialId: UUID) async {
        monthlyStats = await fetchStats(officialId: officialId, days: 30)
    }

    // MARK: - Record Events

    /// Record a profile view
    func recordProfileView(officialId: UUID, source: String = "direct") async {
        await incrementStat(officialId: officialId, stat: .profileViews, source: source)
    }

    /// Record a link click
    func recordLinkClick(officialId: UUID, linkType: LinkType) async {
        switch linkType {
        case .website:
            await incrementStat(officialId: officialId, stat: .linkClicks)
        case .contact:
            await incrementStat(officialId: officialId, stat: .contactClicks)
        case .social:
            await incrementStat(officialId: officialId, stat: .socialClicks)
        }
    }

    /// Record a search appearance
    func recordSearchAppearance(officialId: UUID) async {
        await incrementStat(officialId: officialId, stat: .searchAppearances)
    }

    // MARK: - Aggregate Stats

    /// Get total views for period
    func getTotalViews(days: Int, officialId: UUID) async -> Int {
        let stats = await fetchStats(officialId: officialId, days: days)
        return stats.reduce(0) { $0 + $1.profileViews }
    }

    /// Get engagement rate
    func getEngagementRate(officialId: UUID) async -> Double {
        let stats = await fetchStats(officialId: officialId, days: 7)
        let totalViews = stats.reduce(0) { $0 + $1.profileViews }
        let totalClicks = stats.reduce(0) { $0 + $1.linkClicks + $1.contactClicks + $1.socialClicks }

        guard totalViews > 0 else { return 0 }
        return Double(totalClicks) / Double(totalViews) * 100
    }

    /// Calculate trend percentage
    func calculateTrend(current: Int, previous: Int) -> (value: Double, isPositive: Bool) {
        guard previous > 0 else { return (0, true) }
        let change = Double(current - previous) / Double(previous) * 100
        return (abs(change), change >= 0)
    }

    // MARK: - Private Helpers

    private enum StatType: String {
        case profileViews = "profile_views"
        case searchAppearances = "search_appearances"
        case linkClicks = "link_clicks"
        case contactClicks = "contact_clicks"
        case socialClicks = "social_clicks"
    }

    private func incrementStat(officialId: UUID, stat: StatType, source: String? = nil) async {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))

        do {
            // Try to upsert today's record
            try await supabase.rpc(
                "increment_analytics_stat",
                params: [
                    "p_official_id": officialId.uuidString,
                    "p_date": today,
                    "p_stat": stat.rawValue,
                    "p_source": source ?? "direct"
                ]
            ).execute()

            #if DEBUG
            print("📊 [AnalyticsService] Recorded \(stat.rawValue)")
            #endif

        } catch {
            #if DEBUG
            print("📊 [AnalyticsService] Error recording stat: \(error.localizedDescription)")
            #endif
        }
    }

    enum LinkType {
        case website
        case contact
        case social
    }

    // MARK: - Cache Management

    /// Clear all cached data (call on sign out)
    func clearCache() {
        todayStats = nil
        weeklyStats = []
        monthlyStats = []
        analytics = nil
        recentActivity = []
        error = nil
        isLoading = false

        #if DEBUG
        print("📊 [AnalyticsService] Cache cleared")
        #endif
    }
}

// MARK: - Daily Stats Model

struct Officials_DailyStats: Codable, Identifiable {
    let id: UUID
    let officialId: UUID
    let date: Date
    var profileViews: Int
    var searchAppearances: Int
    var uniqueVoters: Int
    var linkClicks: Int
    var contactClicks: Int
    var socialClicks: Int
    var sourceBreakdown: SourceBreakdown?
    var createdAt: Date?
    var updatedAt: Date?

    struct SourceBreakdown: Codable {
        var caVotersApp: Int
        var direct: Int
        var search: Int
        var sharedLink: Int

        enum CodingKeys: String, CodingKey {
            case caVotersApp = "ca_voters_app"
            case direct, search
            case sharedLink = "shared_link"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case officialId = "official_id"
        case date
        case profileViews = "profile_views"
        case searchAppearances = "search_appearances"
        case uniqueVoters = "unique_voters"
        case linkClicks = "link_clicks"
        case contactClicks = "contact_clicks"
        case socialClicks = "social_clicks"
        case sourceBreakdown = "source_breakdown"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func empty(officialId: UUID, date: Date) -> Officials_DailyStats {
        Officials_DailyStats(
            id: UUID(),
            officialId: officialId,
            date: date,
            profileViews: 0,
            searchAppearances: 0,
            uniqueVoters: 0,
            linkClicks: 0,
            contactClicks: 0,
            socialClicks: 0,
            sourceBreakdown: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}

// MARK: - Preview Data

#if DEBUG
extension Officials_DailyStats {
    static let previewWeek: [Officials_DailyStats] = (0..<7).map { dayOffset in
        let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        return Officials_DailyStats(
            id: UUID(),
            officialId: UUID(),
            date: date,
            profileViews: Int.random(in: 100...300),
            searchAppearances: Int.random(in: 50...150),
            uniqueVoters: Int.random(in: 80...200),
            linkClicks: Int.random(in: 20...80),
            contactClicks: Int.random(in: 10...40),
            socialClicks: Int.random(in: 5...20),
            sourceBreakdown: SourceBreakdown(
                caVotersApp: Int.random(in: 50...150),
                direct: Int.random(in: 20...60),
                search: Int.random(in: 10...40),
                sharedLink: Int.random(in: 5...20)
            ),
            createdAt: date,
            updatedAt: date
        )
    }.reversed()
}
#endif
