//
//  Officials_RootView.swift
//  CA Officials
//
//  Root view that handles navigation based on verification status
//

import SwiftUI

/// Root view for the Officials module
/// Routes to appropriate view based on authentication and verification status
struct Officials_RootView: View {
    @EnvironmentObject private var roleManager: RoleManager

    @State private var showingWelcome = true

    var body: some View {
        NavigationStack {
            Group {
                if !roleManager.isAuthenticated {
                    // Not logged in - show welcome/onboarding
                    Officials_WelcomeView()
                } else if roleManager.verificationStatus == .unverified {
                    // Logged in but not verified - show verification flow
                    Officials_VerificationFlowView()
                } else if roleManager.verificationStatus == .pending {
                    // Verification pending review
                    Officials_PendingReviewView()
                } else if roleManager.verificationStatus == .verified {
                    // Verified - show dashboard
                    Officials_DashboardView()
                } else {
                    // Other status (rejected, expired) - show status view
                    Officials_StatusView()
                }
            }
        }
        .tint(ColorSystem.Brand.primary)
    }
}

// MARK: - Pending Review View

/// Shown while verification is under review
struct Officials_PendingReviewView: View {
    @EnvironmentObject private var roleManager: RoleManager

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            // Animated icon
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 80))
                .foregroundStyle(ColorSystem.Brand.primary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Spacing.md) {
                Text("Verification Under Review")
                    .font(Typography.title2)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text("We're reviewing your verification request. This typically takes 1-3 business days.")
                    .font(Typography.body)
                    .foregroundStyle(ColorSystem.Content.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Status card
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(ColorSystem.Brand.primary)
                    Text("We'll email you when your verification is complete")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)
                }

                HStack {
                    Image(systemName: "bell")
                        .foregroundStyle(ColorSystem.Brand.primary)
                    Text("You'll also receive a push notification")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)
                }
            }
            .padding(Spacing.lg)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Preview button
            Button {
                // Navigate to preview
            } label: {
                Text("Preview Your Profile")
                    .font(Typography.buttonPrimary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSSecondaryButtonStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(ColorSystem.Gradients.appBackground)
        .navigationTitle("Verification Status")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Status View

/// Shown for rejected or expired verification
struct Officials_StatusView: View {
    @EnvironmentObject private var roleManager: RoleManager

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            // Status icon
            Image(systemName: roleManager.verificationStatus.icon)
                .font(.system(size: 80))
                .foregroundStyle(statusColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Spacing.md) {
                Text(statusTitle)
                    .font(Typography.title2)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text(statusMessage)
                    .font(Typography.body)
                    .foregroundStyle(ColorSystem.Content.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            // Action button
            Button {
                // Restart verification
                roleManager.setOfficialProfile(id: roleManager.officialProfileId, status: .unverified)
            } label: {
                Text(actionButtonTitle)
                    .font(Typography.buttonPrimary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(ColorSystem.Gradients.appBackground)
        .navigationTitle("Verification Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusColor: Color {
        switch roleManager.verificationStatus {
        case .rejected:
            return ColorSystem.Status.error
        case .expired:
            return ColorSystem.Status.warning
        default:
            return ColorSystem.Content.secondary
        }
    }

    private var statusTitle: String {
        switch roleManager.verificationStatus {
        case .rejected:
            return "Verification Rejected"
        case .expired:
            return "Verification Expired"
        default:
            return "Unknown Status"
        }
    }

    private var statusMessage: String {
        switch roleManager.verificationStatus {
        case .rejected:
            return "Your verification request was not approved. You can try again with different documentation."
        case .expired:
            return "Your verification has expired. Please complete the verification process again."
        default:
            return "Please contact support for assistance."
        }
    }

    private var actionButtonTitle: String {
        switch roleManager.verificationStatus {
        case .rejected:
            return "Try Again"
        case .expired:
            return "Reverify"
        default:
            return "Contact Support"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_RootView_Previews: PreviewProvider {
    static var previews: some View {
        Officials_RootView()
            .environmentObject(RoleManager())
    }
}
#endif
