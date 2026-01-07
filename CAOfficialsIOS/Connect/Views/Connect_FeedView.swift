//
//  Connect_FeedView.swift
//  CA Officials
//
//  Main feed view for Connect module
//

import SwiftUI

struct Connect_FeedView: View {
    @StateObject private var feedService = Connect_FeedService.shared
    @StateObject private var postService = Connect_PostService.shared
    @StateObject private var followService = Connect_FollowService.shared

    @State private var selectedFilter: FeedFilter = .forYou
    @State private var showingCompose = false
    @State private var selectedPost: Connect_Post?
    @State private var showingComments = false
    @State private var showingOfficialProfile = false
    @State private var selectedOfficialId: UUID?
    @State private var searchText = ""
    @State private var showingSearch = false

    enum FeedFilter: String, CaseIterable {
        case forYou = "For You"
        case following = "Following"
        case events = "Events"
        case polls = "Polls"

        var postType: Connect_Post.PostType? {
            switch self {
            case .forYou, .following: return nil
            case .events: return .event
            case .polls: return .poll
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorSystem.Gradients.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter tabs
                    filterTabs

                    // Feed content
                    feedContent
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSearch = true
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCompose = true
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .refreshable {
                await refreshFeed()
            }
            .task {
                await loadInitialData()
            }
            .task(id: selectedFilter) {
                await loadFilteredFeed()
            }
            .sheet(isPresented: $showingCompose) {
                Connect_ComposeSheet()
            }
            .sheet(item: $selectedPost) { post in
                Connect_CommentsSheet(post: post)
            }
            .sheet(isPresented: $showingSearch) {
                Connect_SearchView()
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(FeedFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(ColorSystem.Surface.elevated.opacity(0.8))
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        Group {
            if feedService.isLoading && feedService.posts.isEmpty {
                loadingState
            } else if let error = feedService.error, feedService.posts.isEmpty {
                errorState(error)
            } else if feedService.posts.isEmpty {
                emptyState
            } else {
                ZStack {
                    postList

                    // Loading overlay during filter change
                    if feedService.isLoading {
                        VStack {
                            Spacer()
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading...")
                                    .font(Typography.caption)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(ColorSystem.Content.primary.opacity(0.8))
                            .clipShape(Capsule())
                            .padding(.bottom, Spacing.xl)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: feedService.isLoading)
                    }
                }
            }
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(ColorSystem.Status.error)

            Text("Unable to load feed")
                .font(Typography.title3Semibold)
                .foregroundStyle(ColorSystem.Content.primary)

            Text(error)
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.shared.buttonTap()
                Task { await refreshFeed() }
            } label: {
                Text("Try Again")
                    .font(Typography.buttonPrimary)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(ColorSystem.Brand.primary)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonPostCard()
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundStyle(ColorSystem.Content.tertiary)

            Text("No posts yet")
                .font(Typography.title2)
                .foregroundStyle(ColorSystem.Content.primary)

            Text(emptyStateMessage)
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
                .multilineTextAlignment(.center)

            if selectedFilter == .following {
                Button {
                    showingSearch = true
                } label: {
                    Text("Find Officials to Follow")
                        .font(Typography.buttonPrimary)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(ColorSystem.Brand.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .forYou:
            return "Be the first to see what your representatives are sharing."
        case .following:
            return "Follow officials to see their posts here."
        case .events:
            return "No upcoming events from officials."
        case .polls:
            return "No active polls right now."
        }
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(feedService.posts) { post in
                    Connect_PostCard(
                        post: post,
                        onLike: { Task { await handleLike(post) } },
                        onComment: { selectedPost = post },
                        onShare: { handleShare(post) },
                        onBookmark: { Task { await handleBookmark(post) } },
                        onOfficialTap: { showOfficialProfile(post.officialId) }
                    )
                    .onAppear {
                        // Load more when reaching near end
                        if post.id == feedService.posts.last?.id {
                            Task { await feedService.loadMore() }
                        }
                    }
                }

                if feedService.isLoading && !feedService.posts.isEmpty {
                    ProgressView()
                        .padding()
                }

                if !feedService.hasMorePosts && !feedService.posts.isEmpty {
                    Text("You're all caught up!")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.tertiary)
                        .padding()
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadInitialData() async {
        await feedService.fetchFeed()
        await followService.fetchFollowedOfficials()
    }

    private func refreshFeed() async {
        await feedService.refresh()
    }

    private func loadFilteredFeed() async {
        switch selectedFilter {
        case .forYou:
            await feedService.refresh()
        case .following:
            _ = await feedService.fetchFollowingFeed()
        case .events:
            _ = await feedService.fetchPostsByType(.event)
        case .polls:
            _ = await feedService.fetchPostsByType(.poll)
        }
    }

    private func handleLike(_ post: Connect_Post) async {
        let success = await postService.likePost(postId: post.id)
        if success {
            var updatedPost = post
            updatedPost.likeCount += 1
            feedService.updatePostInCache(updatedPost)
        }
    }

    private func handleBookmark(_ post: Connect_Post) async {
        _ = await postService.bookmarkPost(postId: post.id)
    }

    private func handleShare(_ post: Connect_Post) {
        // Share sheet
        let shareText = "\(post.content)\n\nShared from CA Officials"
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        Task {
            _ = await postService.sharePost(postId: post.id)
        }
    }

    private func showOfficialProfile(_ officialId: UUID) {
        selectedOfficialId = officialId
        showingOfficialProfile = true
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.subheadlineMedium)
                .foregroundStyle(isSelected ? .white : ColorSystem.Content.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? ColorSystem.Brand.primary : ColorSystem.Surface.elevated)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(ColorSystem.Border.subtle, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton Post Card

private struct SkeletonPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(ColorSystem.Border.subtle)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorSystem.Border.subtle)
                        .frame(width: 120, height: 14)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorSystem.Border.subtle)
                        .frame(width: 80, height: 12)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorSystem.Border.subtle)
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorSystem.Border.subtle)
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorSystem.Border.subtle)
                    .frame(width: 200, height: 14)
            }

            HStack(spacing: Spacing.lg) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorSystem.Border.subtle)
                        .frame(width: 60, height: 30)
                }
            }
        }
        .padding()
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .shimmering()
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.modifier(FeedShimmerModifier())
    }
}

private struct FeedShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Search View

struct Connect_SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var followService = Connect_FollowService.shared

    @State private var searchText = ""
    @State private var searchResults: [Connect_FollowableOfficial] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ColorSystem.Content.tertiary)

                    TextField("Search officials", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorSystem.Content.tertiary)
                        }
                    }
                }
                .padding(Spacing.md)
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .padding()

                // Results
                if searchText.isEmpty {
                    suggestedSection
                } else if isSearching {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .background(ColorSystem.Gradients.appBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.isEmpty else {
                    searchResults = []
                    return
                }

                searchTask = Task {
                    isSearching = true
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    searchResults = await followService.searchOfficials(query: newValue)
                    isSearching = false
                }
            }
            .task {
                await followService.fetchSuggestedOfficials()
            }
        }
    }

    private var suggestedSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Suggested Officials")
                    .font(Typography.title3Semibold)
                    .foregroundStyle(ColorSystem.Content.primary)
                    .padding(.horizontal)

                ForEach(followService.suggestedOfficials) { official in
                    OfficialRow(official: official)
                }
            }
            .padding(.vertical)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(ColorSystem.Content.tertiary)

            Text("No officials found")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)

            Text("Try a different search term")
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { official in
                    OfficialRow(official: official)
                }
            }
        }
    }
}

// MARK: - Official Row

private struct OfficialRow: View {
    let official: Connect_FollowableOfficial
    @StateObject private var followService = Connect_FollowService.shared
    @State private var isFollowing: Bool
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(official: Connect_FollowableOfficial) {
        self.official = official
        self._isFollowing = State(initialValue: official.isFollowing)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(ColorSystem.Brand.primary.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(official.name.prefix(1)))
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(official.name)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.primary)

                    if official.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }

                if let title = official.title {
                    Text(title)
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.secondary)
                        .lineLimit(1)
                }

                Text("\(official.followerCount) followers")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.tertiary)
            }

            Spacer()

            Button {
                toggleFollow()
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 80)
                        .padding(.vertical, Spacing.sm)
                } else {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(Typography.buttonPrimary)
                        .foregroundStyle(isFollowing ? ColorSystem.Content.primary : .white)
                        .padding(.horizontal, Spacing.md)
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
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding()
        .background(ColorSystem.Surface.elevated)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func toggleFollow() {
        guard !isLoading else { return }

        HapticManager.shared.light()
        isLoading = true

        Task {
            let success: Bool
            if isFollowing {
                success = await followService.unfollowOfficial(officialId: official.id)
            } else {
                success = await followService.followOfficial(officialId: official.id)
            }

            await MainActor.run {
                isLoading = false

                if success {
                    isFollowing.toggle()
                    HapticManager.shared.success()
                } else {
                    errorMessage = isFollowing
                        ? "Failed to unfollow. Please try again."
                        : "Failed to follow. Please try again."
                    showingError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Connect_FeedView()
}
#endif
