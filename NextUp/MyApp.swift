import SwiftUI
import SwiftData
import OSLog
import BacklogCore

private let appLogger = Logger(
    subsystem: "devplaceholder.NextUp",
    category: "App"
)

@main
struct MyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try Self.makeModelContainer()
        } catch {
            appLogger.critical(
                "ModelContainer setup failed: \(error.localizedDescription, privacy: .public)"
            )
            preconditionFailure(
                """
                Next Up could not create its local SwiftData store.
                Check disk space and app sandbox file access, then relaunch.
                Underlying error: \(error)
                """
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([BacklogItem.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
