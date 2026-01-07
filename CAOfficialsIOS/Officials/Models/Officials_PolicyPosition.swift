//
//  Officials_PolicyPosition.swift
//  CA Officials
//
//  Model for policy positions
//

import Foundation

/// Represents a policy position held by an official
struct Officials_PolicyPosition: Codable, Identifiable, Equatable {
    let id: UUID
    let officialId: UUID
    var topic: String
    var stance: String?
    var summary: String?
    var detailedPosition: String?
    var isFeatured: Bool
    var displayOrder: Int
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case officialId = "official_id"
        case topic, stance, summary
        case detailedPosition = "detailed_position"
        case isFeatured = "is_featured"
        case displayOrder = "display_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Stance Options

    enum Stance: String, CaseIterable, Codable {
        case support
        case oppose
        case neutral

        var displayName: String {
            switch self {
            case .support: return "Support"
            case .oppose: return "Oppose"
            case .neutral: return "Neutral"
            }
        }

        var icon: String {
            switch self {
            case .support: return "hand.thumbsup.fill"
            case .oppose: return "hand.thumbsdown.fill"
            case .neutral: return "minus.circle.fill"
            }
        }
    }

    // MARK: - Common Topics

    static let commonTopics = [
        "Education",
        "Healthcare",
        "Environment",
        "Economy",
        "Housing",
        "Transportation",
        "Public Safety",
        "Immigration",
        "Gun Control",
        "Abortion Rights",
        "Tax Policy",
        "Criminal Justice Reform",
        "Climate Change",
        "Infrastructure",
        "Social Security",
        "Veterans Affairs",
        "Foreign Policy",
        "Labor Rights",
        "Civil Rights",
        "Technology & Privacy"
    ]

    // MARK: - Computed Properties

    var stanceType: Stance? {
        guard let stance = stance else { return nil }
        return Stance(rawValue: stance)
    }

    var description: String? {
        summary
    }
}

// MARK: - Preview Data

#if DEBUG
extension Officials_PolicyPosition {
    static let previewEducation = Officials_PolicyPosition(
        id: UUID(),
        officialId: UUID(),
        topic: "Education",
        stance: "support",
        summary: "I strongly support increased funding for public schools and teacher salaries.",
        detailedPosition: nil,
        isFeatured: true,
        displayOrder: 1,
        createdAt: Date(),
        updatedAt: nil
    )

    static let previewHealthcare = Officials_PolicyPosition(
        id: UUID(),
        officialId: UUID(),
        topic: "Healthcare",
        stance: "support",
        summary: "Universal healthcare access is a fundamental right.",
        detailedPosition: nil,
        isFeatured: true,
        displayOrder: 2,
        createdAt: Date(),
        updatedAt: nil
    )

    static let previewEnvironment = Officials_PolicyPosition(
        id: UUID(),
        officialId: UUID(),
        topic: "Environment",
        stance: "support",
        summary: "Climate action is urgent. I support transitioning to renewable energy.",
        detailedPosition: nil,
        isFeatured: false,
        displayOrder: 3,
        createdAt: Date(),
        updatedAt: nil
    )

    static let previewArray: [Officials_PolicyPosition] = [
        previewEducation,
        previewHealthcare,
        previewEnvironment
    ]
}
#endif
