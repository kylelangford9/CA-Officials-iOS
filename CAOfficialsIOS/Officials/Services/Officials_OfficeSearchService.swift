//
//  Officials_OfficeSearchService.swift
//  CA Officials
//
//  Service for searching government offices
//

import Foundation
import SwiftUI
import Supabase

/// Service for searching and managing government offices
@MainActor
final class Officials_OfficeSearchService: ObservableObject {
    static let shared = Officials_OfficeSearchService()

    // MARK: - Published Properties

    @Published private(set) var searchResults: [Officials_GovernmentOffice] = []
    @Published private(set) var featuredOffices: [Officials_GovernmentOffice] = []
    @Published private(set) var isSearching = false
    @Published private(set) var error: String?

    // MARK: - Private Properties

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    private var searchTask: Task<Void, Never>?

    private init() {
        #if DEBUG
        print("🏛️ [OfficeSearchService] Initialized")
        #endif
    }

    // MARK: - Search

    /// Search offices by query
    func search(query: String) async {
        // Cancel previous search
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        error = nil

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            do {
                let response: [Officials_GovernmentOffice] = try await supabase
                    .from("government_offices")
                    .select()
                    .or("title.ilike.%\(query)%,jurisdiction.ilike.%\(query)%,district.ilike.%\(query)%,incumbent_name.ilike.%\(query)%")
                    .limit(20)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }

                searchResults = response

                #if DEBUG
                print("🏛️ [OfficeSearchService] Found \(response.count) results for '\(query)'")
                #endif

            } catch {
                guard !Task.isCancelled else { return }

                self.error = error.localizedDescription
                searchResults = []

                #if DEBUG
                print("🏛️ [OfficeSearchService] Search error: \(error.localizedDescription)")
                #endif
            }

            isSearching = false
        }
    }

    /// Clear search results
    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
    }

    // MARK: - Fetch Offices

    /// Fetch office by ID
    func fetchOffice(id: UUID) async -> Officials_GovernmentOffice? {
        do {
            let response: Officials_GovernmentOffice = try await supabase
                .from("government_offices")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("🏛️ [OfficeSearchService] Error fetching office: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetch offices by level
    func fetchOffices(level: String, limit: Int = 50) async -> [Officials_GovernmentOffice] {
        do {
            let response: [Officials_GovernmentOffice] = try await supabase
                .from("government_offices")
                .select()
                .eq("level", value: level)
                .order("title")
                .limit(limit)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("🏛️ [OfficeSearchService] Error fetching offices by level: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Fetch unclaimed offices
    func fetchUnclaimedOffices(jurisdiction: String? = nil, limit: Int = 20) async -> [Officials_GovernmentOffice] {
        do {
            var query = supabase
                .from("government_offices")
                .select()
                .eq("is_claimed", value: false)

            if let jurisdiction = jurisdiction {
                query = query.eq("jurisdiction", value: jurisdiction)
            }

            let response: [Officials_GovernmentOffice] = try await query
                .order("level")
                .limit(limit)
                .execute()
                .value

            return response

        } catch {
            #if DEBUG
            print("🏛️ [OfficeSearchService] Error fetching unclaimed offices: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Fetch featured/highlighted offices
    func fetchFeaturedOffices() async {
        do {
            // Fetch a mix of federal, state, and local offices
            let response: [Officials_GovernmentOffice] = try await supabase
                .from("government_offices")
                .select()
                .eq("is_claimed", value: false)
                .limit(10)
                .execute()
                .value

            featuredOffices = response

        } catch {
            #if DEBUG
            print("🏛️ [OfficeSearchService] Error fetching featured offices: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Claim Office

    /// Claim an office for an official
    func claimOffice(officeId: UUID, officialId: UUID) async -> Bool {
        do {
            // First check if already claimed
            let office = await fetchOffice(id: officeId)
            guard let office = office, !office.isClaimed else {
                error = "This office has already been claimed"
                return false
            }

            // Update office - use struct for typed updates
            struct OfficeClaimUpdate: Encodable {
                let is_claimed: Bool
                let claimed_by: String
            }
            try await supabase
                .from("government_offices")
                .update(OfficeClaimUpdate(is_claimed: true, claimed_by: officialId.uuidString))
                .eq("id", value: officeId.uuidString)
                .execute()

            // Update official's office_id
            try await supabase
                .from("officials")
                .update(["office_id": officeId.uuidString])
                .eq("id", value: officialId.uuidString)
                .execute()

            #if DEBUG
            print("🏛️ [OfficeSearchService] Office claimed successfully")
            #endif

            return true

        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("🏛️ [OfficeSearchService] Error claiming office: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Release claim on an office
    func releaseOffice(officeId: UUID) async -> Bool {
        do {
            // Use struct for typed updates
            struct OfficeReleaseUpdate: Encodable {
                let is_claimed: Bool
                let claimed_by: String?
            }
            try await supabase
                .from("government_offices")
                .update(OfficeReleaseUpdate(is_claimed: false, claimed_by: nil))
                .eq("id", value: officeId.uuidString)
                .execute()

            return true

        } catch {
            #if DEBUG
            print("🏛️ [OfficeSearchService] Error releasing office: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Jurisdictions

    /// Get unique jurisdictions
    func fetchJurisdictions() async -> [String] {
        do {
            let response: [JurisdictionResult] = try await supabase
                .from("government_offices")
                .select("jurisdiction")
                .execute()
                .value

            let unique = Set(response.map { $0.jurisdiction })
            return Array(unique).sorted()

        } catch {
            return []
        }
    }

    private struct JurisdictionResult: Codable {
        let jurisdiction: String
    }
}

// MARK: - Office Levels

extension Officials_OfficeSearchService {
    /// Available office levels
    static let officeLevels = [
        OfficeLevel(id: "federal", name: "Federal", icon: "building.columns.fill"),
        OfficeLevel(id: "state", name: "State", icon: "building.2.fill"),
        OfficeLevel(id: "county", name: "County", icon: "building.fill"),
        OfficeLevel(id: "local", name: "City/Local", icon: "house.fill"),
        OfficeLevel(id: "special", name: "Special District", icon: "star.fill")
    ]

    struct OfficeLevel: Identifiable {
        let id: String
        let name: String
        let icon: String
    }
}
