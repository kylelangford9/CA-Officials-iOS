//
//  Connect_OfficialProfileView.swift
//  CA Officials
//
//  Public profile view for officials (viewed by constituents)
//

import SwiftUI

struct Connect_OfficialProfileView: View {
    let officialId: UUID

    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedService = Connect_FeedService.shared
    @StateObject private var followService = Connect_FollowService.shared

    @State private var official: Officials_Official?
    @State private var posts: [Connect_Post] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var selectedTab: ProfileTab = .posts
    @State private var showingNotificationSettings = false

    enum ProfileTab: String, CaseIterable {
        case posts = "Posts"
        case events = "Events"
        case about = "About"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    profileHeader

                    // Stats bar
                    statsBar

                    // Tab selector
                    tabSelector

                    // Content
                    tabContent
                }
            }
            .background(ColorSystem.Gradients.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            shareProfile()
                        } label: {
                            Label("Share Profile", systemImage: "square.and.arrow.up")
                        }

                        if isFollowing {
                            Button {
                                showingNotificationSettings = true
                            } label: {
                                Label("Notification Settings", systemImage: "bell")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await loadProfile()
            }
            .sheet(isPresented: $showingNotificationSettings) {
                if let official = official {
                    NotificationSettingsSheet(officialId: official.id)
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.md) {
            // Cover gradient
            LinearGradient(
                colors: [ColorSystem.Brand.primary, ColorSystem.Brand.primary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .overlay(alignment: .bottomLeading) {
                // Avatar
                profileAvatar
                    .offset(x: Spacing.lg, y: 40)
            }

            // Profile info
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Spacer()
                    followButton
                }

                HStack(spacing: Spacing.xs) {
                    Text(official?.name ?? "Loading...")
                        .font(Typography.title2)
                        .foregroundStyle(ColorSystem.Content.primary)

                    if official?.verificationStatus == "verified" {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }

                if let title = official?.title {
                    Text(title)
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Content.secondary)
                }

                if let party = official?.party {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(partyColor(party))
                            .frame(width: 8, height: 8)

                        Text(party.capitalized)
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }
                }

                if let bio = official?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.body)
                        .foregroundStyle(ColorSystem.Content.primary)
                        .padding(.top, Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 50)
        }
    }

    private var profileAvatar: some View {
        Group {
            if let photoUrl = official?.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
        }
        .shadow(radius: 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(ColorSystem.Brand.primary.opacity(0.2))
            .overlay {
                Text(String(official?.name.prefix(1) ?? "O"))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(ColorSystem.Brand.primary)
            }
    }

    private var followButton: some View {
        Button {
            Task {
                if isFollowing {
                    let success = await followService.unfollowOfficial(officialId: officialId)
                    if success { isFollowing = false }
                } else {
                    let success = await followService.followOfficial(officialId: officialId)
                    if success { isFollowing = true }
                }
            }
            HapticManager.shared.medium()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isFollowing ? "checkmark" : "plus")
                Text(isFollowing ? "Following" : "Follow")
            }
            .font(Typography.buttonPrimary)
            .foregroundStyle(isFollowing ? ColorSystem.Content.primary : .white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(isFollowing ? ColorSystem.Surface.elevated : ColorSystem.Brand.primary)
            .clipShape(Capsule())
            .overlay {
                if isFollowing {
                    Capsule()
                        .strokeBorder(ColorSystem.Border.subtle, lineWidth: 1)
                }
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: posts.count, label: "Posts")
            statItem(value: 0, label: "Followers")  // TODO: Fetch follower count from backend
            statItem(value: calculateEngagement(), label: "Engagement")
        }
        .padding(.vertical, Spacing.md)
        .background(ColorSystem.Surface.elevated)
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(formatNumber(value))
                .font(Typography.title3Semibold)
                .foregroundStyle(ColorSystem.Content.primary)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorSystem.Content.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }

    private func calculateEngagement() -> Int {
        posts.reduce(0) { $0 + $1.totalEngagement }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.selectionChanged()
                } label: {
                    VStack(spacing: Spacing.sm) {
                        Text(tab.rawValue)
                            .font(Typography.subheadlineMedium)
                            .foregroundStyle(
                                selectedTab == tab
                                    ? ColorSystem.Brand.primary
                                    : ColorSystem.Content.secondary
                            )

                        Rectangle()
                            .fill(selectedTab == tab ? ColorSystem.Brand.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .posts:
            postsTab
        case .events:
            eventsTab
        case .about:
            aboutTab
        }
    }

    private var postsTab: some View {
        LazyVStack(spacing: Spacing.md) {
            if isLoading {
                ProgressView()
                    .padding()
            } else if posts.isEmpty {
                emptyPostsState
            } else {
                ForEach(posts.filter { $0.postType != .event }) { post in
                    Connect_PostCard(post: post)
                }
            }
        }
        .padding()
    }

    private var eventsTab: some View {
        LazyVStack(spacing: Spacing.md) {
            let events = posts.filter { $0.postType == .event }

            if events.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorSystem.Content.tertiary)

                    Text("No upcoming events")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.primary)
                }
                .padding(.vertical, Spacing.xxxl)
            } else {
                ForEach(events) { post in
                    Connect_PostCard(post: post)
                }
            }
        }
        .padding()
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Contact Info
            if let contact = official?.contactInfo {
                aboutSection(title: "Contact") {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let email = contact.officeEmail {
                            contactRow(icon: "envelope", text: email)
                        }
                        if let phone = contact.officePhone {
                            contactRow(icon: "phone", text: phone)
                        }
                        if let address = contact.officeAddress {
                            contactRow(icon: "building.2", text: address)
                        }
                    }
                }
            }

            // Social Links
            if let social = official?.socialLinks {
                aboutSection(title: "Social Media") {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let twitter = social.twitterHandle {
                            socialRow(platform: "Twitter", handle: twitter)
                        }
                        if let facebook = social.facebookUrl {
                            socialRow(platform: "Facebook", handle: facebook)
                        }
                        if let instagram = social.instagramHandle {
                            socialRow(platform: "Instagram", handle: instagram)
                        }
                        if let linkedin = social.linkedinUrl {
                            socialRow(platform: "LinkedIn", handle: linkedin)
                        }
                    }
                }
            }

            // Website
            if let website = official?.socialLinks?.websiteUrl {
                aboutSection(title: "Website") {
                    Link(destination: URL(string: website)!) {
                        HStack {
                            Image(systemName: "globe")
                            Text(website)
                                .lineLimit(1)
                        }
                        .font(Typography.body)
                        .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }
            }
        }
        .padding()
    }

    private func aboutSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.subheadlineSemibold)
                .foregroundStyle(ColorSystem.Content.secondary)

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(ColorSystem.Brand.primary)
                .frame(width: 24)

            Text(text)
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.primary)
        }
    }

    private func socialRow(platform: String, handle: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: socialIcon(for: platform))
                .foregroundStyle(ColorSystem.Brand.primary)
                .frame(width: 24)

            Text("@\(handle)")
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.primary)
        }
    }

    private func socialIcon(for platform: String) -> String {
        switch platform.lowercased() {
        case "twitter": return "at"
        case "facebook": return "f.square"
        case "instagram": return "camera"
        case "linkedin": return "link"
        default: return "globe"
        }
    }

    private var emptyPostsState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(ColorSystem.Content.tertiary)

            Text("No posts yet")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)

            Text("This official hasn't shared any posts")
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
        }
        .padding(.vertical, Spacing.xxxl)
    }

    // MARK: - Helpers

    private func partyColor(_ party: String) -> Color {
        switch party.lowercased() {
        case "democratic": return ColorSystem.Party.democratic
        case "republican": return ColorSystem.Party.republican
        default: return ColorSystem.Party.independent
        }
    }

    private func loadProfile() async {
        isLoading = true

        // Load official profile
        official = await Officials_ProfileService.shared.fetchOfficialById(officialId)

        // Load posts
        posts = await feedService.fetchOfficialPosts(officialId: officialId)

        // Check follow status
        isFollowing = followService.isFollowing(officialId: officialId)

        isLoading = false
    }

    private func shareProfile() {
        guard let official = official else { return }

        let shareText = "Check out \(official.name) on CA Officials!"
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Notification Settings Sheet

private struct NotificationSettingsSheet: View {
    let officialId: UUID

    @Environment(\.dismiss) private var dismiss
    @StateObject private var followService = Connect_FollowService.shared

    @State private var notifyPosts = true
    @State private var notifyEvents = true
    @State private var notifyPolicy = false
    @State private var followId: UUID?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("New Posts", isOn: $notifyPosts)
                    Toggle("Events", isOn: $notifyEvents)
                    Toggle("Policy Updates", isOn: $notifyPolicy)
                } header: {
                    Text("Notify me about")
                } footer: {
                    Text("Choose what notifications you want to receive from this official.")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await savePreferences() }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                await loadPreferences()
            }
        }
        .presentationDetents([.medium])
    }

    private func loadPreferences() async {
        if let follow = await followService.getFollowDetails(officialId: officialId) {
            followId = follow.id
            notifyPosts = follow.notifyPosts
            notifyEvents = follow.notifyEvents
            notifyPolicy = follow.notifyPolicy
        }
    }

    private func savePreferences() async {
        guard let followId = followId else { return }

        isSaving = true

        let success = await followService.updateNotificationPreferences(
            followId: followId,
            notifyPosts: notifyPosts,
            notifyEvents: notifyEvents,
            notifyPolicy: notifyPolicy
        )

        isSaving = false

        if success {
            HapticManager.shared.success()
            dismiss()
        } else {
            HapticManager.shared.error()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Connect_OfficialProfileView(officialId: UUID())
}
#endif
