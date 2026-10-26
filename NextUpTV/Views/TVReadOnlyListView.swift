import SwiftUI
import SwiftData
import BacklogCore

/// Read-only backlog browser for Apple TV (no reorder / swipe / add).
struct TVReadOnlyListView: View {
    @Query(sort: [
        SortDescriptor(\BacklogItem.priority),
        SortDescriptor(\BacklogItem.createdAt),
    ])
    private var items: [BacklogItem]

    @State private var selectedCategory: MediaCategory?

    var body: some View {
        VStack(spacing: 0) {
            Text("List")
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 48)
                .padding(.top, 36)
                .padding(.bottom, 12)

            TVCategoryFilterBar(selected: $selectedCategory)

            List {
                section(title: "Up Next", rows: upNextItems, empty: "Nothing queued")
                section(
                    title: "Backlog",
                    rows: remainingBacklogItems,
                    empty: backlogItems.isEmpty ? "Empty" : "All caught up in Up Next"
                )
                section(title: "In Progress", rows: inProgressItems, empty: "None")
                section(title: "Done", rows: doneItems, empty: "None")
            }
            .listStyle(.plain)
        }
        .overlay {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No items",
                    systemImage: "tray",
                    description: Text(
                        "Local store is empty. Sample data seeds on first launch when CloudKit is off."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func section(
        title: String,
        rows: [BacklogItem],
        empty: String
    ) -> some View {
        Section(title) {
            if rows.isEmpty {
                Text(empty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows, id: \.id) { item in
                    TVBacklogRowView(item: item)
                        .focusable(true)
                }
            }
        }
    }

    private var filteredItems: [BacklogItem] {
        guard let selectedCategory else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    private var backlogItems: [BacklogItem] {
        BacklogOrdering.sortedBacklog(from: filteredItems)
    }

    private var upNextItems: [BacklogItem] {
        Array(backlogItems.prefix(BacklogOrdering.upNextCount))
    }

    private var remainingBacklogItems: [BacklogItem] {
        Array(backlogItems.dropFirst(BacklogOrdering.upNextCount))
    }

    private var inProgressItems: [BacklogItem] {
        filteredItems
            .filter { $0.status == .inProgress }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var doneItems: [BacklogItem] {
        filteredItems
            .filter { $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}
