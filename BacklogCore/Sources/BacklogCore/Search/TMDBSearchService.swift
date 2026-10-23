import Foundation

/// The Movie Database search for movies and TV shows.
public struct TMDBSearchService: MediaSearchService {
    public let supportedCategories: Set<MediaCategory> = [.movie, .tv]

    private let apiKey: String
    private let session: URLSession
    private let imageBaseURL: String

    public init(
        apiKey: String,
        session: URLSession = .shared,
        imageBaseURL: String = "https://image.tmdb.org/t/p/w500"
    ) {
        self.apiKey = apiKey
        self.session = session
        self.imageBaseURL = imageBaseURL
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
            throw MediaSearchError.missingAPIKey("TMDB_API_KEY")
        }

        let path = category == .movie ? "search/movie" : "search/tv"
        var components = URLComponents(string: "https://api.themoviedb.org/3/\(path)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "include_adult", value: "false"),
        ]
        guard let url = components?.url else { throw MediaSearchError.invalidURL }

        let data = try await SearchHTTP.data(
            for: SearchHTTP.get(url),
            session: session
        )
        return try TMDBResponseParser.parse(
            data: data,
            category: category,
            imageBaseURL: imageBaseURL
        )
    }
}

/// Pure JSON → `MediaSearchResult` mapping for TMDB (unit-testable).
public enum TMDBResponseParser {
    public static func parse(
        data: Data,
        category: MediaCategory,
        imageBaseURL: String = "https://image.tmdb.org/t/p/w500"
    ) throws -> [MediaSearchResult] {
        let decoded: TMDBSearchEnvelope
        do {
            decoded = try JSONDecoder().decode(TMDBSearchEnvelope.self, from: data)
        } catch {
            throw MediaSearchError.decodingFailed
        }

        return decoded.results.compactMap { item in
            let title: String
            let date: String?
            switch category {
            case .movie:
                title = item.title ?? item.name ?? ""
                date = item.releaseDate
            case .tv:
                title = item.name ?? item.title ?? ""
                date = item.firstAirDate
            default:
                return nil
            }
            guard !title.isEmpty, let id = item.id else { return nil }

            let cover: String?
            if let path = item.posterPath, !path.isEmpty {
                cover = imageBaseURL + path
            } else {
                cover = nil
            }

            let prefix = category == .movie ? "tmdb:movie:" : "tmdb:tv:"
            return MediaSearchResult(
                title: title,
                subtitle: "",
                coverURL: cover,
                externalID: "\(prefix)\(id)",
                year: SearchHTTP.year(from: date),
                category: category
            )
        }
    }
}

struct TMDBSearchEnvelope: Decodable {
    let results: [TMDBResult]
}

struct TMDBResult: Decodable {
    let id: Int?
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
    }
}
