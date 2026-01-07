//
//  Officials_DashboardView.swift
//  CA Officials
//
//  Main dashboard for verified officials
//

import SwiftUI

/// Main dashboard view for verified officials
struct Officials_DashboardView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @StateObject private var viewModel = Officials_DashboardViewModel()

    @State private var showingProfileEditor = false
    @State private var showingAnalytics = false
    @State private var showingSettings = false
    @State private var showingCompose = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.profile == nil {
                // Loading skeleton
                loadingView
            } else if let error = viewModel.error, viewModel.profile == nil {
                // Error state
                errorView(error)
            } else {
                // Content
                VStack(spacing: Spacing.lg) {
                    welcomeHeader
                    statsSection
                    quickActionsSection
                    recentActivitySection
                }
                .padding(.top, Spacing.md)
            }
        }
        .background(ColorSystem.Gradients.appBackground)
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.shared.light()
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(ColorSystem.Content.primary)
                }
            }
        }
        .task {
            await viewModel.loadDashboard()
        }
        .sheet(isPresented: $showingProfileEditor) {
            NavigationStack {
                Officials_ProfileEditorView()
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            NavigationStack {
                Officials_AnalyticsView()
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                Officials_SettingsView()
            }
        }
        .sheet(isPresented: $showingCompose) {
            Connect_ComposeSheet()
        }
        .refreshable {
            await viewModel.refresh()
            HapticManager.shared.success()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Welcome header skeleton
            HStack(spacing: Spacing.md) {
                Circle()
                    .fill(ColorSystem.Content.tertiary.opacity(0.3))
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorSystem.Content.tertiary.opacity(0.3))
                        .frame(width: 100, height: 14)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorSystem.Content.tertiary.opacity(0.3))
                        .frame(width: 150, height: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorSystem.Content.tertiary.opacity(0.3))
                        .frame(width: 120, height: 12)
                }

                Spacer()
            }
            .padding(Spacing.lg)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)

            // Stats skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(ColorSystem.Content.tertiary.opacity(0.3))
                            .frame(width: 140, height: 100)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Quick actions skeleton
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(ColorSystem.Content.tertiary.opacity(0.3))
                        .frame(height: 80)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.md)
        .shimmer()
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(ColorSystem.Status.warning)

            Text("Unable to load dashboard")
                .font(Typography.title3Semibold)
                .foregroundStyle(ColorSystem.Content.primary)

            Text(error)
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.shared.buttonTap()
                Task {
                    await viewModel.loadDashboard()
                }
            } label: {
                Text("Try Again")
                    .font(Typography.buttonPrimary)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(ColorSystem.Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        HStack(spacing: Spacing.md) {
            // Profile photo
            if let photoUrl = viewModel.profile?.photoUrl,
               let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(viewModel.greeting)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)

                    if viewModel.isVerified {
                        Officials_VerifiedBadge()
                    }
                }

                Text(viewModel.profile?.name ?? "Official")
                    .font(Typography.title3Semibold)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text(viewModel.profile?.title ?? "Government Official")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.tertiary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(ColorSystem.Brand.primary.opacity(0.2))
            .frame(width: 60, height: 60)
            .overlay(
                Text(String(viewModel.profile?.name.prefix(1) ?? "?"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ColorSystem.Brand.primary)
            )
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("This Week")
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(ColorSystem.Content.primary)

                Spacer()

                Button {
                    HapticManager.shared.light()
                    viewModel.recordQuickAction(.viewAnalytics)
                    showingAnalytics = true
                } label: {
                    Text("See All")
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    Officials_StatCard(
                        title: "Profile Views",
                        value: viewModel.formatNumber(viewModel.totalViews),
                        trend: viewModel.formatTrend(viewModel.viewsTrend),
                        trendPositive: viewModel.viewsTrend >= 0,
                        icon: "eye.fill"
                    )

                    Officials_StatCard(
                        title: "Followers",
                        value: viewModel.formatNumber(viewModel.totalFollowers),
                        trend: "+5%",
                        trendPositive: true,
                        icon: "person.2.fill"
                    )

                    Officials_StatCard(
                        title: "Engagement",
                        value: viewModel.formatNumber(viewModel.totalEngagement),
                        trend: "+2.3%",
                        trendPositive: true,
                        icon: "hand.tap.fill"
                    )
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Actions")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)
                .padding(.horizontal, Spacing.lg)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.md) {
                QuickActionButton(
                    title: "New Post",
                    icon: "square.and.pencil",
                    color: ColorSystem.Brand.primary
                ) {
                    HapticManager.shared.buttonTap()
                    viewModel.recordQuickAction(.createPost)
                    showingCompose = true
                }

                QuickActionButton(
                    title: "Edit Profile",
                    icon: "person.crop.circle",
                    color: ColorSystem.Status.info
                ) {
                    HapticManager.shared.buttonTap()
                    viewModel.recordQuickAction(.editProfile)
                    showingProfileEditor = true
                }

                QuickActionButton(
                    title: "View Analytics",
                    icon: "chart.line.uptrend.xyaxis",
                    color: ColorSystem.Status.success
                ) {
                    HapticManager.shared.buttonTap()
                    viewModel.recordQuickAction(.viewAnalytics)
                    showingAnalytics = true
                }

                QuickActionButton(
                    title: "Share Profile",
                    icon: "square.and.arrow.up",
                    color: ColorSystem.Content.secondary
                ) {
                    HapticManager.shared.buttonTap()
                    viewModel.shareProfile()
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(ColorSystem.Content.primary)

                Spacer()

                Button {
                    HapticManager.shared.light()
                } label: {
                    Text("View All")
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }
            }
            .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                if viewModel.recentActivity.isEmpty {
                    // Empty state
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorSystem.Content.tertiary)

                        Text("No recent activity")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.xl)
                } else {
                    ForEach(Array(viewModel.recentActivity.prefix(5).enumerated()), id: \.element.id) { index, activity in
                        ActivityRow(
                            icon: activity.icon,
                            iconColor: activity.iconColor,
                            text: activity.formattedDescription,
                            time: activity.timeAgo
                        )

                        if index < min(viewModel.recentActivity.count - 1, 4) {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.bottom, Spacing.xxl)
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Supporting Views

struct Officials_StatCard: View {
    let title: String
    let value: String
    let trend: String
    let trendPositive: Bool
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(ColorSystem.Brand.primary)

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: trendPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(trend)
                        .font(Typography.captionSemibold)
                }
                .foregroundStyle(trendPositive ? ColorSystem.Status.success : ColorSystem.Status.error)
            }

            Text(value)
                .font(Typography.title2)
                .foregroundStyle(ColorSystem.Content.primary)

            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorSystem.Content.secondary)
        }
        .padding(Spacing.md)
        .frame(width: 140)
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Text(title)
                    .font(Typography.subheadlineMedium)
                    .foregroundStyle(ColorSystem.Content.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
    }
}

struct ActivityRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    let time: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text(time)
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.tertiary)
            }

            Spacer()
        }
        .padding(Spacing.md)
    }
}

// MARK: - Verified Badge

struct Officials_VerifiedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 16))
            .foregroundStyle(ColorSystem.Brand.primary)
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Officials_DashboardView()
                .environmentObject(RoleManager())
        }
    }
}
#endif
