import Foundation

/// Routes searches to the correct catalog implementation by `MediaCategory`.
public struct MediaSearchFacade: Sendable {
    private let services: [MediaSearchService]

    public init(services: [MediaSearchService]) {
        self.services = services
    }

    /// Convenience factory using live `URLSession` and the given API keys.
    /// MusicBrainz and Open Library need no keys.
    public init(tmdbAPIKey: String, rawgAPIKey: String, session: URLSession = .shared) {
        self.services = [
            TMDBSearchService(apiKey: tmdbAPIKey, session: session),
            MusicBrainzSearchService(session: session),
            RAWGSearchService(apiKey: rawgAPIKey, session: session),
            OpenLibrarySearchService(session: session),
        ]
    }

    public func search(
        query: String,
        category: MediaCategory
    ) async throws -> [MediaSearchResult] {
        guard let service = services.first(where: {
            $0.supportedCategories.contains(category)
        }) else {
            throw MediaSearchError.unsupportedCategory(category)
        }
        return try await service.search(query: query, category: category)
    }
}
