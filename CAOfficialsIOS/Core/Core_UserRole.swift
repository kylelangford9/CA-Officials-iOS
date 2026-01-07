//
//  Core_UserRole.swift
//  CA Officials
//
//  Defines user roles for the app
//

import Foundation

/// User roles determine what features are available
enum UserRole: String, Codable, CaseIterable {
    /// Regular voter using the app to find information
    case voter

    /// Verified government official managing their profile
    case official

    /// Staff member with delegated access to an official's profile
    case delegate

    /// Admin with elevated permissions (future use)
    case admin

    /// Display name for the role
    var displayName: String {
        switch self {
        case .voter:
            return "Voter"
        case .official:
            return "Official"
        case .delegate:
            return "Staff Member"
        case .admin:
            return "Administrator"
        }
    }

    /// Description of what this role can do
    var description: String {
        switch self {
        case .voter:
            return "Access voter information and follow officials"
        case .official:
            return "Manage your official profile and connect with constituents"
        case .delegate:
            return "Help manage an official's profile with delegated permissions"
        case .admin:
            return "Full administrative access"
        }
    }

    /// Whether this role can access the Officials dashboard
    var canAccessOfficialsDashboard: Bool {
        switch self {
        case .official, .delegate, .admin:
            return true
        case .voter:
            return false
        }
    }

    /// Whether this role can post updates
    var canPost: Bool {
        switch self {
        case .official, .delegate, .admin:
            return true
        case .voter:
            return false
        }
    }
}
