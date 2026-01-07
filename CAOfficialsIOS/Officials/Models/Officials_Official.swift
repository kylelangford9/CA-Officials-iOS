//
//  Officials_Official.swift
//  CA Officials
//
//  Model for official profiles
//

import Foundation

/// Represents a government official's profile
struct Officials_Official: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID?
    let officeId: UUID?
    let representativeId: UUID?

    // Basic Info
    var name: String
    var title: String?
    var bio: String?
    var pronouns: String?
    var party: String?  // Maps to political_party enum

    // Media
    var photoUrl: String?
    var bannerUrl: String?

    // Verification
    var verificationStatus: String  // Maps to verification_status enum
    var verifiedAt: Date?
    var verificationMethod: String?  // Maps to verification_method enum

    // Contact Info (JSONB)
    var contactInfo: ContactInfo?

    // Social Links (JSONB)
    var socialLinks: SocialLinks?

    // Metadata
    var isActive: Bool
    var createdAt: Date?
    var updatedAt: Date?

    // MARK: - Nested Types

    struct ContactInfo: Codable, Equatable {
        var officePhone: String?
        var officeEmail: String?
        var officeAddress: String?
        var mailingAddress: String?

        enum CodingKeys: String, CodingKey {
            case officePhone = "office_phone"
            case officeEmail = "office_email"
            case officeAddress = "office_address"
            case mailingAddress = "mailing_address"
        }
    }

    struct SocialLinks: Codable, Equatable {
        var websiteUrl: String?
        var twitterHandle: String?
        var facebookUrl: String?
        var instagramHandle: String?
        var linkedinUrl: String?
        var youtubeUrl: String?

        enum CodingKeys: String, CodingKey {
            case websiteUrl = "website_url"
            case twitterHandle = "twitter_handle"
            case facebookUrl = "facebook_url"
            case instagramHandle = "instagram_handle"
            case linkedinUrl = "linkedin_url"
            case youtubeUrl = "youtube_url"
        }
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case officeId = "office_id"
        case representativeId = "representative_id"
        case name
        case title
        case bio
        case pronouns
        case party
        case photoUrl = "photo_url"
        case bannerUrl = "banner_url"
        case verificationStatus = "verification_status"
        case verifiedAt = "verified_at"
        case verificationMethod = "verification_method"
        case contactInfo = "contact_info"
        case socialLinks = "social_links"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var isVerified: Bool {
        verificationStatus == "verified"
    }

    var displayParty: String {
        guard let party = party else { return "Unknown" }
        return party.capitalized.replacingOccurrences(of: "_", with: " ")
    }

    var partyAbbreviation: String {
        guard let party = party?.lowercased() else { return "" }
        switch party {
        case "democratic": return "D"
        case "republican": return "R"
        case "independent": return "I"
        case "libertarian": return "L"
        case "green": return "G"
        case "nonpartisan": return "NP"
        default: return ""
        }
    }

    // MARK: - Static Factory

    /// Create an empty profile for a new official
    static func empty(userId: UUID) -> Officials_Official {
        Officials_Official(
            id: UUID(),
            userId: userId,
            officeId: nil,
            representativeId: nil,
            name: "",
            title: nil,
            bio: nil,
            pronouns: nil,
            party: "unknown",
            photoUrl: nil,
            bannerUrl: nil,
            verificationStatus: "unverified",
            verifiedAt: nil,
            verificationMethod: nil,
            contactInfo: ContactInfo(),
            socialLinks: SocialLinks(),
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Preview Data

#if DEBUG
extension Officials_Official {
    static let preview = Officials_Official(
        id: UUID(),
        userId: UUID(),
        officeId: UUID(),
        representativeId: nil,
        name: "Jane Smith",
        title: "State Senator, District 15",
        bio: "Serving California's 15th Senate District since 2020. Focused on education, healthcare, and environmental protection.",
        pronouns: "she/her",
        party: "democratic",
        photoUrl: nil,
        bannerUrl: nil,
        verificationStatus: "verified",
        verifiedAt: Date(),
        verificationMethod: "government_email",
        contactInfo: ContactInfo(
            officePhone: "(916) 555-1234",
            officeEmail: "senator.smith@senate.ca.gov",
            officeAddress: "State Capitol, Room 5100, Sacramento, CA 95814",
            mailingAddress: nil
        ),
        socialLinks: SocialLinks(
            websiteUrl: "https://sd15.senate.ca.gov",
            twitterHandle: "@SenatorSmith",
            facebookUrl: nil,
            instagramHandle: nil,
            linkedinUrl: nil,
            youtubeUrl: nil
        ),
        isActive: true,
        createdAt: Date(),
        updatedAt: Date()
    )

    static let previewUnverified = Officials_Official(
        id: UUID(),
        userId: UUID(),
        officeId: nil,
        representativeId: nil,
        name: "John Doe",
        title: nil,
        bio: nil,
        pronouns: nil,
        party: nil,
        photoUrl: nil,
        bannerUrl: nil,
        verificationStatus: "unverified",
        verifiedAt: nil,
        verificationMethod: nil,
        contactInfo: nil,
        socialLinks: nil,
        isActive: true,
        createdAt: Date(),
        updatedAt: Date()
    )
}
#endif
