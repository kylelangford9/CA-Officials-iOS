//
//  Officials_AnalyticsViewModel.swift
//  CA Officials
//
//  ViewModel for analytics view
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class Officials_AnalyticsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTimeRange: TimeRange = .week
    @Published private(set) var analytics: Officials_ProfileAnalytics?
    @Published private(set) var viewsData: [ChartDataPoint] = []
    @Published private(set) var engagementData: [EngagementMetric] = []
    @Published private(set) var topPosts: [PostAnalytics] = []
    @Published private(set) var demographicData: [DemographicItem] = []

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // Summary stats
    @Published private(set) var totalViews = 0
    @Published private(set) var viewsChange: Double = 0
    @Published private(set) var totalFollowers = 0
    @Published private(set) var followersChange: Double = 0
    @Published private(set) var totalEngagement = 0
    @Published private(set) var engagementChange: Double = 0
    @Published private(set) var profileReach = 0
    @Published private(set) var reachChange: Double = 0

    // MARK: - Types

    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "90 Days"
        case year = "1 Year"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Int
        let label: String
    }

    struct EngagementMetric: Identifiable {
        let id = UUID()
        let name: String
        let value: Int
        let percentage: Double
        let icon: String
        let color: Color
    }

    struct PostAnalytics: Identifiable {
        let id: UUID
        let content: String
        let views: Int
        let likes: Int
        let comments: Int
        let shares: Int
        let createdAt: Date

        var totalEngagement: Int {
            likes + comments + shares
        }

        var engagementRate: Double {
            guard views > 0 else { return 0 }
            return Double(totalEngagement) / Double(views) * 100
        }
    }

    struct DemographicItem: Identifiable {
        let id = UUID()
        let category: String
        let value: String
        let percentage: Double
    }

    // MARK: - Services

    private let analyticsService = Officials_AnalyticsService.shared
    private let profileService = Officials_ProfileService.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var hasData: Bool {
        analytics != nil && totalViews > 0
    }

    var isPremium: Bool {
        // Check if user has premium subscription
        // For now, return false to show upsell
        false
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        $selectedTimeRange
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadAnalytics() }
            }
            .store(in: &cancellables)

        analyticsService.$analytics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] analytics in
                self?.analytics = analytics
                self?.updateSummaryStats()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadAnalytics() async {
        guard let profile = profileService.profile else { return }

        isLoading = true
        error = nil

        await analyticsService.fetchAnalytics(officialId: profile.id)

        generateChartData()
        generateEngagementData()
        generateTopPosts()
        generateDemographicData()

        isLoading = false
    }

    func refresh() async {
        await loadAnalytics()
    }

    // MARK: - Data Processing

    private func updateSummaryStats() {
        guard let analytics = analytics else { return }

        totalViews = analytics.totalViews
        totalFollowers = analytics.followers
        totalEngagement = analytics.postViews + analytics.profileShares
        profileReach = analytics.uniqueVisitors

        // Calculate changes (mock data - would compare with previous period)
        viewsChange = 12.5
        followersChange = 8.3
        engagementChange = -2.1
        reachChange = 15.7
    }

    private func generateChartData() {
        let calendar = Calendar.current
        let today = Date()

        viewsData = (0..<selectedTimeRange.days).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!

            // Generate mock data - in production, this would come from analytics
            let baseValue = analytics?.totalViews ?? 0
            let dailyAverage = baseValue / max(selectedTimeRange.days, 1)
            let variance = Double.random(in: 0.5...1.5)
            let value = Int(Double(dailyAverage) * variance)

            let formatter = DateFormatter()
            formatter.dateFormat = selectedTimeRange == .week ? "EEE" : "MMM d"
            let label = formatter.string(from: date)

            return ChartDataPoint(date: date, value: value, label: label)
        }
    }

    private func generateEngagementData() {
        guard let analytics = analytics else {
            engagementData = []
            return
        }

        let total = analytics.postViews + analytics.profileShares + analytics.uniqueVisitors

        engagementData = [
            EngagementMetric(
                name: "Post Views",
                value: analytics.postViews,
                percentage: total > 0 ? Double(analytics.postViews) / Double(total) * 100 : 0,
                icon: "doc.text",
                color: ColorSystem.Brand.primary
            ),
            EngagementMetric(
                name: "Profile Shares",
                value: analytics.profileShares,
                percentage: total > 0 ? Double(analytics.profileShares) / Double(total) * 100 : 0,
                icon: "square.and.arrow.up",
                color: ColorSystem.Status.success
            ),
            EngagementMetric(
                name: "Unique Visitors",
                value: analytics.uniqueVisitors,
                percentage: total > 0 ? Double(analytics.uniqueVisitors) / Double(total) * 100 : 0,
                icon: "person.2",
                color: ColorSystem.Brand.secondary
            )
        ]
    }

    private func generateTopPosts() {
        // Mock data - would come from API in production
        topPosts = [
            PostAnalytics(
                id: UUID(),
                content: "Excited to announce new education funding...",
                views: 1234,
                likes: 89,
                comments: 23,
                shares: 45,
                createdAt: Date().addingTimeInterval(-86400 * 2)
            ),
            PostAnalytics(
                id: UUID(),
                content: "Join me for a town hall this weekend...",
                views: 987,
                likes: 67,
                comments: 34,
                shares: 28,
                createdAt: Date().addingTimeInterval(-86400 * 5)
            ),
            PostAnalytics(
                id: UUID(),
                content: "Thank you to everyone who attended...",
                views: 756,
                likes: 123,
                comments: 12,
                shares: 19,
                createdAt: Date().addingTimeInterval(-86400 * 7)
            )
        ]
    }

    private func generateDemographicData() {
        // Mock data - would come from API in production
        demographicData = [
            DemographicItem(category: "Age", value: "35-44", percentage: 32),
            DemographicItem(category: "Age", value: "25-34", percentage: 28),
            DemographicItem(category: "Age", value: "45-54", percentage: 22),
            DemographicItem(category: "Location", value: "District 15", percentage: 45),
            DemographicItem(category: "Location", value: "Adjacent Districts", percentage: 35),
            DemographicItem(category: "Device", value: "Mobile", percentage: 68),
            DemographicItem(category: "Device", value: "Desktop", percentage: 32)
        ]
    }

    // MARK: - Formatting

    func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }

    func formatChange(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }

    func changeColor(_ value: Double) -> Color {
        if value > 0 {
            return ColorSystem.Status.success
        } else if value < 0 {
            return ColorSystem.Status.error
        }
        return ColorSystem.Content.secondary
    }

    // MARK: - Export

    func exportAnalytics() {
        // Generate CSV or PDF report
        HapticManager.shared.light()

        #if DEBUG
        print("[AnalyticsVM] Exporting analytics...")
        #endif
    }
}
