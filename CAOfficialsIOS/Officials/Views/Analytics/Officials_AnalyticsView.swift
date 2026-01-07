//
//  Officials_AnalyticsView.swift
//  CA Officials
//
//  Analytics dashboard view
//

import SwiftUI
import Charts

/// Analytics dashboard for viewing profile engagement
struct Officials_AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = Officials_AnalyticsViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading && !viewModel.hasData {
                // Loading state
                loadingView
            } else if let error = viewModel.error, !viewModel.hasData {
                // Error state
                errorView(error)
            } else {
                // Content
                VStack(spacing: Spacing.lg) {
                    // Time range picker
                    Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                        ForEach(Officials_AnalyticsViewModel.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)

                    // Overview stats
                    overviewSection

                    // Views chart
                    viewsChartSection

                    // Engagement breakdown
                    engagementSection

                    // Top content
                    topContentSection

                    // Premium upsell (for non-premium users)
                    if !viewModel.isPremium {
                        premiumUpsellSection
                    }
                }
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(ColorSystem.Surface.base)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    HapticManager.shared.light()
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.exportAnalytics()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await viewModel.loadAnalytics()
        }
        .refreshable {
            await viewModel.refresh()
            HapticManager.shared.success()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Picker skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorSystem.Content.tertiary.opacity(0.3))
                .frame(height: 32)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            // Stats grid skeleton
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(ColorSystem.Content.tertiary.opacity(0.3))
                        .frame(height: 100)
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Chart skeleton
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(ColorSystem.Content.tertiary.opacity(0.3))
                .frame(height: 250)
                .padding(.horizontal, Spacing.lg)

            // Engagement skeleton
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(ColorSystem.Content.tertiary.opacity(0.3))
                .frame(height: 200)
                .padding(.horizontal, Spacing.lg)
        }
        .shimmer()
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(ColorSystem.Content.tertiary)

            Text("Unable to load analytics")
                .font(Typography.title3Semibold)
                .foregroundStyle(ColorSystem.Content.primary)

            Text(error)
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.shared.buttonTap()
                Task {
                    await viewModel.loadAnalytics()
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

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Overview")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)
                .padding(.horizontal, Spacing.lg)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.md) {
                AnalyticsStatCard(
                    title: "Total Views",
                    value: viewModel.formatNumber(viewModel.totalViews),
                    change: viewModel.formatChange(viewModel.viewsChange),
                    positive: viewModel.viewsChange >= 0
                )

                AnalyticsStatCard(
                    title: "Unique Visitors",
                    value: viewModel.formatNumber(viewModel.profileReach),
                    change: viewModel.formatChange(viewModel.reachChange),
                    positive: viewModel.reachChange >= 0
                )

                AnalyticsStatCard(
                    title: "Followers",
                    value: viewModel.formatNumber(viewModel.totalFollowers),
                    change: viewModel.formatChange(viewModel.followersChange),
                    positive: viewModel.followersChange >= 0
                )

                AnalyticsStatCard(
                    title: "Engagement",
                    value: viewModel.formatNumber(viewModel.totalEngagement),
                    change: viewModel.formatChange(viewModel.engagementChange),
                    positive: viewModel.engagementChange >= 0
                )
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Views Chart

    private var viewsChartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Profile Views")
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(ColorSystem.Content.primary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, Spacing.lg)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if viewModel.viewsData.isEmpty {
                    // Empty state
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorSystem.Content.tertiary)

                        Text("No data available")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                } else {
                    Chart(viewModel.viewsData) { item in
                        BarMark(
                            x: .value("Day", item.label),
                            y: .value("Views", item.value)
                        )
                        .foregroundStyle(ColorSystem.Brand.primary.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }
            .padding(Spacing.md)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Engagement Section

    private var engagementSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Engagement Breakdown")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                if viewModel.engagementData.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Text("No engagement data")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                } else {
                    ForEach(Array(viewModel.engagementData.enumerated()), id: \.element.id) { index, metric in
                        EngagementRow(
                            icon: metric.icon,
                            title: metric.name,
                            value: "\(metric.value)",
                            percentage: metric.percentage
                        )

                        if index < viewModel.engagementData.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Top Content Section

    private var topContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Top Performing Posts")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                if viewModel.topPosts.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorSystem.Content.tertiary)

                        Text("No posts yet")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                } else {
                    ForEach(Array(viewModel.topPosts.enumerated()), id: \.element.id) { index, post in
                        TopPostRow(
                            title: post.content,
                            views: post.views,
                            likes: post.likes
                        )

                        if index < viewModel.topPosts.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Premium Upsell

    private var premiumUpsellSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(ColorSystem.Brand.primary)

            Text("Unlock Advanced Analytics")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)

            Text("Get detailed demographics, geographic insights, and export capabilities with CA Officials Pro")
                .font(Typography.subheadline)
                .foregroundStyle(ColorSystem.Content.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.shared.buttonTap()
                // Upgrade action
            } label: {
                Text("Learn More")
                    .font(Typography.buttonPrimary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSSecondaryButtonStyle())
        }
        .padding(Spacing.lg)
        .background(ColorSystem.Brand.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Supporting Views

struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let change: String
    let positive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorSystem.Content.secondary)

            Text(value)
                .font(Typography.title2)
                .foregroundStyle(ColorSystem.Content.primary)

            HStack(spacing: 2) {
                Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(change)
                    .font(Typography.captionSemibold)
            }
            .foregroundStyle(positive ? ColorSystem.Status.success : ColorSystem.Status.error)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

struct EngagementRow: View {
    let icon: String
    let title: String
    let value: String
    let percentage: Double

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(ColorSystem.Brand.primary)
                .frame(width: 24)

            Text(title)
                .font(Typography.subheadline)
                .foregroundStyle(ColorSystem.Content.primary)

            Spacer()

            Text(value)
                .font(Typography.subheadlineSemibold)
                .foregroundStyle(ColorSystem.Content.primary)

            Text("(\(String(format: "%.1f", percentage))%)")
                .font(Typography.caption)
                .foregroundStyle(ColorSystem.Content.tertiary)
        }
        .padding(.vertical, Spacing.sm)
    }
}

struct TopPostRow: View {
    let title: String
    let views: Int
    let likes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.subheadline)
                .foregroundStyle(ColorSystem.Content.primary)
                .lineLimit(1)

            HStack(spacing: Spacing.md) {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                    Text("\(views)")
                        .font(Typography.caption)
                }
                .foregroundStyle(ColorSystem.Content.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.system(size: 12))
                    Text("\(likes)")
                        .font(Typography.caption)
                }
                .foregroundStyle(ColorSystem.Content.secondary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Officials_AnalyticsView()
        }
    }
}
#endif
