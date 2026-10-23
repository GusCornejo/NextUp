import Testing
@testable import BacklogCore
import Foundation

@Suite("Media search parsers")
struct MediaSearchParserTests {
    private func utf8Data(_ string: String) throws -> Data {
        try #require(string.data(using: .utf8))
    }

    @Test("TMDB movie JSON maps title, year, cover, and external id")
    func tmdbMovieParse() throws {
        let json = try utf8Data("""
        {
          "results": [
            {
              "id": 329865,
              "title": "Arrival",
              "release_date": "2016-11-11",
              "poster_path": "/yDatJ40ZlqWFvUWNjYa440Qg2f.jpg"
            },
            {
              "id": 1,
              "title": "",
              "release_date": "2020-01-01"
            }
          ]
        }
        """)

        let results = try TMDBResponseParser.parse(data: json, category: .movie)
        #expect(results.count == 1)
        let arrival = try #require(results.first)
        #expect(arrival.title == "Arrival")
        #expect(arrival.year == 2016)
        #expect(arrival.externalID == "tmdb:movie:329865")
        let expectedCover =
            "https://image.tmdb.org/t/p/w500/yDatJ40ZlqWFvUWNjYa440Qg2f.jpg"
        #expect(arrival.coverURL == expectedCover)
        #expect(arrival.category == .movie)
    }

    @Test("TMDB TV JSON uses name and first_air_date")
    func tmdbTVParse() throws {
        let json = try utf8Data("""
        {
          "results": [
            {
              "id": 1396,
              "name": "Breaking Bad",
              "first_air_date": "2008-01-20",
              "poster_path": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg"
            }
          ]
        }
        """)

        let results = try TMDBResponseParser.parse(data: json, category: .tv)
        #expect(results.count == 1)
        #expect(results[0].title == "Breaking Bad")
        #expect(results[0].year == 2008)
        #expect(results[0].externalID == "tmdb:tv:1396")
    }

    @Test("MusicBrainz release-group JSON maps artist and cover URL")
    func musicBrainzParse() throws {
        let json = try utf8Data("""
        {
          "release-groups": [
            {
              "id": "b84ee12a-09ef-407b-b876-d1ea179a2f6a",
              "title": "OK Computer",
              "first-release-date": "1997-05-21",
              "artist-credit": [{ "name": "Radiohead" }]
            }
          ]
        }
        """)

        let results = try MusicBrainzResponseParser.parse(data: json)
        #expect(results.count == 1)
        #expect(results[0].title == "OK Computer")
        #expect(results[0].subtitle == "Radiohead")
        #expect(results[0].year == 1997)
        #expect(results[0].externalID.hasPrefix("musicbrainz:release-group:"))
        #expect(results[0].coverURL?.contains("coverartarchive.org") == true)
        #expect(results[0].category == .album)
    }

    @Test("RAWG games JSON maps platforms and cover")
    func rawgParse() throws {
        let json = try utf8Data("""
        {
          "results": [
            {
              "id": 3498,
              "name": "Grand Theft Auto V",
              "released": "2013-09-17",
              "background_image": "https://example.com/gta.jpg",
              "platforms": [
                { "platform": { "name": "PC" } },
                { "platform": { "name": "PlayStation 4" } }
              ]
            }
          ]
        }
        """)

        let results = try RAWGResponseParser.parse(data: json)
        #expect(results.count == 1)
        #expect(results[0].title == "Grand Theft Auto V")
        #expect(results[0].subtitle == "PC, PlayStation 4")
        #expect(results[0].year == 2013)
        #expect(results[0].externalID == "rawg:game:3498")
        #expect(results[0].coverURL == "https://example.com/gta.jpg")
    }

    @Test("Open Library JSON maps authors and cover id")
    func openLibraryParse() throws {
        let json = try utf8Data("""
        {
          "docs": [
            {
              "key": "/works/OL45883W",
              "title": "The Hobbit",
              "author_name": ["J.R.R. Tolkien"],
              "first_publish_year": 1937,
              "cover_i": 14625767
            }
          ]
        }
        """)

        let results = try OpenLibraryResponseParser.parse(data: json)
        #expect(results.count == 1)
        #expect(results[0].title == "The Hobbit")
        #expect(results[0].subtitle == "J.R.R. Tolkien")
        #expect(results[0].year == 1937)
        #expect(results[0].externalID == "openlibrary:/works/OL45883W")
        let expectedCover = "https://covers.openlibrary.org/b/id/14625767-M.jpg"
        #expect(results[0].coverURL == expectedCover)
        #expect(results[0].category == .book)
    }

    @Test("TMDB missing API key surfaces MediaSearchError")
    func tmdbMissingKey() async {
        let service = TMDBSearchService(apiKey: "  ")
        await #expect(throws: MediaSearchError.missingAPIKey("TMDB_API_KEY")) {
            try await service.search(query: "Arrival", category: .movie)
        }
    }

    @Test("Facade rejects empty query")
    func facadeEmptyQuery() async {
        let facade = MediaSearchFacade(tmdbAPIKey: "x", rawgAPIKey: "y")
        await #expect(throws: MediaSearchError.emptyQuery) {
            try await facade.search(query: "   ", category: .book)
        }
    }
}
