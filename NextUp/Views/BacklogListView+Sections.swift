import SwiftUI
import BacklogCore

extension BacklogListView {
    var filteredItems: [BacklogItem] {
        guard let selectedCategory else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    var backlogItems: [BacklogItem] {
        BacklogOrdering.sortedBacklog(from: filteredItems)
    }

    var upNextItems: [BacklogItem] {
        Array(backlogItems.prefix(BacklogOrdering.upNextCount))
    }

    var remainingBacklogItems: [BacklogItem] {
        Array(backlogItems.dropFirst(BacklogOrdering.upNextCount))
    }

    var inProgressItems: [BacklogItem] {
        filteredItems
            .filter { $0.status == .inProgress }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var doneItems: [BacklogItem] {
        filteredItems
            .filter { $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @ViewBuilder
    var upNextSection: some View {
        Section("Up Next") {
            if upNextItems.isEmpty {
                Text("Nothing queued")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upNextItems, id: \.id) { item in
                    backlogRow(item, leading: .backlogStatus)
                }
                .onMove(perform: moveUpNext)
                .moveDisabled(isFilteringByCategory)
            }
        }
    }

    @ViewBuilder
    var backlogSection: some View {
        Section("Backlog") {
            if remainingBacklogItems.isEmpty {
                Text(backlogItems.isEmpty ? "Empty" : "All caught up in Up Next")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(remainingBacklogItems, id: \.id) { item in
                    backlogRow(item, leading: .backlogStatus)
                }
                .onMove(perform: moveRemainingBacklog)
                .moveDisabled(isFilteringByCategory)
            }
        }
    }

    @ViewBuilder
    var inProgressSection: some View {
        Section("In Progress") {
            if inProgressItems.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(inProgressItems, id: \.id) { item in
                    backlogRow(item, leading: .inProgressStatus)
                }
            }
        }
    }

    @ViewBuilder
    var doneSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isDoneExpanded) {
                if doneItems.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(doneItems, id: \.id) { item in
                        backlogRow(item, leading: .doneStatus)
                    }
                }
            } label: {
                Text("Done (\(doneItems.count))")
            }
        }
    }

    private enum LeadingSwipe {
        case backlogStatus
        case inProgressStatus
        case doneStatus
    }

    @ViewBuilder
    private func backlogRow(
        _ item: BacklogItem,
        leading: LeadingSwipe
    ) -> some View {
        BacklogRowView(item: item)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteButton(for: item)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                switch leading {
                case .backlogStatus:
                    markInProgressButton(for: item)
                    markDoneButton(for: item)
                case .inProgressStatus:
                    markDoneButton(for: item)
                    returnToBacklogButton(for: item)
                case .doneStatus:
                    returnToBacklogButton(for: item)
                }
            }
    }
}
