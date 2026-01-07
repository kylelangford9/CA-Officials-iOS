//
//  Connect_FeedViewModel.swift
//  CA Officials
//
//  ViewModel for the Connect feed
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class Connect_FeedViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedFilter: FeedFilter = .forYou
    @Published private(set) var posts: [Connect_Post] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasMorePosts = true
    @Published private(set) var error: String?

    @Published var userInteractions: [UUID: Set<Connect_InteractionType>] = [:]

    enum FeedFilter: String, CaseIterable, Identifiable {
        case forYou = "For You"
        case following = "Following"
        case events = "Events"
        case polls = "Polls"
        case announcements = "Announcements"

        var id: String { rawValue }

        var postType: Connect_Post.PostType? {
            switch self {
            case .forYou, .following: return nil
            case .events: return .event
            case .polls: return .poll
            case .announcements: return .announcement
            }
        }

        var icon: String {
            switch self {
            case .forYou: return "sparkles"
            case .following: return "person.2"
            case .events: return "calendar"
            case .polls: return "chart.bar"
            case .announcements: return "megaphone"
            }
        }
    }

    // MARK: - Services

    private let feedService = Connect_FeedService.shared
    private let postService = Connect_PostService.shared
    private let followService = Connect_FollowService.shared

    private var cancellables = Set<AnyCancellable>()
    private var loadMoreTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var isEmpty: Bool {
        posts.isEmpty && !isLoading
    }

    var emptyStateMessage: String {
        switch selectedFilter {
        case .forYou:
            return "No posts yet. Follow some officials to see their updates!"
        case .following:
            return "No posts from officials you follow."
        case .events:
            return "No upcoming events."
        case .polls:
            return "No active polls right now."
        case .announcements:
            return "No recent announcements."
        }
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        feedService.$posts
            .receive(on: DispatchQueue.main)
            .assign(to: &$posts)

        feedService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        feedService.$isRefreshing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRefreshing)

        feedService.$hasMorePosts
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasMorePosts)

        feedService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        $selectedFilter
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadFeed() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadFeed() async {
        switch selectedFilter {
        case .forYou:
            await feedService.fetchFeed(refresh: true)
        case .following:
            posts = await feedService.fetchFollowingFeed()
        case .events:
            posts = await feedService.fetchPostsByType(.event)
        case .polls:
            posts = await feedService.fetchPostsByType(.poll)
        case .announcements:
            posts = await feedService.fetchPostsByType(.announcement)
        }

        // Load interactions for visible posts
        await loadInteractions(for: Array(posts.prefix(10)))
    }

    func refresh() async {
        await loadFeed()
    }

    func loadMore() async {
        guard hasMorePosts, !isLoading, selectedFilter == .forYou else { return }

        loadMoreTask?.cancel()
        loadMoreTask = Task {
            await feedService.loadMore()
        }
    }

    func loadMoreIfNeeded(currentPost: Connect_Post) {
        guard let lastPost = posts.last,
              currentPost.id == lastPost.id else { return }

        Task { await loadMore() }
    }

    // MARK: - Interactions

    private func loadInteractions(for posts: [Connect_Post]) async {
        for post in posts {
            if userInteractions[post.id] == nil {
                let interactions = await feedService.getUserInteractions(postId: post.id)
                userInteractions[post.id] = interactions
            }
        }
    }

    func isLiked(_ post: Connect_Post) -> Bool {
        userInteractions[post.id]?.contains(.like) ?? false
    }

    func isBookmarked(_ post: Connect_Post) -> Bool {
        userInteractions[post.id]?.contains(.bookmark) ?? false
    }

    func toggleLike(for post: Connect_Post) async {
        let wasLiked = isLiked(post)

        // Optimistic update
        if wasLiked {
            userInteractions[post.id]?.remove(.like)
            updatePostCount(post.id, keyPath: \.likeCount, delta: -1)
        } else {
            if userInteractions[post.id] == nil {
                userInteractions[post.id] = []
            }
            userInteractions[post.id]?.insert(.like)
            updatePostCount(post.id, keyPath: \.likeCount, delta: 1)
        }

        HapticManager.shared.light()

        // Perform actual request
        let success: Bool
        if wasLiked {
            success = await postService.unlikePost(postId: post.id)
        } else {
            success = await postService.likePost(postId: post.id)
        }

        // Revert on failure
        if !success {
            if wasLiked {
                userInteractions[post.id]?.insert(.like)
                updatePostCount(post.id, keyPath: \.likeCount, delta: 1)
            } else {
                userInteractions[post.id]?.remove(.like)
                updatePostCount(post.id, keyPath: \.likeCount, delta: -1)
            }
            HapticManager.shared.error()
        }
    }

    func toggleBookmark(for post: Connect_Post) async {
        let wasBookmarked = isBookmarked(post)

        // Optimistic update
        if wasBookmarked {
            userInteractions[post.id]?.remove(.bookmark)
        } else {
            if userInteractions[post.id] == nil {
                userInteractions[post.id] = []
            }
            userInteractions[post.id]?.insert(.bookmark)
        }

        HapticManager.shared.light()

        // Perform actual request
        let success: Bool
        if wasBookmarked {
            success = await postService.unbookmarkPost(postId: post.id)
        } else {
            success = await postService.bookmarkPost(postId: post.id)
        }

        // Revert on failure
        if !success {
            if wasBookmarked {
                userInteractions[post.id]?.insert(.bookmark)
            } else {
                userInteractions[post.id]?.remove(.bookmark)
            }
            HapticManager.shared.error()
        }
    }

    func sharePost(_ post: Connect_Post) {
        let shareText = "\(post.content)\n\nShared from CA Officials"

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        // Record share
        Task {
            _ = await postService.sharePost(postId: post.id)
            updatePostCount(post.id, keyPath: \.shareCount, delta: 1)
        }
    }

    // MARK: - Poll Voting

    func votePoll(post: Connect_Post, optionIndex: Int) async -> Bool {
        let success = await postService.votePoll(postId: post.id, optionIndex: optionIndex)

        if success {
            // Update local poll data
            if let index = posts.firstIndex(where: { $0.id == post.id }),
               var options = posts[index].pollOptions {
                options[optionIndex].voteCount += 1
                posts[index].pollOptions = options
            }
            HapticManager.shared.success()
        } else {
            HapticManager.shared.error()
        }

        return success
    }

    // MARK: - Helpers

    private func updatePostCount(_ postId: UUID, keyPath: WritableKeyPath<Connect_Post, Int>, delta: Int) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index][keyPath: keyPath] += delta
        }
    }

    func updatePost(_ post: Connect_Post) {
        feedService.updatePostInCache(post)
    }
}
