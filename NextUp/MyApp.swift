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
                Next Up could not create its SwiftData store (CloudKit private DB).
                Confirm iCloud is signed in, CloudKit capability is enabled for this
                App ID, and the iCloud container matches the entitlements.
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

    /// Local SwiftData store mirrored to the user's private CloudKit database.
    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([BacklogItem.self])
        let configuration = ModelConfiguration(
            "NextUp",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
