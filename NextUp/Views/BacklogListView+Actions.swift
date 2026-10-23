import SwiftUI
import SwiftData
import BacklogCore

extension BacklogListView {
    func markInProgressButton(for item: BacklogItem) -> some View {
        Button {
            setStatus(item, to: .inProgress)
        } label: {
            Label("In Progress", systemImage: "play.fill")
        }
        .tint(.orange)
    }

    func markDoneButton(for item: BacklogItem) -> some View {
        Button {
            setStatus(item, to: .done)
        } label: {
            Label("Done", systemImage: "checkmark")
        }
        .tint(.green)
    }

    func returnToBacklogButton(for item: BacklogItem) -> some View {
        Button {
            returnToBacklog(item)
        } label: {
            Label("Backlog", systemImage: "arrow.uturn.backward")
        }
        .tint(.blue)
    }

    func deleteButton(for item: BacklogItem) -> some View {
        Button(role: .destructive) {
            delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    func setStatus(_ item: BacklogItem, to status: ItemStatus) {
        item.status = status
        item.updatedAt = Date()
        BacklogOrdering.compactBacklogPriorities(among: Array(items))
        persist(operation: "update status")
    }

    func returnToBacklog(_ item: BacklogItem) {
        let others = items.filter { $0.id != item.id }
        item.status = .backlog
        item.priority = BacklogOrdering.nextBottomPriority(among: others)
        item.updatedAt = Date()
        BacklogOrdering.compactBacklogPriorities(among: Array(items))
        persist(operation: "return to backlog")
    }

    func delete(_ item: BacklogItem) {
        modelContext.delete(item)
        // Compact after delete using remaining items (query may lag one frame).
        let remaining = items.filter { $0.id != item.id }
        BacklogOrdering.compactBacklogPriorities(among: remaining)
        persist(operation: "delete item")
    }

    func moveUpNext(from source: IndexSet, to destination: Int) {
        let ordered = BacklogOrdering.moving(
            backlogItems,
            from: source,
            to: destination
        )
        BacklogOrdering.reassignPriorities(in: ordered)
        persist(operation: "reorder Up Next")
    }

    func moveRemainingBacklog(from source: IndexSet, to destination: Int) {
        let offset = upNextItems.count
        let globalSource = IndexSet(source.map { $0 + offset })
        let globalDestination = destination + offset
        let ordered = BacklogOrdering.moving(
            backlogItems,
            from: globalSource,
            to: globalDestination
        )
        BacklogOrdering.reassignPriorities(in: ordered)
        persist(operation: "reorder Backlog")
    }

    func persist(operation: String) {
        if let message = modelContext.saveReportingFailure(operation: operation) {
            saveErrorMessage = message
        }
    }
}
