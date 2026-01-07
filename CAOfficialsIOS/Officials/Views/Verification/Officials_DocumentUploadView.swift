//
//  Officials_DocumentUploadView.swift
//  CA Officials
//
//  Document upload verification view
//

import SwiftUI
import PhotosUI

/// View for uploading verification documents
struct Officials_DocumentUploadView: View {
    let selectedOffice: Officials_GovernmentOffice?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var uploadedDocuments: [UploadedDocument] = []
    @State private var isUploading = false
    @State private var errorMessage: String?

    struct UploadedDocument: Identifiable {
        let id = UUID()
        var name: String
        var type: DocumentType
        var image: UIImage?
    }

    enum DocumentType: String, CaseIterable {
        case oath = "Oath of Office"
        case certificate = "Certificate of Election"
        case governmentID = "Government ID"
        case letterhead = "Official Letterhead"

        var icon: String {
            switch self {
            case .oath: return "doc.text.fill"
            case .certificate: return "rosette"
            case .governmentID: return "person.crop.rectangle"
            case .letterhead: return "envelope.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.md) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(ColorSystem.Brand.primary)

                    Text("Upload Documents")
                        .font(Typography.title2)
                        .foregroundStyle(ColorSystem.Content.primary)

                    Text("Upload official documents to verify your identity. Documents will be reviewed within 1-3 business days.")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.lg)

                // Document types
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Accepted Documents")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.primary)

                    ForEach(DocumentType.allCases, id: \.rawValue) { type in
                        HStack(spacing: Spacing.md) {
                            Image(systemName: type.icon)
                                .foregroundStyle(ColorSystem.Brand.primary)
                                .frame(width: 24)

                            Text(type.rawValue)
                                .font(Typography.subheadline)
                                .foregroundStyle(ColorSystem.Content.secondary)
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .padding(.horizontal, Spacing.lg)

                // Uploaded documents
                if !uploadedDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Uploaded (\(uploadedDocuments.count))")
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(ColorSystem.Content.primary)

                        ForEach(uploadedDocuments) { doc in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(ColorSystem.Brand.primary)

                                Text(doc.name)
                                    .font(Typography.subheadline)
                                    .foregroundStyle(ColorSystem.Content.primary)

                                Spacer()

                                Button {
                                    removeDocument(doc)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(ColorSystem.Content.tertiary)
                                }
                            }
                            .padding(Spacing.md)
                            .background(ColorSystem.Surface.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }

                // Upload button
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Document")
                    }
                    .font(Typography.buttonPrimary)
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                    .background(ColorSystem.Brand.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(ColorSystem.Brand.primary, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .onChange(of: selectedItems) { _, newItems in
                    handleSelectedItems(newItems)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Status.error)
                        .padding(.horizontal, Spacing.lg)
                }

                Spacer()
                    .frame(height: Spacing.xxl)

                // Submit button
                Button {
                    submitDocuments()
                } label: {
                    if isUploading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Submit for Review")
                            .font(Typography.buttonPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(uploadedDocuments.isEmpty || isUploading)
                .padding(.horizontal, Spacing.lg)

                // Back button
                Button {
                    onBack()
                } label: {
                    Text("Back")
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }
                .padding(.bottom, Spacing.lg)
            }
        }
    }

    private func handleSelectedItems(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        let doc = UploadedDocument(
                            name: "Document_\(uploadedDocuments.count + 1).jpg",
                            type: .governmentID,
                            image: image
                        )
                        uploadedDocuments.append(doc)
                    }
                }
            }
            await MainActor.run {
                selectedItems = []
            }
        }
    }

    private func removeDocument(_ doc: UploadedDocument) {
        HapticManager.shared.light()
        uploadedDocuments.removeAll { $0.id == doc.id }
    }

    private func submitDocuments() {
        HapticManager.shared.buttonTap()
        isUploading = true
        errorMessage = nil

        // Simulate upload
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                isUploading = false
                HapticManager.shared.success()
                onComplete()
            }
        }
    }
}

// MARK: - Website Verify View

struct Officials_WebsiteVerifyView: View {
    let selectedOffice: Officials_GovernmentOffice?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var verificationToken = UUID().uuidString.prefix(8).uppercased()
    @State private var isVerifying = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            VStack(spacing: Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorSystem.Brand.primary)

                Text("Website Verification")
                    .font(Typography.title2)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text("Add a verification token to your official website")
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorSystem.Content.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.lg)

            // Instructions
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Instructions")
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(ColorSystem.Content.primary)

                InstructionRow(number: 1, text: "Add the following meta tag to your official website's homepage")
                InstructionRow(number: 2, text: "The tag should be in the <head> section")
                InstructionRow(number: 3, text: "Click 'Verify' once added")
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)

            // Token display
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Verification Token")
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Content.secondary)

                HStack {
                    Text("<meta name=\"ca-officials-verify\" content=\"\(verificationToken)\">")
                        .font(Typography.monoCaption)
                        .foregroundStyle(ColorSystem.Content.primary)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = "<meta name=\"ca-officials-verify\" content=\"\(verificationToken)\">"
                        HapticManager.shared.success()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                }
                .padding(Spacing.md)
                .background(ColorSystem.Surface.elevatedPlus)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
            .padding(.horizontal, Spacing.lg)

            if let error = errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(ColorSystem.Status.error)
                    .padding(.horizontal, Spacing.lg)
            }

            Spacer()

            // Verify button
            Button {
                verifyWebsite()
            } label: {
                if isVerifying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Verify Website")
                        .font(Typography.buttonPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(isVerifying)
            .padding(.horizontal, Spacing.lg)

            // Back button
            Button {
                onBack()
            } label: {
                Text("Back")
                    .font(Typography.subheadlineMedium)
                    .foregroundStyle(ColorSystem.Brand.primary)
            }
            .padding(.bottom, Spacing.lg)
        }
    }

    private func verifyWebsite() {
        HapticManager.shared.buttonTap()
        isVerifying = true
        errorMessage = nil

        // Simulate verification
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                isVerifying = false
                // For demo, succeed
                HapticManager.shared.success()
                onComplete()
            }
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("\(number)")
                .font(Typography.captionSemibold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(ColorSystem.Brand.primary)
                .clipShape(Circle())

            Text(text)
                .font(Typography.subheadline)
                .foregroundStyle(ColorSystem.Content.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_DocumentUploadView_Previews: PreviewProvider {
    static var previews: some View {
        Officials_DocumentUploadView(
            selectedOffice: .preview,
            onComplete: {},
            onBack: {}
        )
    }
}
#endif
