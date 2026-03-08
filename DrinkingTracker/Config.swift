import Foundation

/// API configuration. Keys come from Secrets.swift (gitignored).
/// To set up: fill in .env.local then run ./scripts/apply_env.sh
enum Config {
    static let supabaseURL          = Secrets.supabaseURL
    static let supabaseAnonKey      = Secrets.supabaseAnonKey
    static let geminiAPIKey         = Secrets.geminiAPIKey
    static let vultureServerURL     = Secrets.vultureServerURL
    static let smartSpectraAPIKey   = Secrets.smartSpectraAPIKey

    // App Group — must match entitlements on both iPhone and Watch targets
    static let appGroupID = "group.com.drinkingtracker"
}
