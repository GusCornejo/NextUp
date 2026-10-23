import Foundation
import SwiftData

/// Media type for a backlog entry. Raw `String` values are CloudKit / SwiftData friendly.
public enum MediaCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case album
    case game
    case movie
    case tv
    case book

    /// Plural label for filter chips (e.g. "Movies").
    public var displayName: String {
        switch self {
        case .album: "Albums"
        case .game: "Games"
        case .movie: "Movies"
        case .tv: "TV"
        case .book: "Books"
        }
    }

    /// Singular label for rows and the add form (e.g. "Movie").
    public var singularName: String {
        switch self {
        case .album: "Album"
        case .game: "Game"
        case .movie: "Movie"
        case .tv: "TV show"
        case .book: "Book"
        }
    }
}

/// Lifecycle status for a backlog entry.
public enum ItemStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case backlog
    case inProgress
    case done

    /// Human-readable section title for this status.
    public var displayName: String {
        switch self {
        case .backlog: "Backlog"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }
}

/// A single media item in the prioritized backlog.
///
/// SwiftData `@Model` shaped for CloudKit private DB later:
/// every stored property has a default or is optional, and nothing uses
/// `@Attribute(.unique)`. Category/status are stored as raw strings for
/// CloudKit compatibility; use `category` / `status` computed accessors.
@Model
public final class BacklogItem {
    public var id: UUID = UUID()
    public var title: String = ""
    public var subtitle: String = ""
    /// Remote cover art URL as a string (optional for CloudKit).
    public var coverURL: String?
    /// ID from the upstream catalog (MusicBrainz, TMDB, RAWG, Open Library).
    public var externalID: String?
    public var year: Int?
    /// Persisted `MediaCategory.rawValue` for CloudKit-friendly storage.
    public var categoryRaw: String = MediaCategory.movie.rawValue
    /// Persisted `ItemStatus.rawValue` for CloudKit-friendly storage.
    public var statusRaw: String = ItemStatus.backlog.rawValue
    /// Lower value = higher on the list (0 = top).
    public var priority: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    /// Typed category; backed by `categoryRaw`.
    public var category: MediaCategory {
        get { MediaCategory(rawValue: categoryRaw) ?? .movie }
        set { categoryRaw = newValue.rawValue }
    }

    /// Typed status; backed by `statusRaw`.
    public var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .backlog }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        title: String = "",
        subtitle: String = "",
        coverURL: String? = nil,
        externalID: String? = nil,
        year: Int? = nil,
        category: MediaCategory = .movie,
        status: ItemStatus = .backlog,
        priority: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coverURL = coverURL
        self.externalID = externalID
        self.year = year
        self.categoryRaw = category.rawValue
        self.statusRaw = status.rawValue
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
