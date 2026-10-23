import Testing
@testable import BacklogCore
import Foundation
import SwiftData

@Suite("BacklogItem models")
struct ModelsTests {
    @Test("defaults satisfy CloudKit / SwiftData readiness")
    func defaultsAreCloudKitReady() {
        let item = BacklogItem()

        #expect(item.title == "")
        #expect(item.subtitle == "")
        #expect(item.coverURL == nil)
        #expect(item.externalID == nil)
        #expect(item.year == nil)
        #expect(item.category == .movie)
        #expect(item.status == .backlog)
        #expect(item.priority == 0)
        #expect(item.categoryRaw == MediaCategory.movie.rawValue)
        #expect(item.statusRaw == ItemStatus.backlog.rawValue)
    }

    @Test("MediaCategory and ItemStatus cover expected cases")
    func enumsCoverSpecCases() {
        #expect(MediaCategory.allCases == [.album, .game, .movie, .tv, .book])
        #expect(ItemStatus.allCases == [.backlog, .inProgress, .done])
        #expect(MediaCategory.movie.displayName == "Movies")
        #expect(ItemStatus.inProgress.displayName == "In Progress")
    }

    @Test("BacklogItem persists in an in-memory SwiftData store")
    func swiftDataRoundTrip() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BacklogItem.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        let original = BacklogItem(
            title: "Arrival",
            subtitle: "Denis Villeneuve",
            coverURL: "https://example.com/arrival.jpg",
            externalID: "tmdb:329865",
            year: 2016,
            category: .movie,
            status: .backlog,
            priority: 3
        )
        context.insert(original)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BacklogItem>())
        #expect(fetched.count == 1)
        let item = try #require(fetched.first)
        #expect(item.title == "Arrival")
        #expect(item.subtitle == "Denis Villeneuve")
        #expect(item.coverURL == "https://example.com/arrival.jpg")
        #expect(item.externalID == "tmdb:329865")
        #expect(item.year == 2016)
        #expect(item.category == .movie)
        #expect(item.status == .backlog)
        #expect(item.priority == 3)
    }
}
