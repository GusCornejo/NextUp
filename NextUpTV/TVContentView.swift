import SwiftUI
import SwiftData
import BacklogCore

struct TVContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [BacklogItem]

    var body: some View {
        TabView {
            Tab("Wheel", systemImage: "arrow.triangle.2.circlepath") {
                TVWheelView()
            }

            Tab("List", systemImage: "list.bullet") {
                TVReadOnlyListView()
            }
        }
        .task {
            seedSampleDataIfNeeded()
        }
    }

    /// Personal Team has no CloudKit sync, and TV has no Add UI — seed a small
    /// local sample backlog once so Wheel / List are exercisable offline.
    private func seedSampleDataIfNeeded() {
        guard items.isEmpty else { return }
        let samples: [(String, String, MediaCategory)] = [
            ("Arrival", "Denis Villeneuve", .movie),
            ("Hades", "Supergiant Games", .game),
            ("OK Computer", "Radiohead", .album),
            ("The Hobbit", "J. R. R. Tolkien", .book),
            ("Severance", "Apple TV+", .tv),
            ("Celeste", "Maddy Makes Games", .game),
            ("Dune", "Frank Herbert", .book),
            ("Spirited Away", "Studio Ghibli", .movie),
        ]
        let now = Date()
        for (index, sample) in samples.enumerated() {
            modelContext.insert(
                BacklogItem(
                    title: sample.0,
                    subtitle: sample.1,
                    category: sample.2,
                    status: .backlog,
                    priority: index,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        _ = modelContext.saveReportingFailure(operation: "seed sample backlog")
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: BacklogItem.self,
            configurations: configuration
        )
    } catch {
        preconditionFailure("Preview container failed: \(error)")
    }
    return TVContentView()
        .modelContainer(container)
}
