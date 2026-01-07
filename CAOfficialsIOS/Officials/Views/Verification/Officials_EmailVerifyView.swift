//
//  Officials_EmailVerifyView.swift
//  CA Officials
//
//  Email verification code entry view
//

import SwiftUI

/// View for entering email verification code
struct Officials_EmailVerifyView: View {
    @Binding var verificationCode: String
    let selectedOffice: Officials_GovernmentOffice?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var codeSent = false
    @State private var resendCountdown = 0
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            VStack(spacing: Spacing.md) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorSystem.Brand.primary)

                Text("Verify Your Email")
                    .font(Typography.title2)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text("We'll send a verification code to your government email")
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorSystem.Content.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.lg)

            // Email display
            if let office = selectedOffice {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(ColorSystem.Brand.primary)

                    Text("senator@\(office.jurisdiction.lowercased().replacingOccurrences(of: " ", with: "")).gov")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(ColorSystem.Content.primary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity)
                .background(ColorSystem.Surface.elevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .padding(.horizontal, Spacing.lg)
            }

            if !codeSent {
                // Send code button
                Button {
                    sendCode()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send Verification Code")
                            .font(Typography.buttonPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(isLoading)
                .padding(.horizontal, Spacing.lg)
            } else {
                // Code entry
                VStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Enter 6-digit code")
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Content.secondary)

                        TextField("000000", text: $verificationCode)
                            .textFieldStyle(OfficialTextFieldStyle())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(Typography.title2)
                    }
                    .padding(.horizontal, Spacing.lg)

                    if let error = errorMessage {
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Status.error)
                            .padding(.horizontal, Spacing.lg)
                    }

                    // Resend
                    if resendCountdown > 0 {
                        Text("Resend code in \(resendCountdown)s")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.tertiary)
                    } else {
                        Button {
                            sendCode()
                        } label: {
                            Text("Resend Code")
                                .font(Typography.subheadlineMedium)
                                .foregroundStyle(ColorSystem.Brand.primary)
                        }
                    }
                }

                Spacer()

                // Verify button
                Button {
                    verifyCode()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Verify")
                            .font(Typography.buttonPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(verificationCode.count != 6 || isLoading)
                .padding(.horizontal, Spacing.lg)
            }

            if !codeSent {
                Spacer()
            }

            // Back button
            Button {
                HapticManager.shared.light()
                resetState()
                onBack()
            } label: {
                Text("Back")
                    .font(Typography.subheadlineMedium)
                    .foregroundStyle(ColorSystem.Brand.primary)
            }
            .padding(.bottom, Spacing.lg)
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    private func resetState() {
        countdownTask?.cancel()
        countdownTask = nil
        verificationCode = ""
        codeSent = false
        errorMessage = nil
        resendCountdown = 0
        isLoading = false
    }

    private func sendCode() {
        HapticManager.shared.buttonTap()
        isLoading = true
        errorMessage = nil

        // Simulate sending code
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                isLoading = false
                codeSent = true
                startResendCountdown()
                HapticManager.shared.success()
            }
        }
    }

    private func verifyCode() {
        HapticManager.shared.buttonTap()
        isLoading = true
        errorMessage = nil

        // Simulate verification
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            await MainActor.run {
                isLoading = false

                // For demo, accept any 6-digit code
                if verificationCode.count == 6 {
                    HapticManager.shared.success()
                    onComplete()
                } else {
                    errorMessage = "Invalid code. Please try again."
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func startResendCountdown() {
        resendCountdown = 60
        countdownTask?.cancel()
        countdownTask = Task {
            while !Task.isCancelled && resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        if resendCountdown > 0 {
                            resendCountdown -= 1
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_EmailVerifyView_Previews: PreviewProvider {
    static var previews: some View {
        Officials_EmailVerifyView(
            verificationCode: .constant(""),
            selectedOffice: .preview,
            onComplete: {},
            onBack: {}
        )
    }
}
#endif
