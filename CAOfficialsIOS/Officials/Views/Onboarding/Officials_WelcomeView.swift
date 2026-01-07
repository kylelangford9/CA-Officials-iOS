//
//  Officials_WelcomeView.swift
//  CA Officials
//
//  Welcome/onboarding screen for new officials
//

import SwiftUI

/// Welcome view shown to unauthenticated users
struct Officials_WelcomeView: View {
    @EnvironmentObject private var roleManager: RoleManager

    @State private var showingSignIn = false
    @State private var showingSignUp = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: Spacing.xl) {
                // App icon/logo
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(ColorSystem.Brand.primary)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: Spacing.md) {
                    Text("CA Officials")
                        .font(Typography.heroTitle)
                        .foregroundStyle(ColorSystem.Content.primary)

                    Text("Connect directly with your constituents")
                        .font(Typography.body)
                        .foregroundStyle(ColorSystem.Content.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: Spacing.lg) {
                FeatureRow(
                    icon: "checkmark.seal.fill",
                    title: "Get Verified",
                    description: "Verify your official status with your government email"
                )

                FeatureRow(
                    icon: "person.crop.rectangle.stack",
                    title: "Manage Your Profile",
                    description: "Share your positions, contact info, and updates"
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Engagement",
                    description: "See how voters interact with your profile"
                )

                FeatureRow(
                    icon: "bubble.left.and.bubble.right",
                    title: "Connect",
                    description: "Post updates and engage with constituents"
                )
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Action buttons
            VStack(spacing: Spacing.md) {
                Button {
                    HapticManager.shared.buttonTap()
                    showingSignUp = true
                } label: {
                    Text("Get Started")
                        .font(Typography.buttonPrimary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPrimaryButtonStyle())

                Button {
                    HapticManager.shared.light()
                    showingSignIn = true
                } label: {
                    Text("I already have an account")
                        .font(Typography.subheadlineMedium)
                        .foregroundStyle(ColorSystem.Brand.primary)
                }
                .padding(.vertical, Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(ColorSystem.Gradients.appBackground)
        .sheet(isPresented: $showingSignIn) {
            Officials_SignInView()
                .environmentObject(roleManager)
        }
        .sheet(isPresented: $showingSignUp) {
            Officials_SignUpView()
                .environmentObject(roleManager)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(ColorSystem.Brand.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(ColorSystem.Content.primary)

                Text(description)
                    .font(Typography.subheadline)
                    .foregroundStyle(ColorSystem.Content.secondary)
            }
        }
    }
}

// MARK: - Sign In View

struct Officials_SignInView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValidEmail: Bool {
        if email.isEmpty { return true }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private var canSignIn: Bool {
        !email.isEmpty && isValidEmail && !password.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(ColorSystem.Brand.primary)

                        Text("Welcome Back")
                            .font(Typography.title2)
                            .foregroundStyle(ColorSystem.Content.primary)
                    }
                    .padding(.top, Spacing.xxl)

                    // Form
                    VStack(spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Email")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.secondary)

                            TextField("your.email@gov.ca.gov", text: $email)
                                .textFieldStyle(OfficialTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(!email.isEmpty && !isValidEmail ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                                )

                            if !email.isEmpty && !isValidEmail {
                                Text("Please enter a valid email address")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorSystem.Status.error)
                            }
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Password")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.secondary)

                            SecureField("Password", text: $password)
                                .textFieldStyle(OfficialTextFieldStyle())
                                .textContentType(.password)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Status.error)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .disabled(isLoading)

                    // Sign In Button
                    Button {
                        signIn()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .font(Typography.buttonPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(!canSignIn)
                    .padding(.horizontal, Spacing.lg)

                    // Forgot password
                    Button {
                        HapticManager.shared.light()
                        // Handle forgot password
                    } label: {
                        Text("Forgot password?")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Brand.primary)
                    }
                    .disabled(isLoading)
                }
            }
            .background(ColorSystem.Surface.base)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func signIn() {
        HapticManager.shared.buttonTap()
        isLoading = true
        errorMessage = nil

        // Simulate sign in for now
        // In production, this would call Supabase Auth
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            await MainActor.run {
                isLoading = false
                // For demo, simulate successful login
                roleManager.setAuthenticated(true)
                roleManager.setRole(.official)
                HapticManager.shared.success()
                dismiss()
            }
        }
    }
}

// MARK: - Sign Up View

struct Officials_SignUpView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValidEmail: Bool {
        if email.isEmpty { return true }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private var isPasswordValid: Bool {
        password.isEmpty || password.count >= 8
    }

    private var doPasswordsMatch: Bool {
        confirmPassword.isEmpty || password == confirmPassword
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.isEmpty &&
        isValidEmail &&
        password.count >= 8 &&
        password == confirmPassword &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(ColorSystem.Brand.primary)

                        Text("Create Account")
                            .font(Typography.title2)
                            .foregroundStyle(ColorSystem.Content.primary)

                        Text("Use your official government email")
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }
                    .padding(.top, Spacing.xl)

                    // Form
                    VStack(spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Full Name")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.secondary)

                            TextField("Jane Smith", text: $name)
                                .textFieldStyle(OfficialTextFieldStyle())
                                .textContentType(.name)
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Government Email")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.secondary)

                            TextField("your.name@gov.ca.gov", text: $email)
                                .textFieldStyle(OfficialTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(!email.isEmpty && !isValidEmail ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                                )

                            if !email.isEmpty && !isValidEmail {
                                Text("Please enter a valid email address")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorSystem.Status.error)
                            }
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Password")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorSystem.Content.secondary)

                                Spacer()

                                if !password.isEmpty {
                                    Text("\(password.count)/8 min")
                                        .font(Typography.caption)
                                        .foregroundStyle(password.count >= 8 ? ColorSystem.Status.success : ColorSystem.Status.warning)
                                }
                            }

                            SecureField("At least 8 characters", text: $password)
                                .textFieldStyle(OfficialTextFieldStyle())
                                .textContentType(.newPassword)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(!password.isEmpty && !isPasswordValid ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                                )

                            if !password.isEmpty && !isPasswordValid {
                                Text("Password must be at least 8 characters")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorSystem.Status.error)
                            }
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Confirm Password")
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Content.secondary)

                            SecureField("Confirm password", text: $confirmPassword)
                                .textFieldStyle(OfficialTextFieldStyle())
                                .textContentType(.newPassword)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(!confirmPassword.isEmpty && !doPasswordsMatch ? ColorSystem.Status.error : Color.clear, lineWidth: 1)
                                )

                            if !confirmPassword.isEmpty && !doPasswordsMatch {
                                Text("Passwords don't match")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorSystem.Status.error)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(Typography.caption)
                                .foregroundStyle(ColorSystem.Status.error)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .disabled(isLoading)

                    // Sign Up Button
                    Button {
                        signUp()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                                .font(Typography.buttonPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(!isFormValid)
                    .padding(.horizontal, Spacing.lg)

                    // Terms
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(Typography.caption)
                        .foregroundStyle(ColorSystem.Content.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }
                .padding(.bottom, Spacing.xxl)
            }
            .background(ColorSystem.Surface.base)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func signUp() {
        HapticManager.shared.buttonTap()
        isLoading = true
        errorMessage = nil

        // Simulate sign up for now
        // In production, this would call Supabase Auth
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            await MainActor.run {
                isLoading = false
                // For demo, simulate successful registration
                roleManager.setAuthenticated(true)
                roleManager.setRole(.official)
                HapticManager.shared.success()
                dismiss()
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct OfficialTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Spacing.md)
            .background(ColorSystem.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(ColorSystem.Border.subtle, lineWidth: BorderWidth.thin)
            )
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        Officials_WelcomeView()
            .environmentObject(RoleManager())
    }
}
#endif
