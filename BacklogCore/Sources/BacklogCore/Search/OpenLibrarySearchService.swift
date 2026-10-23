import Foundation

/// Open Library book search (no API key).
public struct OpenLibrarySearchService: MediaSearchService {
    public let supportedCategories: Set<MediaCategory> = [.book]

    private let session: URLSession
    private let coverBaseURL: String

    public init(
        session: URLSession = .shared,
        coverBaseURL: String = "https://covers.openlibrary.org/b/id"
    ) {
        self.session = session
        self.coverBaseURL = coverBaseURL
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

        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: "20"),
        ]
        guard let url = components?.url else { throw MediaSearchError.invalidURL }

        let data = try await SearchHTTP.data(
            for: SearchHTTP.get(url),
            session: session
        )
        return try OpenLibraryResponseParser.parse(
            data: data,
            coverBaseURL: coverBaseURL
        )
    }
}

/// Pure JSON → `MediaSearchResult` mapping for Open Library.
public enum OpenLibraryResponseParser {
    public static func parse(
        data: Data,
        coverBaseURL: String = "https://covers.openlibrary.org/b/id"
    ) throws -> [MediaSearchResult] {
        let decoded: OpenLibraryEnvelope
        do {
            decoded = try JSONDecoder().decode(OpenLibraryEnvelope.self, from: data)
        } catch {
            throw MediaSearchError.decodingFailed
        }

        return decoded.docs.compactMap { doc in
            guard let title = doc.title, !title.isEmpty else { return nil }
            let key = doc.key ?? doc.coverEditionKey ?? title
            let authors = doc.authorName?.prefix(2).joined(separator: ", ") ?? ""
            let cover: String?
            if let coverID = doc.coverI {
                cover = "\(coverBaseURL)/\(coverID)-M.jpg"
            } else {
                cover = nil
            }
            return MediaSearchResult(
                title: title,
                subtitle: authors,
                coverURL: cover,
                externalID: "openlibrary:\(key)",
                year: doc.firstPublishYear,
                category: .book
            )
        }
    }
}

struct OpenLibraryEnvelope: Decodable {
    let docs: [OpenLibraryDoc]
}

struct OpenLibraryDoc: Decodable {
    let key: String?
    let title: String?
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverI: Int?
    let coverEditionKey: String?

    enum CodingKeys: String, CodingKey {
        case key, title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverI = "cover_i"
        case coverEditionKey = "cover_edition_key"
    }
}
