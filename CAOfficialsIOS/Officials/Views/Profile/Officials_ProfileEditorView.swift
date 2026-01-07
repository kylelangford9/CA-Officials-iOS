//
//  Officials_ProfileEditorView.swift
//  CA Officials
//
//  Profile editor view for officials
//

import SwiftUI
import PhotosUI

/// View for editing official profile
struct Officials_ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = Officials_ProfileEditorViewModel()

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""

    @State private var isLoadingProfile = false

    var body: some View {
        Group {
            if isLoadingProfile && viewModel.name.isEmpty {
                loadingView
            } else {
                formContent
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    HapticManager.shared.light()
                    dismiss()
                }
                .disabled(viewModel.isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveProfile()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!viewModel.hasChanges || viewModel.isSaving || !isFormValid)
            }
        }
        .task {
            isLoadingProfile = true
            await viewModel.loadProfile()
            isLoadingProfile = false
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.photoImage = image
                        HapticManager.shared.light()
                    }
                }
            }
        }
        .alert("Validation Error", isPresented: $showingValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationErrorMessage)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.saveError ?? "An error occurred")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading profile...")
                .font(Typography.body)
                .foregroundStyle(ColorSystem.Content.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            // Photo section
            photoSection

            // Basic info
            basicInfoSection

            // Bio
            bioSection

            // Contact
            contactSection

            // Social links
            socialSection

            // Preview
            previewSection
        }
        .disabled(viewModel.isSaving)
        .opacity(viewModel.isSaving ? 0.6 : 1.0)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: Spacing.sm) {
                        if let image = viewModel.photoImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let existingPhotoUrl = viewModel.photoUrl,
                                  let url = URL(string: existingPhotoUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure, .empty:
                                    photoPlaceholder
                                @unknown default:
                                    photoPlaceholder
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            photoPlaceholder
                        }

                        Text("Change Photo")
                            .font(Typography.subheadlineMedium)
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }
                .disabled(viewModel.isSaving)
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private var photoPlaceholder: some View {
        Circle()
            .fill(ColorSystem.Brand.primary.opacity(0.2))
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(viewModel.name.prefix(1)))
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(ColorSystem.Brand.primary)
            )
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Full Name", text: $viewModel.name)

            TextField("Title", text: $viewModel.title)

            Picker("Party", selection: $viewModel.party) {
                Text("Democratic").tag("Democratic")
                Text("Republican").tag("Republican")
                Text("Independent").tag("Independent")
                Text("Libertarian").tag("Libertarian")
                Text("Green").tag("Green")
                Text("No Party Preference").tag("No Party Preference")
            }
        }
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        Section {
            TextEditor(text: $viewModel.bio)
                .frame(minHeight: 100)

            HStack {
                Text("\(viewModel.bio.count)/500 characters")
                    .font(Typography.caption)
                    .foregroundStyle(bioCharacterColor)

                Spacer()

                if viewModel.bio.count > 500 {
                    Text("Too long")
                        .font(Typography.captionSemibold)
                        .foregroundStyle(ColorSystem.Status.error)
                }
            }
        } header: {
            Text("Biography")
        } footer: {
            Text("Tell constituents about yourself and your priorities.")
        }
    }

    private var bioCharacterColor: Color {
        if viewModel.bio.count > 500 {
            return ColorSystem.Status.error
        } else if viewModel.bio.count > 450 {
            return ColorSystem.Status.warning
        }
        return ColorSystem.Content.tertiary
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        Section {
            HStack {
                Image(systemName: "phone.fill")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("Office Phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
            }

            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(isValidEmail ? ColorSystem.Brand.primary : ColorSystem.Status.error)
                    .frame(width: 24)
                TextField("Office Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !viewModel.email.isEmpty && !isValidEmail {
                Text("Please enter a valid email address")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Status.error)
            }

            HStack {
                Image(systemName: "building.fill")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("Office Address", text: $viewModel.officeAddress)
            }

            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("Mailing Address", text: $viewModel.mailingAddress)
            }
        } header: {
            Text("Contact Information")
        } footer: {
            Text("This information will be visible to voters.")
        }
    }

    // MARK: - Social Section

    private var socialSection: some View {
        Section {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(isValidWebsite ? ColorSystem.Brand.primary : ColorSystem.Status.error)
                    .frame(width: 24)
                TextField("Website URL", text: $viewModel.website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !viewModel.website.isEmpty && !isValidWebsite {
                Text("Please enter a valid URL (e.g., https://example.com)")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Status.error)
            }

            HStack {
                Image(systemName: "at")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("Twitter/X Handle", text: $viewModel.twitter)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            HStack {
                Image(systemName: "person.crop.square")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("Facebook URL", text: $viewModel.facebook)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            HStack {
                Image(systemName: "camera")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("Instagram Handle", text: $viewModel.instagram)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            HStack {
                Image(systemName: "link")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("LinkedIn URL", text: $viewModel.linkedin)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            HStack {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(width: 24)
                TextField("YouTube URL", text: $viewModel.youtube)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Social Media")
        } footer: {
            Text("Add your official social media accounts.")
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            NavigationLink {
                profilePreview
            } label: {
                Label("Preview Profile", systemImage: "eye")
            }
        }
    }

    private var profilePreview: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Profile header preview
                VStack(spacing: Spacing.md) {
                    if let image = viewModel.photoImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(ColorSystem.Brand.primary.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text(String(viewModel.name.prefix(1)))
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundStyle(ColorSystem.Brand.primary)
                            )
                    }

                    Text(viewModel.name)
                        .font(Typography.title2)
                        .foregroundStyle(ColorSystem.Content.primary)

                    Text(viewModel.title)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)

                    if !viewModel.bio.isEmpty {
                        Text(viewModel.bio)
                            .font(Typography.body)
                            .foregroundStyle(ColorSystem.Content.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Preview")
    }

    // MARK: - Validation

    private var isValidEmail: Bool {
        if viewModel.email.isEmpty { return true }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return viewModel.email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private var isValidWebsite: Bool {
        if viewModel.website.isEmpty { return true }
        guard let url = URL(string: viewModel.website) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private var isFormValid: Bool {
        // Name is required
        guard !viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        // Bio must be under 500 characters
        guard viewModel.bio.count <= 500 else { return false }

        // Email must be valid if provided
        guard isValidEmail else { return false }

        // Website must be valid if provided
        guard isValidWebsite else { return false }

        return true
    }

    // MARK: - Save

    private func saveProfile() {
        // Validate before saving
        guard isFormValid else {
            if viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrorMessage = "Name is required"
            } else if viewModel.bio.count > 500 {
                validationErrorMessage = "Biography must be 500 characters or less"
            } else if !isValidEmail {
                validationErrorMessage = "Please enter a valid email address"
            } else if !isValidWebsite {
                validationErrorMessage = "Please enter a valid website URL"
            }
            showingValidationError = true
            HapticManager.shared.error()
            return
        }

        HapticManager.shared.buttonTap()

        Task {
            await viewModel.saveProfile()
            // Check if save was successful by checking showingSaveSuccess
            if viewModel.showingSaveSuccess {
                dismiss()
            }
            // Error haptics are handled in the ViewModel
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_ProfileEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Officials_ProfileEditorView()
        }
    }
}
#endif
