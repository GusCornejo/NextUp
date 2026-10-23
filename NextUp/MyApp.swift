import SwiftUI
import SwiftData
import OSLog
import BacklogCore

private let appLogger = Logger(
    subsystem: "com.guscornejo.NextUp",
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

    /// Local-only SwiftData store (Personal Team cannot use CloudKit).
    ///
    /// When on a **paid** Apple Developer Program team, re-enable sync by:
    /// 1. Adding iCloud (CloudKit) + Push / remote-notification capabilities
    ///    (container `iCloud.com.guscornejo.NextUp`).
    /// 2. Changing `cloudKitDatabase:` below from `.none` to `.automatic`.
    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([BacklogItem.self])
        let configuration = ModelConfiguration(
            "NextUp",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
