import Foundation

/// RAWG video game search.
public struct RAWGSearchService: MediaSearchService {
    public let supportedCategories: Set<MediaCategory> = [.game]

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func search(
        query: String,
        category: MediaCategory
    ) async throws -> [MediaSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MediaSearchError.emptyQuery }
        guard supportedCategories.contains(category) else {
            throw MediaSearchError.unsupportedCategory(category)
        }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MediaSearchError.missingAPIKey("RAWG_API_KEY")
        }

        var components = URLComponents(string: "https://api.rawg.io/api/games")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "search", value: trimmed),
            URLQueryItem(name: "page_size", value: "20"),
        ]
        guard let url = components?.url else { throw MediaSearchError.invalidURL }

        let data = try await SearchHTTP.data(
            for: SearchHTTP.get(url),
            session: session
        )
        return try RAWGResponseParser.parse(data: data)
    }
}

/// Pure JSON → `MediaSearchResult` mapping for RAWG.
public enum RAWGResponseParser {
    public static func parse(data: Data) throws -> [MediaSearchResult] {
        let decoded: RAWGEnvelope
        do {
            decoded = try JSONDecoder().decode(RAWGEnvelope.self, from: data)
        } catch {
            throw MediaSearchError.decodingFailed
        }

        return decoded.results.compactMap { game in
            guard let id = game.id, let name = game.name, !name.isEmpty else {
                return nil
            }
            return MediaSearchResult(
                title: name,
                subtitle: game.platforms?
                    .compactMap { $0.platform?.name }
                    .prefix(3)
                    .joined(separator: ", ") ?? "",
                coverURL: game.backgroundImage,
                externalID: "rawg:game:\(id)",
                year: SearchHTTP.year(from: game.released),
                category: .game
            )
        }
    }
}

struct RAWGEnvelope: Decodable {
    let results: [RAWGGame]
}

struct RAWGGame: Decodable {
    let id: Int?
    let name: String?
    let released: String?
    let backgroundImage: String?
    let platforms: [RAWGPlatformWrap]?

    enum CodingKeys: String, CodingKey {
        case id, name, released, platforms
        case backgroundImage = "background_image"
    }
}

struct RAWGPlatformWrap: Decodable {
    let platform: RAWGPlatformName?
}

struct RAWGPlatformName: Decodable {
    let name: String?
}
