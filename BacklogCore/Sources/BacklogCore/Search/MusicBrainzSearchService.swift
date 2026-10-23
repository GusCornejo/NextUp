import Foundation

/// MusicBrainz release-group search with Cover Art Archive front cover URLs.
public struct MusicBrainzSearchService: MediaSearchService {
    public let supportedCategories: Set<MediaCategory> = [.album]

    private let session: URLSession
    private let coverArtBaseURL: String

    public init(
        session: URLSession = .shared,
        coverArtBaseURL: String = "https://coverartarchive.org/release-group"
    ) {
        self.session = session
        self.coverArtBaseURL = coverArtBaseURL
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

        var components = URLComponents(
            string: "https://musicbrainz.org/ws/2/release-group/"
        )
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "20"),
        ]
        guard let url = components?.url else { throw MediaSearchError.invalidURL }

        let data = try await SearchHTTP.data(
            for: SearchHTTP.get(url),
            session: session
        )
        return try MusicBrainzResponseParser.parse(
            data: data,
            coverArtBaseURL: coverArtBaseURL
        )
    }
}

/// Pure JSON → `MediaSearchResult` mapping for MusicBrainz.
public enum MusicBrainzResponseParser {
    public static func parse(
        data: Data,
        coverArtBaseURL: String = "https://coverartarchive.org/release-group"
    ) throws -> [MediaSearchResult] {
        let decoded: MusicBrainzEnvelope
        do {
            decoded = try JSONDecoder().decode(MusicBrainzEnvelope.self, from: data)
        } catch {
            throw MediaSearchError.decodingFailed
        }

        return decoded.releaseGroups.compactMap { group in
            guard let id = group.id, let title = group.title, !title.isEmpty else {
                return nil
            }
            let artist = group.artistCredit?
                .compactMap(\.name)
                .joined(separator: ", ") ?? ""
            let year = SearchHTTP.year(from: group.firstReleaseDate)
            return MediaSearchResult(
                title: title,
                subtitle: artist,
                coverURL: "\(coverArtBaseURL)/\(id)/front-250",
                externalID: "musicbrainz:release-group:\(id)",
                year: year,
                category: .album
            )
        }
    }
}

struct MusicBrainzEnvelope: Decodable {
    let releaseGroups: [MusicBrainzReleaseGroup]

    enum CodingKeys: String, CodingKey {
        case releaseGroups = "release-groups"
    }
}

struct MusicBrainzReleaseGroup: Decodable {
    let id: String?
    let title: String?
    let firstReleaseDate: String?
    let artistCredit: [MusicBrainzArtistCredit]?

    enum CodingKeys: String, CodingKey {
        case id, title
        case firstReleaseDate = "first-release-date"
        case artistCredit = "artist-credit"
    }
}

struct MusicBrainzArtistCredit: Decodable {
    let name: String?
}
