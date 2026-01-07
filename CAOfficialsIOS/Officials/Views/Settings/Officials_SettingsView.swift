//
//  Officials_SettingsView.swift
//  CA Officials
//
//  Settings view for officials
//

import SwiftUI

/// Settings view for managing account and preferences
struct Officials_SettingsView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @Environment(\.dismiss) private var dismiss

    @State private var notificationsEnabled = true
    @State private var emailDigest = true
    @State private var showingSignOutAlert = false
    @State private var showingStaffAccess = false

    var body: some View {
        List {
            // Account section
            Section("Account") {
                HStack {
                    Circle()
                        .fill(ColorSystem.Brand.primary.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(ColorSystem.Brand.primary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Senator Jane Smith")
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(ColorSystem.Content.primary)

                        Text("senator.smith@senate.ca.gov")
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Content.secondary)
                    }

                    Spacer()

                    Officials_VerifiedBadge()
                }

                NavigationLink {
                    Text("Account Details")
                } label: {
                    Label("Account Details", systemImage: "person.circle")
                }

                NavigationLink {
                    Text("Change Password")
                } label: {
                    Label("Change Password", systemImage: "lock")
                }
            }

            // Staff access
            Section("Team") {
                NavigationLink {
                    Officials_StaffAccessView()
                } label: {
                    HStack {
                        Label("Staff Access", systemImage: "person.2")

                        Spacer()

                        Text("3 members")
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Content.tertiary)
                    }
                }
            }

            // Notifications
            Section("Notifications") {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Push Notifications", systemImage: "bell")
                }

                Toggle(isOn: $emailDigest) {
                    Label("Weekly Email Digest", systemImage: "envelope")
                }

                NavigationLink {
                    Text("Notification Preferences")
                } label: {
                    Label("Notification Preferences", systemImage: "bell.badge")
                }
            }

            // Privacy
            Section("Privacy") {
                NavigationLink {
                    Text("Privacy Settings")
                } label: {
                    Label("Privacy Settings", systemImage: "hand.raised")
                }

                NavigationLink {
                    Text("Blocked Accounts")
                } label: {
                    Label("Blocked Accounts", systemImage: "nosign")
                }
            }

            // Support
            Section("Support") {
                NavigationLink {
                    Text("Help Center")
                } label: {
                    Label("Help Center", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    Text("Contact Support")
                } label: {
                    Label("Contact Support", systemImage: "envelope")
                }

                NavigationLink {
                    Text("Report a Problem")
                } label: {
                    Label("Report a Problem", systemImage: "exclamationmark.bubble")
                }
            }

            // Legal
            Section("Legal") {
                NavigationLink {
                    Text("Terms of Service")
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }

                NavigationLink {
                    Text("Privacy Policy")
                } label: {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }

                NavigationLink {
                    Text("Licenses")
                } label: {
                    Label("Open Source Licenses", systemImage: "doc.badge.gearshape")
                }
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    showingSignOutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                        Spacer()
                    }
                }
            }

            // App info
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (1)")
                        .foregroundStyle(ColorSystem.Content.tertiary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    private func signOut() {
        HapticManager.shared.medium()

        // Clear all cached data for security
        Officials_ProfileService.shared.clearCache()
        Officials_AnalyticsService.shared.clearCache()
        Connect_FeedService.shared.clearCache()
        Connect_FollowService.shared.clearCache()
        Connect_PostService.shared.clearCache()

        #if DEBUG
        print("🔒 [Settings] All caches cleared on sign out")
        #endif

        roleManager.resetToVoter()
        dismiss()
    }
}

// MARK: - Staff Access View

struct Officials_StaffAccessView: View {
    @State private var showingInvite = false

    // Demo data
    let staffMembers = [
        StaffMember(name: "John Doe", email: "john@staff.gov", role: "Communications Director", canPost: true, canEdit: true),
        StaffMember(name: "Mary Johnson", email: "mary@staff.gov", role: "Policy Advisor", canPost: false, canEdit: true),
        StaffMember(name: "Bob Williams", email: "bob@staff.gov", role: "Scheduler", canPost: false, canEdit: false)
    ]

    struct StaffMember: Identifiable {
        let id = UUID()
        let name: String
        let email: String
        let role: String
        let canPost: Bool
        let canEdit: Bool
    }

    var body: some View {
        List {
            Section {
                ForEach(staffMembers) { member in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(member.name)
                                .font(Typography.bodyEmphasized)
                                .foregroundStyle(ColorSystem.Content.primary)

                            Spacer()

                            Menu {
                                Button("Edit Permissions") { }
                                Button("Remove Access", role: .destructive) { }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(ColorSystem.Content.secondary)
                            }
                        }

                        Text(member.role)
                            .font(Typography.subheadline)
                            .foregroundStyle(ColorSystem.Content.secondary)

                        Text(member.email)
                            .font(Typography.caption)
                            .foregroundStyle(ColorSystem.Content.tertiary)

                        HStack(spacing: Spacing.sm) {
                            if member.canPost {
                                PermissionBadge(text: "Can Post", color: ColorSystem.Status.success)
                            }
                            if member.canEdit {
                                PermissionBadge(text: "Can Edit", color: ColorSystem.Brand.primary)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            } header: {
                Text("Team Members")
            } footer: {
                Text("Staff members can help manage your profile based on the permissions you grant.")
            }

            Section {
                Button {
                    showingInvite = true
                } label: {
                    Label("Invite Staff Member", systemImage: "person.badge.plus")
                }
            }
        }
        .navigationTitle("Staff Access")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInvite) {
            NavigationStack {
                Text("Invite Staff")
                    .navigationTitle("Invite Staff")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingInvite = false
                            }
                        }
                    }
            }
        }
    }
}

struct PermissionBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Typography.captionSemibold)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
struct Officials_SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Officials_SettingsView()
                .environmentObject(RoleManager())
        }
    }
}
#endif
