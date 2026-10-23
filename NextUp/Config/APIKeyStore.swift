import Foundation

/// Reads catalog API keys from the app Info.plist (injected via xcconfig).
enum APIKeyStore {
    static var tmdbAPIKey: String {
        string(for: "TMDB_API_KEY")
    }

    static var rawgAPIKey: String {
        string(for: "RAWG_API_KEY")
    }

    static var hasTMDBKey: Bool { !tmdbAPIKey.isEmpty }
    static var hasRAWGKey: Bool { !rawgAPIKey.isEmpty }

    private static func string(for key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Unexpanded $(TMDB_API_KEY) placeholders count as missing.
        if trimmed.hasPrefix("$(") { return "" }
        return trimmed
    }
}
