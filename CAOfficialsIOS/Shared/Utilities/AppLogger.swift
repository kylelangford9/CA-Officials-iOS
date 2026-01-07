//
//  AppLogger.swift
//  California Voters
//
//  Centralized logging system using Apple's OSLog for structured, performant logging.
//  This is the canonical logger for the app - use this instead of LegacyLogger.
//

import OSLog
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Centralized logging system using OSLog for structured, performant logging.
/// Categories separate concerns for easier filtering in Console.app.
/// Use signposts to bracket expensive operations for Instruments profiling.
///
/// This is the preferred logging system. Use these loggers instead of print() or LegacyLogger.
public enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.cavoters.app"

    // MARK: - Log Categories

    /// UI events, view lifecycle, user interactions
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Network requests, API calls, response handling
    public static let network = Logger(subsystem: subsystem, category: "network")

    /// Geocoding, location updates, coordinate operations
    public static let geo = Logger(subsystem: subsystem, category: "geo")

    /// Map rendering, camera changes, annotation updates
    public static let map = Logger(subsystem: subsystem, category: "map")

    /// Data management and caching
    public static let data = Logger(subsystem: subsystem, category: "data")

    /// Configuration and settings
    public static let config = Logger(subsystem: subsystem, category: "config")

    /// Photo fetching and image operations
    public static let photos = Logger(subsystem: subsystem, category: "photos")

    /// AI and legislative data operations
    public static let ai = Logger(subsystem: subsystem, category: "ai")

    /// Location services
    public static let location = Logger(subsystem: subsystem, category: "location")

    // MARK: - Signpost Logs for Performance Instrumentation

    /// OSLog for map-related signposts (camera settle, fetch operations)
    public static let mapSignpost = OSLog(subsystem: subsystem, category: "map")

    /// OSLog for geocoding signposts
    public static let geoSignpost = OSLog(subsystem: subsystem, category: "geo")

    // MARK: - Privacy Helpers

    /// Redacts sensitive strings for logging (e.g., addresses, personal info)
    /// - Parameter string: The sensitive string to redact
    /// - Returns: A redacted version showing only first and last 3 chars
    public static func redacted(_ string: String) -> String {
        #if DEBUG
        return string
        #else
        guard string.count > 6 else {
            return "***"
        }
        let prefix = string.prefix(3)
        let suffix = string.suffix(3)
        return "\(prefix)***\(suffix)"
        #endif
    }

    /// Creates a normalized cache key from an address
    /// - Parameter address: The address to normalize
    /// - Returns: A normalized lowercase address string for caching
    public static func makeAddressKey(_ address: String) -> String {
        return address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Creates a hash-based address key for privacy
    /// - Parameter address: Raw address string
    /// - Returns: SHA-256 hash of the address for use as a cache key
    public static func makeHashedAddressKey(_ address: String) -> String {
        let normalized = address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let salt = "california_voters_salt_2024"
        return sha256(normalized + salt)
    }

    // MARK: - Private Helpers

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        #if canImport(CryptoKit)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
        #else
        return String(input.hashValue)
        #endif
    }
}

