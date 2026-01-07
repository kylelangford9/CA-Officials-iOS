//
//  SupabaseConfig.swift
//  California Voters
//
//  Supabase configuration and credentials
//

import Foundation

/**
 Centralized configuration for Supabase connection.
 
 This struct provides secure access to Supabase credentials and configuration.
 Credentials should be stored in Info.plist or environment variables for security.
 */
struct SupabaseConfig {
    
    // MARK: - Supabase Credentials
    
    /**
     The Supabase Project URL.
     
     This is the base URL for your Supabase project's API.
     
     - Returns: The Supabase URL as a `String`.
     */
    static var supabaseURL: String {
        // Try to get from Info.plist first (injected at build time)
        if let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           !url.isEmpty,
           url != "$(SUPABASE_URL)" {
            return url
        }

        // Fallback to environment variable (for development)
        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           !url.isEmpty {
            return url
        }

        // Fallback to hardcoded production URL
        // This is safe as the URL is public and protected by RLS
        return "https://eoifovdmuuqdcospamru.supabase.co"
    }
    
    /**
     The Supabase Anonymous API Key.
     
     This is the public anon key for client-side access.
     It's safe to include in the app as it only provides access based on RLS policies.
     
     - Returns: The Supabase anon key as a `String`.
     */
    static var supabaseAnonKey: String {
        // Try to get from Info.plist first (injected at build time)
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !key.isEmpty,
           key != "$(SUPABASE_ANON_KEY)" {
            return key
        }

        // Fallback to environment variable (for development)
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
           !key.isEmpty {
            return key
        }

        // Fallback to hardcoded production anon key
        // Anon keys are safe for client apps - access is controlled by Row Level Security (RLS)
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvaWZvdmRtdXVxZGNvc3BhbXJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyOTI4NTAsImV4cCI6MjA3NTg2ODg1MH0.0aQ1JGJzAPqWanzYjR719mB9eKWNfhp3XD9ssQiZnOg"
    }
    
    /**
     The Supabase Service Role Key (optional - only for server-side operations).
     
     This key has elevated privileges and should NEVER be exposed in client code.
     Only use this in secure backend environments.
     
     - Returns: The Supabase service role key as a `String`, or empty if not configured.
     */
    static var supabaseServiceKey: String {
        // Try to get from Info.plist first (injected at build time)
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_SERVICE_KEY") as? String,
           !key.isEmpty,
           key != "$(SUPABASE_SERVICE_KEY)" {
            return key
        }
        
        // Fallback to environment variable (for development)
        if let key = ProcessInfo.processInfo.environment["SUPABASE_SERVICE_KEY"],
           !key.isEmpty {
            return key
        }
        
        return "" // Not configured - this is fine for client apps
    }
    
    // MARK: - Validation
    
    /**
     Validates that Supabase is properly configured.
     
     - Returns: `true` if configuration is valid, otherwise `false`.
     */
    static func validateConfiguration() -> Bool {
        let isValid = !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
        
        #if DEBUG
        print("🔧 Supabase Configuration Status:")
        print("   - URL: \(supabaseURL.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("   - Anon Key: \(supabaseAnonKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("   - Service Key: \(supabaseServiceKey.isEmpty ? "⚠️  Not configured (optional)" : "✅ Configured")")
        #endif
        
        return isValid
    }
}
