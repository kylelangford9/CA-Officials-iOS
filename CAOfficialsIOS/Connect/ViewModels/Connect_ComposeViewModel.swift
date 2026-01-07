//
//  Connect_ComposeViewModel.swift
//  CA Officials
//
//  ViewModel for composing new posts
//

import Foundation
import SwiftUI
import PhotosUI
import Combine

@MainActor
final class Connect_ComposeViewModel: ObservableObject {

    // MARK: - Published Properties

    // Content
    @Published var content = ""
    @Published var selectedPostType: Connect_Post.PostType = .update

    // Media
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var loadedImages: [UIImage] = []
    @Published var isLoadingMedia = false

    // Link
    @Published var linkUrl = ""
    @Published var linkPreview: Connect_Post.LinkPreview?
    @Published var isLoadingLinkPreview = false

    // Event
    @Published var eventDate = Date().addingTimeInterval(86400) // Tomorrow
    @Published var eventEndDate: Date?
    @Published var eventLocation = ""
    @Published var eventUrl = ""
    @Published var hasEndDate = false

    // Poll
    @Published var pollOptions: [String] = ["", ""]
    @Published var pollDuration: PollDuration = .oneDay

    // Scheduling
    @Published var isScheduled = false
    @Published var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now

    // State
    @Published var isPosting = false
    @Published var postError: String?
    @Published var showingError = false
    @Published var postSuccess = false

    // MARK: - Types

    enum PollDuration: String, CaseIterable, Identifiable {
        case oneHour = "1 hour"
        case sixHours = "6 hours"
        case twelveHours = "12 hours"
        case oneDay = "1 day"
        case threeDays = "3 days"
        case oneWeek = "1 week"

        var id: String { rawValue }

        var interval: TimeInterval {
            switch self {
            case .oneHour: return 3600
            case .sixHours: return 3600 * 6
            case .twelveHours: return 3600 * 12
            case .oneDay: return 86400
            case .threeDays: return 86400 * 3
            case .oneWeek: return 86400 * 7
            }
        }
    }

    // MARK: - Services

    private let postService = Connect_PostService.shared
    private let profileService = Officials_ProfileService.shared

    private var cancellables = Set<AnyCancellable>()
    private var linkPreviewTask: Task<Void, Never>?

    // MARK: - Constants

    let maxContentLength = 2000
    let maxImages = 4
    let maxPollOptions = 4
    let minPollOptions = 2

    // MARK: - Computed Properties

    var profile: Officials_Official? {
        profileService.profile
    }

    var characterCount: Int {
        content.count
    }

    var remainingCharacters: Int {
        maxContentLength - characterCount
    }

    var isContentValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= maxContentLength
    }

    var isEventValid: Bool {
        guard selectedPostType == .event else { return true }
        return eventDate > Date() && !eventLocation.isEmpty
    }

    var isPollValid: Bool {
        guard selectedPostType == .poll else { return true }
        let validOptions = pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return validOptions.count >= minPollOptions
    }

    var isScheduleValid: Bool {
        guard isScheduled else { return true }
        return scheduledDate > Date()
    }

    var canPost: Bool {
        isContentValid && isEventValid && isPollValid && isScheduleValid && !isPosting
    }

    var validPollOptions: [String] {
        pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Load photos when selected
        $selectedPhotos
            .dropFirst()
            .sink { [weak self] items in
                Task { await self?.loadPhotos(items) }
            }
            .store(in: &cancellables)

        // Fetch link preview when URL changes
        $linkUrl
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] url in
                Task { await self?.fetchLinkPreview(for: url) }
            }
            .store(in: &cancellables)

        // Update end date when start date changes
        $eventDate
            .sink { [weak self] date in
                if let self = self, self.hasEndDate, let endDate = self.eventEndDate {
                    if endDate <= date {
                        self.eventEndDate = date.addingTimeInterval(3600) // 1 hour after start
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Photo Handling

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingMedia = true

        for item in items {
            guard loadedImages.count < maxImages else { break }

            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            } catch {
                #if DEBUG
                print("[ComposeVM] Error loading photo: \(error)")
                #endif
            }
        }

        isLoadingMedia = false
    }

    func removeImage(at index: Int) {
        guard index < loadedImages.count else { return }
        loadedImages.remove(at: index)

        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }

        HapticManager.shared.light()
    }

    func canAddMoreImages() -> Bool {
        loadedImages.count < maxImages
    }

    // MARK: - Link Preview

    private func fetchLinkPreview(for urlString: String) async {
        linkPreviewTask?.cancel()

        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              url.scheme != nil else {
            linkPreview = nil
            return
        }

        linkPreviewTask = Task {
            isLoadingLinkPreview = true

            // In production, this would fetch Open Graph data from the URL
            // For now, create a simple preview
            try? await Task.sleep(for: .milliseconds(500))

            guard !Task.isCancelled else { return }

            linkPreview = Connect_Post.LinkPreview(
                title: url.host,
                description: nil,
                imageUrl: nil,
                siteName: url.host
            )

            isLoadingLinkPreview = false
        }
    }

    func clearLinkPreview() {
        linkUrl = ""
        linkPreview = nil
    }

    // MARK: - Poll Options

    func addPollOption() {
        guard pollOptions.count < maxPollOptions else { return }
        pollOptions.append("")
        HapticManager.shared.light()
    }

    func removePollOption(at index: Int) {
        guard pollOptions.count > minPollOptions, index < pollOptions.count else { return }
        pollOptions.remove(at: index)
        HapticManager.shared.light()
    }

    // MARK: - Post Creation

    func createPost() async {
        guard canPost, let officialId = profile?.id else {
            postError = "Unable to create post. Please try again."
            showingError = true
            return
        }

        isPosting = true
        postError = nil

        // Upload images
        var mediaUrls: [String] = []
        for image in loadedImages {
            if let data = image.jpegData(compressionQuality: 0.8),
               let url = await postService.uploadMedia(imageData: data, officialId: officialId) {
                mediaUrls.append(url)
            }
        }

        // Prepare poll data
        let pollEndsAt = selectedPostType == .poll
            ? Date().addingTimeInterval(pollDuration.interval)
            : nil

        // Create post
        let post = await postService.createPost(
            officialId: officialId,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            postType: selectedPostType,
            mediaUrls: mediaUrls,
            linkUrl: linkUrl.isEmpty ? nil : linkUrl,
            eventDate: selectedPostType == .event ? eventDate : nil,
            eventLocation: selectedPostType == .event && !eventLocation.isEmpty ? eventLocation : nil,
            pollOptions: selectedPostType == .poll ? validPollOptions : nil,
            pollEndsAt: pollEndsAt,
            scheduledFor: isScheduled ? scheduledDate : nil
        )

        isPosting = false

        if post != nil {
            postSuccess = true
            HapticManager.shared.success()
            reset()
        } else {
            postError = postService.error ?? "Failed to create post"
            showingError = true
            HapticManager.shared.error()
        }
    }

    // MARK: - Draft Management

    func saveDraft() {
        // Save draft to UserDefaults or local storage
        #if DEBUG
        print("[ComposeVM] Saving draft...")
        #endif
    }

    func loadDraft() {
        // Load draft from storage
        #if DEBUG
        print("[ComposeVM] Loading draft...")
        #endif
    }

    func clearDraft() {
        // Clear saved draft
        #if DEBUG
        print("[ComposeVM] Clearing draft...")
        #endif
    }

    // MARK: - Reset

    func reset() {
        content = ""
        selectedPostType = .update
        selectedPhotos = []
        loadedImages = []
        linkUrl = ""
        linkPreview = nil
        eventDate = Date().addingTimeInterval(86400)
        eventEndDate = nil
        eventLocation = ""
        eventUrl = ""
        hasEndDate = false
        pollOptions = ["", ""]
        pollDuration = .oneDay
        isScheduled = false
        scheduledDate = Date().addingTimeInterval(3600)
        postError = nil
    }

    // MARK: - Validation Messages

    var contentValidationMessage: String? {
        if content.isEmpty {
            return nil
        }
        if characterCount > maxContentLength {
            return "Content exceeds maximum length"
        }
        return nil
    }

    var eventValidationMessage: String? {
        guard selectedPostType == .event else { return nil }

        if eventLocation.isEmpty {
            return "Please enter an event location"
        }
        if eventDate <= Date() {
            return "Event date must be in the future"
        }
        return nil
    }

    var pollValidationMessage: String? {
        guard selectedPostType == .poll else { return nil }

        let validOptions = validPollOptions
        if validOptions.count < minPollOptions {
            return "Please add at least \(minPollOptions) poll options"
        }
        return nil
    }

    var scheduleValidationMessage: String? {
        guard isScheduled else { return nil }

        if scheduledDate <= Date() {
            return "Scheduled time must be in the future"
        }
        return nil
    }
}
