import Foundation

/// A catalog hit ready to save as a `BacklogItem`.
public struct MediaSearchResult: Equatable, Sendable, Identifiable {
    public var id: String { externalID }

    public var title: String
    public var subtitle: String
    public var coverURL: String?
    public var externalID: String
    public var year: Int?
    public var category: MediaCategory

    public init(
        title: String,
        subtitle: String = "",
        coverURL: String? = nil,
        externalID: String,
        year: Int? = nil,
        category: MediaCategory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.coverURL = coverURL
        self.externalID = externalID
        self.year = year
        self.category = category
    }
}

/// Errors from remote media catalog search.
public enum MediaSearchError: Error, Equatable, Sendable, LocalizedError {
    case emptyQuery
    case missingAPIKey(String)
    case unsupportedCategory(MediaCategory)
    case invalidURL
    case httpStatus(Int)
    case decodingFailed
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Enter a search query."
        case .missingAPIKey(let name):
            return "Missing \(name). Add it to Config/Secrets.xcconfig and rebuild."
        case .unsupportedCategory(let category):
            return "No search source for \(category.singularName)."
        case .invalidURL:
            return "Could not build the search request."
        case .httpStatus(let code):
            return "Search failed (HTTP \(code))."
        case .decodingFailed:
            return "Could not read search results."
        case .transport(let message):
            return "Network error: \(message)"
        }
    }
}

/// Searches one upstream catalog for a media category.
public protocol MediaSearchService: Sendable {
    /// Categories this implementation can search.
    var supportedCategories: Set<MediaCategory> { get }

    /// Searches the remote catalog. Implementations must not retain API keys in logs.
    func search(
        query: String,
        category: MediaCategory
    ) async throws -> [MediaSearchResult]
}

/// Builds a `URLRequest` for catalog HTTP calls (User-Agent, JSON accept, etc.).
enum SearchHTTP {
    static let userAgent = "NextUp/1.0 (https://github.com/guscornejo/nextup; media-backlog-app)"

    static func get(_ url: URL, extraHeaders: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    static func data(
        for request: URLRequest,
        session: URLSession
    ) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MediaSearchError.transport(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw MediaSearchError.httpStatus(http.statusCode)
        }
        return data
    }

    static func year(from dateString: String?) -> Int? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return Int(dateString.prefix(4))
    }
}
