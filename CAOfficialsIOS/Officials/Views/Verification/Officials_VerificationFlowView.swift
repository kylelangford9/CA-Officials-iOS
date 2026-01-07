//
//  Officials_VerificationFlowView.swift
//  CA Officials
//
//  Main verification flow container
//

import SwiftUI

/// Container view for the multi-step verification flow
struct Officials_VerificationFlowView: View {
    @EnvironmentObject private var roleManager: RoleManager

    @State private var currentStep: VerificationStep = .claimOffice
    @State private var verificationState: Officials_VerificationState = .idle
    @State private var selectedOffice: Officials_GovernmentOffice?
    @State private var selectedMethod: Officials_VerificationMethod?
    @State private var verificationCode = ""

    enum VerificationStep: Int, CaseIterable {
        case claimOffice = 1
        case selectMethod = 2
        case verify = 3

        var title: String {
            switch self {
            case .claimOffice: return "Claim Office"
            case .selectMethod: return "Verify"
            case .verify: return "Complete"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            VerificationProgressBar(currentStep: currentStep)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            // Content based on step
            TabView(selection: $currentStep) {
                Officials_ClaimOfficeView(
                    selectedOffice: $selectedOffice,
                    onNext: { goToStep(.selectMethod) }
                )
                .tag(VerificationStep.claimOffice)

                Officials_VerifyMethodView(
                    selectedMethod: $selectedMethod,
                    selectedOffice: selectedOffice,
                    onNext: { goToStep(.verify) },
                    onBack: { goToStep(.claimOffice) }
                )
                .tag(VerificationStep.selectMethod)

                verifyStepView
                    .tag(VerificationStep.verify)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
        }
        .background(ColorSystem.Surface.base)
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var verifyStepView: some View {
        switch selectedMethod {
        case .governmentEmail:
            Officials_EmailVerifyView(
                verificationCode: $verificationCode,
                selectedOffice: selectedOffice,
                onComplete: completeVerification,
                onBack: { goToStep(.selectMethod) }
            )
        case .documentUpload:
            Officials_DocumentUploadView(
                selectedOffice: selectedOffice,
                onComplete: completeVerification,
                onBack: { goToStep(.selectMethod) }
            )
        case .websiteToken:
            Officials_WebsiteVerifyView(
                selectedOffice: selectedOffice,
                onComplete: completeVerification,
                onBack: { goToStep(.selectMethod) }
            )
        case .none:
            Text("Please select a verification method")
                .foregroundStyle(ColorSystem.Content.secondary)
        }
    }

    private func goToStep(_ step: VerificationStep) {
        HapticManager.shared.selectionChanged()

        // Reset state when going back
        if step.rawValue < currentStep.rawValue {
            switch currentStep {
            case .verify:
                // Reset verification code when going back from verify
                verificationCode = ""
            case .selectMethod:
                // Reset method when going back from select method
                selectedMethod = nil
            default:
                break
            }
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    private func completeVerification() {
        HapticManager.shared.success()

        // Update role manager based on method
        if selectedMethod == .governmentEmail {
            // Instant verification
            roleManager.setOfficialProfile(id: UUID(), status: .verified)
        } else {
            // Needs review
            roleManager.setOfficialProfile(id: UUID(), status: .pending)
        }
    }
}

// MARK: - Progress Bar

struct VerificationProgressBar: View {
    let currentStep: Officials_VerificationFlowView.VerificationStep

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Officials_VerificationFlowView.VerificationStep.allCases, id: \.rawValue) { step in
                ProgressStepIndicator(
                    step: step.rawValue,
                    title: step.title,
                    isCompleted: step.rawValue < currentStep.rawValue,
                    isCurrent: step == currentStep
                )

                if step != .verify {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ?
                              ColorSystem.Brand.primary :
                              ColorSystem.Border.subtle)
                        .frame(height: 2)
                }
            }
        }
    }
}

struct ProgressStepIndicator: View {
    let step: Int
    let title: String
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step)")
                        .font(Typography.captionSemibold)
                        .foregroundStyle(isCurrent ? .white : ColorSystem.Content.tertiary)
                }
            }

            Text(title)
                .font(Typography.caption)
                .foregroundStyle(isCurrent ? ColorSystem.Content.primary : ColorSystem.Content.tertiary)
        }
    }

    private var circleColor: Color {
        if isCompleted || isCurrent {
            return ColorSystem.Brand.primary
        }
        return ColorSystem.Surface.elevated
    }
}

// MARK: - Claim Office View

struct Officials_ClaimOfficeView: View {
    @Binding var selectedOffice: Officials_GovernmentOffice?
    let onNext: () -> Void

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [Officials_GovernmentOffice] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            VStack(spacing: Spacing.md) {
                Image(systemName: "building.columns")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorSystem.Brand.primary)

                Text("Find Your Office")
                    .font(Typography.title2)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text("Search for the government office you hold")
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorSystem.Content.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ColorSystem.Content.tertiary)

                TextField("Search by office title or location", text: $searchText)
                    .textFieldStyle(.plain)

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(Spacing.md)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(ColorSystem.Border.subtle, lineWidth: BorderWidth.thin)
            )
            .padding(.horizontal, Spacing.lg)
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }

            // Results
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorSystem.Content.tertiary)

                    Text("No offices found")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.secondary)

                    Text("Try a different search term")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.tertiary)
                }
                .padding(.top, Spacing.xxl)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(searchResults) { office in
                            OfficeSearchResultRow(
                                office: office,
                                isSelected: selectedOffice?.id == office.id
                            ) {
                                HapticManager.shared.selectionChanged()
                                selectedOffice = office
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }

            Spacer()

            // Next button
            Button {
                HapticManager.shared.buttonTap()
                onNext()
            } label: {
                Text("Continue")
                    .font(Typography.buttonPrimary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(selectedOffice == nil)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func performSearch(query: String) {
        // Cancel any existing search
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Debounced search with cancellation support
        searchTask = Task {
            // Debounce delay
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            // In production this would query Supabase
            await MainActor.run {
                guard !Task.isCancelled else { return }

                #if DEBUG
                // Use preview data for demo
                searchResults = Officials_GovernmentOffice.previewArray.filter {
                    $0.matches(searchQuery: query)
                }
                #else
                searchResults = []
                #endif
                isSearching = false
            }
        }
    }
}

struct OfficeSearchResultRow: View {
    let office: Officials_GovernmentOffice
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(office.displayName)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.primary)

                    Text(office.locationString)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)

                    HStack(spacing: Spacing.sm) {
                        Text(office.levelDisplayName)
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Brand.primary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(ColorSystem.Brand.primary.opacity(0.1))
                            .clipShape(Capsule())

                        if office.isClaimed {
                            Text("Claimed")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Status.warning)
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorSystem.Brand.primary)
                        .font(.system(size: 24))
                }
            }
            .padding(Spacing.md)
            .background(isSelected ? ColorSystem.Brand.primary.opacity(0.1) : ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(isSelected ? ColorSystem.Brand.primary : ColorSystem.Border.subtle, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_VerificationFlowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Officials_VerificationFlowView()
                .environmentObject(RoleManager())
        }
    }
}
#endif
