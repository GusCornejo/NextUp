import SwiftUI
import SwiftData
import OSLog
import BacklogCore

private let appLogger = Logger(
    subsystem: "com.guscornejo.NextUpTV",
    category: "App"
)

@main
struct NextUpTVApp: App {
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
                Next Up TV could not create its local SwiftData store.
                Underlying error: \(error)
                """
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            TVContentView()
        }
        .modelContainer(container)
    }

    /// Local-only SwiftData store (Personal Team cannot use CloudKit).
    ///
    /// True iPhone ↔ Apple TV sync needs a **paid** Apple Developer team plus
    /// iCloud CloudKit entitlements and `cloudKitDatabase: .automatic` on both
    /// apps (same container / iCloud account). Do not re-enable iCloud/Push on
    /// Personal Team — signing will fail.
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
