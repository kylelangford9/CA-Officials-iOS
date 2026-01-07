//
//  Connect_ComposeSheet.swift
//  CA Officials
//
//  Sheet for composing new posts
//

import SwiftUI
import PhotosUI

struct Connect_ComposeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var postService = Connect_PostService.shared
    @StateObject private var profileService = Officials_ProfileService.shared

    @State private var content = ""
    @State private var selectedPostType: Connect_Post.PostType = .update
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []

    // Event fields
    @State private var eventDate = Date()
    @State private var eventLocation = ""
    @State private var eventUrl = ""

    // Poll fields
    @State private var pollOptions: [String] = ["", ""]
    @State private var pollDuration: PollDuration = .oneDay

    // Link
    @State private var linkUrl = ""

    // Scheduling
    @State private var isScheduled = false
    @State private var scheduledDate = Date()

    @State private var isPosting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""

    @FocusState private var isContentFocused: Bool

    enum PollDuration: String, CaseIterable {
        case oneHour = "1 hour"
        case sixHours = "6 hours"
        case oneDay = "1 day"
        case threeDays = "3 days"
        case oneWeek = "1 week"

        var interval: TimeInterval {
            switch self {
            case .oneHour: return 3600
            case .sixHours: return 3600 * 6
            case .oneDay: return 86400
            case .threeDays: return 86400 * 3
            case .oneWeek: return 86400 * 7
            }
        }
    }

    private var canPost: Bool {
        // Basic content validation
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty && content.count <= 2000 else {
            return false
        }

        // Post-type specific validation
        switch selectedPostType {
        case .poll:
            // Polls need at least 2 non-empty options
            let validOptions = pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard validOptions.count >= 2 else { return false }

        case .event:
            // Events need a location
            guard !eventLocation.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
            // Event date must be in the future (already enforced by DatePicker, but double-check)
            guard eventDate > Date() else { return false }

        default:
            break
        }

        // URL validation if provided
        if !linkUrl.isEmpty && !isValidUrl(linkUrl) {
            return false
        }

        if selectedPostType == .event && !eventUrl.isEmpty && !isValidUrl(eventUrl) {
            return false
        }

        return true
    }

    private var characterCount: Int {
        content.count
    }

    private func isValidUrl(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private var validPollOptionsCount: Int {
        pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Post type selector
                    postTypeSelector

                    // Content input
                    contentInput

                    // Type-specific fields
                    switch selectedPostType {
                    case .event:
                        eventFields
                    case .poll:
                        pollFields
                    default:
                        EmptyView()
                    }

                    // Media picker
                    if selectedPostType != .poll {
                        mediaPicker
                    }

                    // Link input
                    if selectedPostType == .update || selectedPostType == .announcement {
                        linkInput
                    }

                    // Schedule toggle
                    scheduleSection
                }
                .padding()
            }
            .background(ColorSystem.Gradients.appBackground)
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isPosting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .disabled(isPosting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await createPost() }
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text(isScheduled ? "Schedule" : "Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canPost || isPosting)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Text("\(characterCount)/2000")
                            .font(Typography.caption)
                            .foregroundStyle(characterCount > 1800 ? ColorSystem.Status.warning : ColorSystem.Content.tertiary)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
            .onAppear {
                isContentFocused = true
            }
        }
    }

    // MARK: - Post Type Selector

    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Post Type")
                .font(Typography.subheadlineSemibold)
                .foregroundStyle(ColorSystem.Content.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Connect_Post.PostType.allCases, id: \.self) { type in
                        PostTypeChip(
                            type: type,
                            isSelected: selectedPostType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPostType = type
                            }
                            HapticManager.shared.selectionChanged()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Content Input

    private var contentInput: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                // Official avatar
                Circle()
                    .fill(ColorSystem.Brand.primary.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay {
                        if let profile = profileService.profile {
                            Text(String(profile.name.prefix(1)))
                                .font(Typography.bodyEmphasized)
                                .foregroundStyle(ColorSystem.Brand.primary)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(ColorSystem.Brand.primary)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profileService.profile?.name ?? "Your Name")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.primary)

                    Text(profileService.profile?.title ?? "Your Title")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.secondary)
                }
            }

            TextEditor(text: $content)
                .font(Typography.body)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .focused($isContentFocused)
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text(placeholderText)
                            .font(Typography.body)
                            .foregroundStyle(ColorSystem.Content.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding()
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var placeholderText: String {
        switch selectedPostType {
        case .update: return "What's on your mind?"
        case .announcement: return "Share an important announcement..."
        case .event: return "Tell people about your event..."
        case .policy: return "Share your policy position..."
        case .media: return "Add a caption to your media..."
        case .poll: return "Ask your constituents a question..."
        }
    }

    // MARK: - Event Fields

    private var isEventLocationValid: Bool {
        !eventLocation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEventUrlValid: Bool {
        eventUrl.isEmpty || isValidUrl(eventUrl)
    }

    private var eventFields: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Event Details")
                .font(Typography.subheadlineSemibold)
                .foregroundStyle(ColorSystem.Content.primary)

            VStack(spacing: Spacing.sm) {
                // Date & Time
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(ColorSystem.Brand.primary)
                        .frame(width: 24)

                    DatePicker(
                        "Event Date",
                        selection: $eventDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }
                .padding()
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                // Location (Required)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Image(systemName: "location")
                            .foregroundStyle(isEventLocationValid ? ColorSystem.Brand.primary : ColorSystem.Status.warning)
                            .frame(width: 24)

                        TextField("Event location (required)", text: $eventLocation)

                        if isEventLocationValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ColorSystem.Status.success)
                        }
                    }
                    .padding()
                    .background(ColorSystem.Surface.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .strokeBorder(!isEventLocationValid && !eventLocation.isEmpty ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                    )
                }

                // RSVP URL
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(isEventUrlValid ? ColorSystem.Brand.primary : ColorSystem.Status.error)
                            .frame(width: 24)

                        TextField("RSVP link (optional)", text: $eventUrl)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding()
                    .background(ColorSystem.Surface.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .strokeBorder(!isEventUrlValid ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                    )

                    if !isEventUrlValid {
                        Text("Please enter a valid URL (e.g., https://example.com)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Status.error)
                    }
                }
            }
        }
    }

    // MARK: - Poll Fields

    private var pollFields: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Poll Options")
                    .font(Typography.subheadlineSemibold)
                    .foregroundStyle(ColorSystem.Content.primary)

                Spacer()

                Text("\(validPollOptionsCount)/2 required")
                    .font(Typography.caption)
                    .foregroundStyle(validPollOptionsCount >= 2 ? ColorSystem.Status.success : ColorSystem.Status.warning)
            }

            VStack(spacing: Spacing.sm) {
                ForEach(pollOptions.indices, id: \.self) { index in
                    HStack {
                        Circle()
                            .strokeBorder(pollOptions[index].trimmingCharacters(in: .whitespaces).isEmpty ? ColorSystem.Border.subtle : ColorSystem.Status.success, lineWidth: 2)
                            .frame(width: 20, height: 20)

                        TextField("Option \(index + 1)", text: $pollOptions[index])

                        if pollOptions.count > 2 {
                            Button {
                                pollOptions.remove(at: index)
                                HapticManager.shared.light()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ColorSystem.Content.tertiary)
                            }
                        }
                    }
                    .padding()
                    .background(ColorSystem.Surface.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }

                if pollOptions.count < 4 {
                    Button {
                        pollOptions.append("")
                        HapticManager.shared.light()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Option")
                        }
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Brand.primary)
                    }
                    .padding(.top, Spacing.xs)
                }

                // Duration picker
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(ColorSystem.Brand.primary)
                        .frame(width: 24)

                    Text("Poll Duration")
                        .foregroundStyle(ColorSystem.Content.primary)

                    Spacer()

                    Picker("Duration", selection: $pollDuration) {
                        ForEach(PollDuration.allCases, id: \.self) { duration in
                            Text(duration.rawValue).tag(duration)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
    }

    // MARK: - Media Picker

    private var mediaPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Media")
                .font(Typography.subheadlineSemibold)
                .foregroundStyle(ColorSystem.Content.primary)

            if !loadedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(loadedImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: loadedImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                                Button {
                                    loadedImages.remove(at: index)
                                    if index < selectedImages.count {
                                        selectedImages.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                }
                                .padding(4)
                            }
                        }

                        if loadedImages.count < 4 {
                            addMediaButton
                        }
                    }
                }
            } else {
                addMediaButton
            }
        }
    }

    private var addMediaButton: some View {
        PhotosPicker(
            selection: $selectedImages,
            maxSelectionCount: 4 - loadedImages.count,
            matching: .images
        ) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24))
                Text("Add Photos")
                    .font(Typography.subheadlineMedium)
            }
            .foregroundStyle(ColorSystem.Brand.primary)
            .frame(width: 100, height: 100)
            .background(ColorSystem.Brand.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
        .onChange(of: selectedImages) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        loadedImages.append(image)
                    }
                }
            }
        }
    }

    // MARK: - Link Input

    private var isLinkUrlValid: Bool {
        linkUrl.isEmpty || isValidUrl(linkUrl)
    }

    private var linkInput: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Add Link")
                .font(Typography.subheadlineSemibold)
                .foregroundStyle(ColorSystem.Content.primary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(isLinkUrlValid ? ColorSystem.Brand.primary : ColorSystem.Status.error)
                        .frame(width: 24)

                    TextField("https://", text: $linkUrl)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding()
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .strokeBorder(!isLinkUrlValid ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                )

                if !isLinkUrlValid {
                    Text("Please enter a valid URL (e.g., https://example.com)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Status.error)
                }
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $isScheduled) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(ColorSystem.Brand.primary)
                    Text("Schedule for later")
                        .font(Typography.subheadlineMedium)
                }
            }
            .tint(ColorSystem.Brand.primary)

            if isScheduled {
                DatePicker(
                    "Schedule Date",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
        .padding()
        .background(ColorSystem.Surface.elevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - Actions

    private func createPost() async {
        HapticManager.shared.buttonTap()

        guard let officialId = profileService.profile?.id else {
            errorMessage = "Profile not loaded"
            showingError = true
            HapticManager.shared.error()
            return
        }

        isPosting = true

        // Upload images first
        var mediaUrls: [String] = []
        for image in loadedImages {
            if let data = image.jpegData(compressionQuality: 0.8),
               let url = await postService.uploadMedia(imageData: data, officialId: officialId) {
                mediaUrls.append(url)
            }
        }

        // Prepare poll options (trimmed and filtered)
        let validPollOptions = selectedPostType == .poll
            ? pollOptions.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            : nil

        let pollEndsAt = selectedPostType == .poll
            ? Date().addingTimeInterval(pollDuration.interval)
            : nil

        // Create post
        let post = await postService.createPost(
            officialId: officialId,
            content: content,
            postType: selectedPostType,
            mediaUrls: mediaUrls,
            linkUrl: linkUrl.isEmpty ? nil : linkUrl,
            eventDate: selectedPostType == .event ? eventDate : nil,
            eventLocation: selectedPostType == .event && !eventLocation.isEmpty ? eventLocation : nil,
            pollOptions: validPollOptions,
            pollEndsAt: pollEndsAt,
            scheduledFor: isScheduled ? scheduledDate : nil
        )

        isPosting = false

        if post != nil {
            HapticManager.shared.success()
            dismiss()
        } else {
            errorMessage = postService.error ?? "Failed to create post"
            showingError = true
            HapticManager.shared.error()
        }
    }
}

// MARK: - Post Type Chip

private struct PostTypeChip: View {
    let type: Connect_Post.PostType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                Text(type.displayName)
            }
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

// MARK: - Preview

#if DEBUG
#Preview {
    Connect_ComposeSheet()
}
#endif
