//
//  Connect_CommentsSheet.swift
//  CA Officials
//
//  Sheet for viewing and adding comments on a post
//

import SwiftUI

struct Connect_CommentsSheet: View {
    let post: Connect_Post

    @Environment(\.dismiss) private var dismiss
    @StateObject private var postService = Connect_PostService.shared

    @State private var comments: [Connect_Comment] = []
    @State private var isLoading = true
    @State private var commentText = ""
    @State private var replyingTo: Connect_Comment?
    @State private var isSubmitting = false

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Post summary
                postSummary

                Divider()

                // Comments list
                if isLoading {
                    loadingState
                } else if comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }

                Divider()

                // Comment input
                commentInput
            }
            .background(ColorSystem.Gradients.appBackground)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadComments()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Post Summary

    private var postSummary: some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            Circle()
                .fill(ColorSystem.Brand.primary.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(post.official?.name.prefix(1) ?? "O"))
                        .font(Typography.subheadlineSemibold)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(post.official?.name ?? "Official")
                        .font(Typography.subheadlineSemibold)
                        .foregroundStyle(ColorSystem.Content.primary)

                    if post.official?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }

                Text(post.content)
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(ColorSystem.Surface.elevated)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(ColorSystem.Content.tertiary)

            Text("No comments yet")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(ColorSystem.Content.primary)

            Text("Be the first to share your thoughts")
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)

            Spacer()
        }
    }

    // MARK: - Comments List

    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        onReply: { replyingTo = comment },
                        onLike: { Task { await likeComment(comment) } }
                    )

                    // Replies
                    if let replies = comment.replies, !replies.isEmpty {
                        ForEach(replies) { reply in
                            CommentRow(
                                comment: reply,
                                isReply: true,
                                onReply: { replyingTo = comment },
                                onLike: { Task { await likeComment(reply) } }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        VStack(spacing: 0) {
            // Reply indicator
            if let replyingTo = replyingTo {
                HStack {
                    Text("Replying to \(replyingTo.user?.displayName ?? "comment")")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.secondary)

                    Spacer()

                    Button {
                        self.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorSystem.Content.tertiary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
            }

            HStack(spacing: Spacing.sm) {
                TextField(
                    replyingTo != nil ? "Write a reply..." : "Add a comment...",
                    text: $commentText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)

                Button {
                    Task { await submitComment() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                commentText.isEmpty
                                    ? ColorSystem.Content.disabled
                                    : ColorSystem.Brand.primary
                            )
                    }
                }
                .disabled(commentText.isEmpty || isSubmitting)
            }
            .padding()
        }
        .background(ColorSystem.Surface.elevated)
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        comments = await postService.fetchComments(postId: post.id)
        isLoading = false
    }

    private func submitComment() async {
        guard !commentText.isEmpty else { return }

        isSubmitting = true
        HapticManager.shared.light()

        let newComment = await postService.addComment(
            postId: post.id,
            content: commentText,
            parentId: replyingTo?.id
        )

        isSubmitting = false

        if let comment = newComment {
            if let parentId = replyingTo?.id,
               let parentIndex = comments.firstIndex(where: { $0.id == parentId }) {
                // Add as reply
                if comments[parentIndex].replies == nil {
                    comments[parentIndex].replies = []
                }
                comments[parentIndex].replies?.append(comment)
            } else {
                // Add as top-level comment
                comments.append(comment)
            }

            commentText = ""
            replyingTo = nil
            HapticManager.shared.success()
        } else {
            HapticManager.shared.error()
        }
    }

    private func likeComment(_ comment: Connect_Comment) async {
        _ = await postService.likeComment(commentId: comment.id)
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: Connect_Comment
    var isReply: Bool = false
    let onReply: () -> Void
    let onLike: () -> Void

    @State private var isLiked = false
    @State private var likeCount: Int

    init(
        comment: Connect_Comment,
        isReply: Bool = false,
        onReply: @escaping () -> Void,
        onLike: @escaping () -> Void
    ) {
        self.comment = comment
        self.isReply = isReply
        self.onReply = onReply
        self.onLike = onLike
        self._likeCount = State(initialValue: comment.likeCount)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Indent for replies
            if isReply {
                Color.clear
                    .frame(width: 32)
            }

            // Avatar
            Circle()
                .fill(comment.user?.isOfficial == true
                    ? ColorSystem.Brand.primary.opacity(0.2)
                    : ColorSystem.Border.subtle
                )
                .frame(width: isReply ? 28 : 36, height: isReply ? 28 : 36)
                .overlay {
                    if let displayName = comment.user?.displayName {
                        Text(String(displayName.prefix(1)))
                            .font(isReply ? Typography.caption : Typography.subheadlineMedium)
                            .foregroundStyle(
                                comment.user?.isOfficial == true
                                    ? ColorSystem.Brand.primary
                                    : ColorSystem.Content.secondary
                            )
                    } else {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(ColorSystem.Content.tertiary)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                // Header
                HStack(spacing: Spacing.xs) {
                    Text(comment.user?.displayName ?? "User")
                        .font(Typography.subheadlineSemibold)
                        .foregroundStyle(ColorSystem.Content.primary)

                    if comment.user?.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }

                    Text("·")
                        .foregroundStyle(ColorSystem.Content.tertiary)

                    Text(comment.timeAgo)
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.tertiary)
                }

                // Content
                Text(comment.content)
                    .font(Typography.body)
                    .foregroundStyle(ColorSystem.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Actions
                HStack(spacing: Spacing.lg) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isLiked.toggle()
                            likeCount += isLiked ? 1 : -1
                        }
                        HapticManager.shared.light()
                        onLike()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? .red : ColorSystem.Content.tertiary)

                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorSystem.Content.tertiary)
                            }
                        }
                    }

                    if !isReply {
                        Button {
                            onReply()
                            HapticManager.shared.light()
                        } label: {
                            Text("Reply")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.tertiary)
                        }
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Connect_CommentsSheet(post: .preview)
}
#endif
