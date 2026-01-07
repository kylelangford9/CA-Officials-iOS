//
//  Officials_GovernmentOffice.swift
//  CA Officials
//
//  Model for government offices/positions
//

import Foundation

/// Represents a government office that can be claimed by an official
struct Officials_GovernmentOffice: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var level: String  // Maps to representative_level enum
    var jurisdiction: String
    var district: String?
    var incumbentName: String?
    var isClaimed: Bool
    var claimedBy: UUID?
    var representativeId: UUID?
    var termStart: Date?
    var termEnd: Date?
    var websiteUrl: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case level
        case jurisdiction
        case district
        case incumbentName = "incumbent_name"
        case isClaimed = "is_claimed"
        case claimedBy = "claimed_by"
        case representativeId = "representative_id"
        case termStart = "term_start"
        case termEnd = "term_end"
        case websiteUrl = "website_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Formatted display name for the office
    var displayName: String {
        if let district = district, !district.isEmpty {
            return "\(title), \(district)"
        }
        return title
    }

    /// Full location string
    var locationString: String {
        if let district = district, !district.isEmpty {
            return "\(jurisdiction) - \(district)"
        }
        return jurisdiction
    }

    /// Level display name
    var levelDisplayName: String {
        switch level.lowercased() {
        case "federal": return "Federal"
        case "state": return "State"
        case "county": return "County"
        case "local", "city": return "Local"
        case "special": return "Special District"
        default: return level.capitalized
        }
    }

    /// Whether the term has expired
    var isTermExpired: Bool {
        guard let termEnd = termEnd else { return false }
        return termEnd < Date()
    }

    /// Days until term ends (negative if expired)
    var daysUntilTermEnd: Int? {
        guard let termEnd = termEnd else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: termEnd)
        return components.day
    }
}

// MARK: - Search & Filter

extension Officials_GovernmentOffice {
    /// Check if office matches search query
    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        return title.lowercased().contains(query) ||
               jurisdiction.lowercased().contains(query) ||
               (district?.lowercased().contains(query) ?? false) ||
               (incumbentName?.lowercased().contains(query) ?? false)
    }
}

// MARK: - Preview Data

#if DEBUG
extension Officials_GovernmentOffice {
    static let preview = Officials_GovernmentOffice(
        id: UUID(),
        title: "State Senator",
        level: "state",
        jurisdiction: "California",
        district: "District 15",
        incumbentName: "Jane Smith",
        isClaimed: true,
        claimedBy: UUID(),
        representativeId: nil,
        termStart: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
        termEnd: Calendar.current.date(byAdding: .year, value: 2, to: Date()),
        websiteUrl: "https://sd15.senate.ca.gov",
        createdAt: Date(),
        updatedAt: Date()
    )

    static let previewUnclaimed = Officials_GovernmentOffice(
        id: UUID(),
        title: "City Council Member",
        level: "local",
        jurisdiction: "San Francisco",
        district: "District 5",
        incumbentName: "Open Seat",
        isClaimed: false,
        claimedBy: nil,
        representativeId: nil,
        termStart: nil,
        termEnd: nil,
        websiteUrl: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    static let previewArray: [Officials_GovernmentOffice] = [
        preview,
        previewUnclaimed,
        Officials_GovernmentOffice(
            id: UUID(),
            title: "Assembly Member",
            level: "state",
            jurisdiction: "California",
            district: "District 19",
            incumbentName: nil,
            isClaimed: false,
            claimedBy: nil,
            representativeId: nil,
            termStart: nil,
            termEnd: nil,
            websiteUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Officials_GovernmentOffice(
            id: UUID(),
            title: "Mayor",
            level: "local",
            jurisdiction: "Los Angeles",
            district: nil,
            incumbentName: "Current Mayor",
            isClaimed: true,
            claimedBy: UUID(),
            representativeId: nil,
            termStart: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
            termEnd: Calendar.current.date(byAdding: .year, value: 3, to: Date()),
            websiteUrl: "https://mayor.lacity.org",
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}
#endif
