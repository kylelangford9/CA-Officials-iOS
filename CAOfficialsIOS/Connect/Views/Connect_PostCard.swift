//
//  Connect_PostCard.swift
//  CA Officials
//
//  Card component for displaying a post in the feed
//

import SwiftUI

struct Connect_PostCard: View {
    let post: Connect_Post
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onBookmark: () -> Void
    let onOfficialTap: () -> Void

    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var likeCount: Int
    @State private var selectedPollOption: Int?

    init(
        post: Connect_Post,
        onLike: @escaping () -> Void = {},
        onComment: @escaping () -> Void = {},
        onShare: @escaping () -> Void = {},
        onBookmark: @escaping () -> Void = {},
        onOfficialTap: @escaping () -> Void = {}
    ) {
        self.post = post
        self.onLike = onLike
        self.onComment = onComment
        self.onShare = onShare
        self.onBookmark = onBookmark
        self.onOfficialTap = onOfficialTap
        self._likeCount = State(initialValue: post.likeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            headerSection

            // Content
            contentSection

            // Media (if any)
            if post.hasMedia {
                mediaSection
            }

            // Event details (if event post)
            if post.isEvent {
                eventSection
            }

            // Poll (if poll post)
            if post.isPoll {
                pollSection
            }

            // Link preview (if has link)
            if let linkPreview = post.linkPreview {
                linkPreviewSection(linkPreview)
            }

            // Engagement stats
            engagementStats

            Divider()
                .background(ColorSystem.Border.subtle)

            // Action buttons
            actionButtons
        }
        .padding(Spacing.md)
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: Spacing.sm) {
            // Official avatar
            Button(action: onOfficialTap) {
                officialAvatar
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Button(action: onOfficialTap) {
                        Text(post.official?.name ?? "Official")
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(ColorSystem.Content.primary)
                    }
                    .buttonStyle(.plain)

                    if post.official?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }

                    if post.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(ColorSystem.Content.tertiary)
                    }
                }

                HStack(spacing: Spacing.xs) {
                    if let title = post.official?.title {
                        Text(title)
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Content.secondary)
                            .lineLimit(1)
                    }

                    Text("·")
                        .foregroundStyle(ColorSystem.Content.tertiary)

                    Text(post.timeAgo)
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.tertiary)
                }
            }

            Spacer()

            // Post type badge
            postTypeBadge
        }
    }

    private var officialAvatar: some View {
        Group {
            if let photoUrl = post.official?.photoUrl,
               let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        avatarShimmer
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(ColorSystem.Brand.primary.opacity(0.1))
            .overlay {
                Text(String(post.official?.name.prefix(1) ?? "O"))
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(ColorSystem.Brand.primary)
            }
    }

    private var avatarShimmer: some View {
        Circle()
            .fill(ColorSystem.Border.subtle)
            .modifier(PostCardShimmerModifier())
    }

    private var postTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: post.postType.icon)
            Text(post.postType.displayName)
        }
        .font(Typography.caption)
        .foregroundStyle(ColorSystem.Brand.primary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(ColorSystem.Brand.primary.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Content

    private var contentSection: some View {
        Text(post.content)
            .font(Typography.body)
            .foregroundStyle(ColorSystem.Content.primary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Media

    private var mediaSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(post.mediaUrls, id: \.self) { urlString in
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(ColorSystem.Border.subtle)
                                    .overlay {
                                        VStack(spacing: Spacing.sm) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 24))
                                                .foregroundStyle(ColorSystem.Content.tertiary)
                                            Text("Failed to load")
                                                .font(Typography.caption)
                                                .foregroundStyle(ColorSystem.Content.tertiary)
                                        }
                                    }
                            case .empty:
                                Rectangle()
                                    .fill(ColorSystem.Border.subtle)
                                    .modifier(PostCardShimmerModifier())
                            @unknown default:
                                Rectangle()
                                    .fill(ColorSystem.Border.subtle)
                            }
                        }
                        .frame(width: post.mediaUrls.count == 1 ? nil : 200, height: 200)
                        .frame(maxWidth: post.mediaUrls.count == 1 ? .infinity : nil)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
            }
        }
    }

    // MARK: - Event

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "calendar")
                    .foregroundStyle(ColorSystem.Brand.primary)

                if let eventDate = post.eventDate {
                    Text(eventDate, style: .date)
                        .font(Typography.subheadlineMedium)

                    Text("at")
                        .foregroundStyle(ColorSystem.Content.secondary)

                    Text(eventDate, style: .time)
                        .font(Typography.subheadlineMedium)
                }
            }

            if let location = post.eventLocation {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "location")
                        .foregroundStyle(ColorSystem.Brand.primary)

                    Text(location)
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Content.secondary)
                }
            }

            if post.eventUrl != nil {
                Button {
                    // Open RSVP link
                } label: {
                    Text("RSVP")
                        .font(Typography.buttonPrimary)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorSystem.Brand.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorSystem.Brand.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // MARK: - Poll

    private var pollSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let options = post.pollOptions {
                let totalVotes = options.reduce(0) { $0 + $1.voteCount }

                ForEach(options) { option in
                    PollOptionRow(
                        option: option,
                        totalVotes: totalVotes,
                        isSelected: selectedPollOption == option.index,
                        hasVoted: selectedPollOption != nil
                    ) {
                        if selectedPollOption == nil {
                            selectedPollOption = option.index
                            HapticManager.shared.light()
                        }
                    }
                }

                HStack {
                    Text("\(totalVotes) votes")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.secondary)

                    if let endsAt = post.pollEndsAt {
                        Text("·")
                            .foregroundStyle(ColorSystem.Content.tertiary)

                        if endsAt > Date() {
                            Text("Ends \(endsAt, style: .relative)")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.secondary)
                        } else {
                            Text("Ended")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Link Preview

    private func linkPreviewSection(_ preview: Connect_Post.LinkPreview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let imageUrl = preview.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(ColorSystem.Border.subtle)
                            .overlay {
                                Image(systemName: "link")
                                    .font(.system(size: 24))
                                    .foregroundStyle(ColorSystem.Content.tertiary)
                            }
                    case .empty:
                        Rectangle()
                            .fill(ColorSystem.Border.subtle)
                            .modifier(PostCardShimmerModifier())
                    @unknown default:
                        Rectangle()
                            .fill(ColorSystem.Border.subtle)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }

            VStack(alignment: .leading, spacing: 4) {
                if let siteName = preview.siteName {
                    Text(siteName.uppercased())
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.tertiary)
                }

                if let title = preview.title {
                    Text(title)
                        .font(Typography.subheadlineSemibold)
                        .foregroundStyle(ColorSystem.Content.primary)
                        .lineLimit(2)
                }

                if let description = preview.description {
                    Text(description)
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(Spacing.sm)
        .background(ColorSystem.Border.subtle.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // MARK: - Engagement Stats

    private var engagementStats: some View {
        HStack(spacing: Spacing.md) {
            if likeCount > 0 {
                Text("\(likeCount) likes")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.secondary)
            }

            if post.commentCount > 0 {
                Text("\(post.commentCount) comments")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.secondary)
            }

            if post.shareCount > 0 {
                Text("\(post.shareCount) shares")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 0) {
            ActionButton(
                icon: isLiked ? "heart.fill" : "heart",
                label: "Like",
                isActive: isLiked,
                activeColor: .red
            ) {
                withAnimation(.spring(response: 0.3)) {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }
                HapticManager.shared.light()
                onLike()
            }

            ActionButton(
                icon: "bubble.right",
                label: "Comment",
                isActive: false
            ) {
                HapticManager.shared.light()
                onComment()
            }

            ActionButton(
                icon: "square.and.arrow.up",
                label: "Share",
                isActive: false
            ) {
                HapticManager.shared.light()
                onShare()
            }

            ActionButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                label: "Save",
                isActive: isBookmarked,
                activeColor: ColorSystem.Brand.primary
            ) {
                withAnimation(.spring(response: 0.3)) {
                    isBookmarked.toggle()
                }
                HapticManager.shared.light()
                onBookmark()
            }
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var activeColor: Color = ColorSystem.Brand.primary

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(label)
                    .font(Typography.caption)
            }
            .foregroundStyle(isActive ? activeColor : ColorSystem.Content.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Poll Option Row

private struct PollOptionRow: View {
    let option: Connect_Post.PollOption
    let totalVotes: Int
    let isSelected: Bool
    let hasVoted: Bool
    let onTap: () -> Void

    private var percentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(option.voteCount) / Double(totalVotes)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                // Background progress
                if hasVoted {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(isSelected ? ColorSystem.Brand.primary.opacity(0.2) : ColorSystem.Border.subtle)
                            .frame(width: geometry.size.width * percentage)
                    }
                }

                HStack {
                    Text(option.text)
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Content.primary)

                    Spacer()

                    if hasVoted {
                        Text("\(Int(percentage * 100))%")
                            .font(Typography.subheadlineSemibold)
                            .foregroundStyle(isSelected ? ColorSystem.Brand.primary : ColorSystem.Content.secondary)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .frame(height: 44)
            .background(hasVoted ? Color.clear : ColorSystem.Border.subtle.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(
                        isSelected ? ColorSystem.Brand.primary : ColorSystem.Border.subtle,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(hasVoted)
    }
}

// MARK: - Shimmer Modifier

private struct PostCardShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.6)
                    .animation(
                        .linear(duration: 1.2)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
            )
            .clipped()
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            Connect_PostCard(post: .preview)
            Connect_PostCard(post: .previewEvent)
            Connect_PostCard(post: .previewPoll)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
#endif
