//
//  Officials_DashboardViewModel.swift
//  CA Officials
//
//  ViewModel for the Officials dashboard
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class Officials_DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var profile: Officials_Official?
    @Published private(set) var analytics: Officials_ProfileAnalytics?
    @Published private(set) var recentActivity: [Officials_Activity] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var error: String?

    // Quick stats
    @Published private(set) var totalViews: Int = 0
    @Published private(set) var totalFollowers: Int = 0
    @Published private(set) var totalEngagement: Int = 0
    @Published private(set) var viewsTrend: Double = 0 // Percentage change

    // MARK: - Services

    private let profileService = Officials_ProfileService.shared
    private let analyticsService = Officials_AnalyticsService.shared
    private let followService = Connect_FollowService.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var displayName: String {
        profile?.name.components(separatedBy: " ").first ?? "there"
    }

    var verificationBadge: String {
        switch profile?.verificationStatus {
        case "verified": return "Verified"
        case "pending": return "Pending Verification"
        case "rejected": return "Verification Required"
        default: return "Unverified"
        }
    }

    var isVerified: Bool {
        profile?.verificationStatus == "verified"
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Listen to profile changes
        profileService.$currentProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
            }
            .store(in: &cancellables)

        // Listen to analytics changes
        analyticsService.$analytics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] analytics in
                self?.analytics = analytics
                self?.updateQuickStats()
            }
            .store(in: &cancellables)

        analyticsService.$recentActivity
            .receive(on: DispatchQueue.main)
            .assign(to: &$recentActivity)
    }

    // MARK: - Data Loading

    func loadDashboard() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        async let profileResult: () = profileService.fetchProfile()
        async let analyticsResult: () = loadAnalytics()
        async let activityResult: () = analyticsService.fetchRecentActivity()

        _ = await (profileResult, analyticsResult, activityResult)

        updateQuickStats()
        isLoading = false
    }

    func refresh() async {
        isRefreshing = true
        await loadDashboard()
        isRefreshing = false
    }

    private func loadAnalytics() async {
        guard let profile = profileService.profile else { return }
        await analyticsService.fetchAnalytics(officialId: profile.id)
    }

    private func updateQuickStats() {
        guard let analytics = analytics else { return }

        totalViews = analytics.totalViews
        totalFollowers = analytics.followers

        // Calculate total engagement
        totalEngagement = analytics.postViews + analytics.profileShares

        // Calculate trend (mock calculation - would compare with previous period)
        if analytics.totalViews > 0 {
            viewsTrend = 12.5 // Placeholder percentage
        }
    }

    // MARK: - Quick Actions

    func recordQuickAction(_ action: QuickAction) {
        HapticManager.shared.light()

        #if DEBUG
        print("[DashboardVM] Quick action: \(action)")
        #endif

        Task {
            guard let profile = profile else { return }

            await analyticsService.recordEvent(
                officialId: profile.id,
                eventType: "quick_action_\(action.rawValue)"
            )
        }
    }

    enum QuickAction: String {
        case createPost = "create_post"
        case editProfile = "edit_profile"
        case viewAnalytics = "view_analytics"
        case manageFollowers = "manage_followers"
        case scheduleEvent = "schedule_event"
        case shareProfile = "share_profile"
    }

    // MARK: - Profile Actions

    func shareProfile() {
        guard let profile = profile else { return }

        let shareText = "Check out \(profile.name) on CA Officials!"
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        recordQuickAction(.shareProfile)
    }

    // MARK: - Stats Formatting

    func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }

    func formatTrend(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }
}

// MARK: - Activity Formatting Extension

extension Officials_Activity {
    var formattedDescription: String {
        switch activityType {
        case "profile_view":
            return "Someone viewed your profile"
        case "post_like":
            return "Your post received a like"
        case "post_comment":
            return "Someone commented on your post"
        case "new_follower":
            return "You have a new follower"
        case "post_share":
            return "Your post was shared"
        default:
            return "Activity on your profile"
        }
    }

    var icon: String {
        switch activityType {
        case "profile_view": return "eye"
        case "post_like": return "heart.fill"
        case "post_comment": return "bubble.left.fill"
        case "new_follower": return "person.badge.plus"
        case "post_share": return "square.and.arrow.up"
        default: return "bell.fill"
        }
    }

    var iconColor: Color {
        switch activityType {
        case "profile_view": return ColorSystem.Brand.primary
        case "post_like": return .red
        case "post_comment": return ColorSystem.Brand.primary
        case "new_follower": return ColorSystem.Status.success
        case "post_share": return ColorSystem.Brand.secondary
        default: return ColorSystem.Content.secondary
        }
    }

    var timeAgo: String {
        guard let createdAt = createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
