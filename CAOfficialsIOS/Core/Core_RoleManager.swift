//
//  Core_RoleManager.swift
//  CA Officials
//
//  Manages user role state and authentication status
//

import Foundation
import SwiftUI

/// Manages the current user's role and authentication state
@MainActor
final class RoleManager: ObservableObject {

    // MARK: - Published Properties

    /// Current user role
    @Published private(set) var currentRole: UserRole = .voter

    /// Whether the user is authenticated
    @Published private(set) var isAuthenticated: Bool = false

    /// Official profile ID if user is an official or delegate
    @Published private(set) var officialProfileId: UUID?

    /// Current authenticated user ID
    @Published private(set) var currentUserId: UUID?

    /// Verification status of the official profile
    @Published private(set) var verificationStatus: VerificationStatus = .unverified

    /// Whether the user has completed onboarding
    @AppStorage("hasCompletedOfficialOnboarding") private var hasCompletedOnboarding: Bool = false

    // MARK: - Computed Properties

    /// Whether the user can access the officials dashboard
    var canAccessDashboard: Bool {
        currentRole.canAccessOfficialsDashboard && isAuthenticated
    }

    /// Whether the user is a verified official
    var isVerifiedOfficial: Bool {
        currentRole == .official && verificationStatus == .verified
    }

    /// Whether onboarding is needed
    var needsOnboarding: Bool {
        !hasCompletedOnboarding && currentRole == .official
    }

    // MARK: - Initialization

    init() {
        // Load saved state from persistence
        loadSavedState()
    }

    // MARK: - Public Methods

    /// Set the current user role
    func setRole(_ role: UserRole) {
        currentRole = role
        saveState()

        #if DEBUG
        print("[RoleManager] Role set to: \(role.displayName)")
        #endif
    }

    /// Set authentication state
    func setAuthenticated(_ authenticated: Bool, userId: UUID? = nil) {
        isAuthenticated = authenticated
        currentUserId = userId
        saveState()

        #if DEBUG
        print("[RoleManager] Authenticated: \(authenticated), userId: \(userId?.uuidString ?? "nil")")
        #endif
    }

    /// Set the official profile ID
    func setOfficialProfile(id: UUID?, status: VerificationStatus) {
        officialProfileId = id
        verificationStatus = status
        saveState()

        #if DEBUG
        print("[RoleManager] Official profile set: \(id?.uuidString ?? "nil"), status: \(status.rawValue)")
        #endif
    }

    /// Mark onboarding as complete
    func completeOnboarding() {
        hasCompletedOnboarding = true

        #if DEBUG
        print("[RoleManager] Onboarding completed")
        #endif
    }

    /// Reset to voter role (sign out)
    func resetToVoter() {
        currentRole = .voter
        isAuthenticated = false
        currentUserId = nil
        officialProfileId = nil
        verificationStatus = .unverified
        saveState()

        #if DEBUG
        print("[RoleManager] Reset to voter role")
        #endif
    }

    // MARK: - Private Methods

    private func loadSavedState() {
        // Load role from UserDefaults
        if let roleString = UserDefaults.standard.string(forKey: "currentUserRole"),
           let role = UserRole(rawValue: roleString) {
            currentRole = role
        }

        // Load authentication state
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")

        // Load current user ID
        if let idString = UserDefaults.standard.string(forKey: "currentUserId"),
           let id = UUID(uuidString: idString) {
            currentUserId = id
        }

        // Load official profile ID
        if let idString = UserDefaults.standard.string(forKey: "officialProfileId"),
           let id = UUID(uuidString: idString) {
            officialProfileId = id
        }

        // Load verification status
        if let statusString = UserDefaults.standard.string(forKey: "verificationStatus"),
           let status = VerificationStatus(rawValue: statusString) {
            verificationStatus = status
        }

        #if DEBUG
        print("[RoleManager] Loaded state - Role: \(currentRole.displayName), Auth: \(isAuthenticated)")
        #endif
    }

    private func saveState() {
        UserDefaults.standard.set(currentRole.rawValue, forKey: "currentUserRole")
        UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        UserDefaults.standard.set(currentUserId?.uuidString, forKey: "currentUserId")
        UserDefaults.standard.set(officialProfileId?.uuidString, forKey: "officialProfileId")
        UserDefaults.standard.set(verificationStatus.rawValue, forKey: "verificationStatus")
    }
}

// MARK: - Verification Status

/// Verification status for official profiles
/// Mirrors the database enum
enum VerificationStatus: String, Codable, CaseIterable {
    case unverified
    case pending
    case verified
    case rejected
    case expired

    var displayName: String {
        switch self {
        case .unverified:
            return "Not Verified"
        case .pending:
            return "Pending Review"
        case .verified:
            return "Verified"
        case .rejected:
            return "Rejected"
        case .expired:
            return "Expired"
        }
    }

    var icon: String {
        switch self {
        case .unverified:
            return "questionmark.circle"
        case .pending:
            return "clock"
        case .verified:
            return "checkmark.seal.fill"
        case .rejected:
            return "xmark.circle"
        case .expired:
            return "exclamationmark.triangle"
        }
    }
}
