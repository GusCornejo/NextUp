import Foundation
import OSLog
import SwiftData

private let persistenceLogger = Logger(
    subsystem: "com.guscornejo.NextUp",
    category: "Persistence"
)

extension ModelContext {
    /// Saves changes, logging failures instead of swallowing them.
    /// - Returns: `nil` on success, or a short user-facing message on failure.
    @discardableResult
    func saveReportingFailure(
        operation: String = "save"
    ) -> String? {
        do {
            try save()
            return nil
        } catch {
            let detail = error.localizedDescription
            persistenceLogger.error(
                "SwiftData \(operation, privacy: .public) failed: \(detail, privacy: .public)"
            )
            return "Couldn't \(operation). \(detail)"
        }
    }
}
