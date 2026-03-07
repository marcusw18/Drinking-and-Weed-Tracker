import Foundation

/// Fill in your API keys before running.
enum Config {
    // MARK: - Supabase
    /// Project URL from Supabase dashboard → Settings → API
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    /// anon/public key (safe for client use with RLS enabled)
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    // MARK: - Gemini
    /// Get from https://aistudio.google.com/app/apikey
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"

    // MARK: - Vulture ML Server
    /// Local dev: "http://localhost:8000" | Deployed: your server URL
    static let vultureServerURL = "http://localhost:8000"

    // MARK: - App Group
    /// Must match entitlements on both iPhone and Watch targets
    static let appGroupID = "group.com.drinkingtracker"
}
