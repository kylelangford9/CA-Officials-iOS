//
//  Officials_VerifyMethodView.swift
//  CA Officials
//
//  Verification method selection view
//

import SwiftUI

/// View for selecting verification method
struct Officials_VerifyMethodView: View {
    @Binding var selectedMethod: Officials_VerificationMethod?
    let selectedOffice: Officials_GovernmentOffice?
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            VStack(spacing: Spacing.md) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorSystem.Brand.primary)

                Text("Verify Your Identity")
                    .font(Typography.title2)
                    .foregroundStyle(ColorSystem.Content.primary)

                if let office = selectedOffice {
                    Text("Claiming: \(office.displayName)")
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)
                }
            }
            .padding(.top, Spacing.xl)

            // Method options
            VStack(spacing: Spacing.md) {
                ForEach(Officials_VerificationMethod.allCases) { method in
                    VerificationMethodCard(
                        method: method,
                        isSelected: selectedMethod == method,
                        onSelect: {
                            HapticManager.shared.selectionChanged()
                            selectedMethod = method
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                Button {
                    onNext()
                } label: {
                    Text("Continue")
                        .font(Typography.buttonPrimary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(selectedMethod == nil)

                Button {
                    onBack()
                } label: {
                    Text("Back")
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
    }
}

struct VerificationMethodCard: View {
    let method: Officials_VerificationMethod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                Image(systemName: method.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? ColorSystem.Brand.primary : ColorSystem.Content.secondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(method.displayName)
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(ColorSystem.Content.primary)

                        if method.isInstant {
                            Text("Instant")
                                .font(Typography.captionSemibold)
                                .foregroundStyle(ColorSystem.Status.success)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 2)
                                .background(ColorSystem.Status.successContainer)
                                .clipShape(Capsule())
                        }
                    }

                    Text(method.description)
                        .font(Typography.subheadline)
                        .foregroundStyle(ColorSystem.Content.secondary)
                        .lineLimit(2)

                    Text("Estimated time: \(method.estimatedTime)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.tertiary)
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
struct Officials_VerifyMethodView_Previews: PreviewProvider {
    static var previews: some View {
        Officials_VerifyMethodView(
            selectedMethod: .constant(.governmentEmail),
            selectedOffice: .preview,
            onNext: {},
            onBack: {}
        )
    }
}
#endif
