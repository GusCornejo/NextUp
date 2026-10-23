import Foundation

/// Helpers for maintaining contiguous backlog priorities (0 = top).
public enum BacklogOrdering {
    public static let upNextCount = 5

    /// Backlog-status items sorted by priority ascending (stable by id).
    public static func sortedBacklog(from items: [BacklogItem]) -> [BacklogItem] {
        items
            .filter { $0.status == .backlog }
            .sorted(by: prioritySort)
    }

    /// Ascending priority, then stable `id` tie-break (lower priority number = higher on list).
    public static func prioritySort(_ lhs: BacklogItem, _ rhs: BacklogItem) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Rewrites `priority` to `0..<count` in the given order and bumps `updatedAt`.
    public static func reassignPriorities(in order: [BacklogItem], now: Date = Date()) {
        for (index, item) in order.enumerated() {
            item.priority = index
            item.updatedAt = now
        }
    }

    /// Priority for a new backlog item inserted at the bottom.
    public static func nextBottomPriority(among items: [BacklogItem]) -> Int {
        sortedBacklog(from: items).count
    }

    /// Applies a drag-reorder within the full backlog list, then reassigns priorities.
    public static func moveBacklog(
        _ items: [BacklogItem],
        from source: IndexSet,
        to destination: Int,
        now: Date = Date()
    ) {
        var ordered = sortedBacklog(from: items)
        ordered = moving(ordered, from: source, to: destination)
        reassignPriorities(in: ordered, now: now)
    }

    /// `RangeReplaceableCollection.move(fromOffsets:toOffset:)` without importing SwiftUI.
    public static func moving<Element>(
        _ items: [Element],
        from source: IndexSet,
        to destination: Int
    ) -> [Element] {
        var result = items
        let moving = source.sorted().map { result[$0] }
        for index in source.sorted(by: >) {
            result.remove(at: index)
        }
        let adjustedDestination: Int = {
            let removedBefore = source.filter { $0 < destination }.count
            return max(0, min(destination - removedBefore, result.count))
        }()
        result.insert(contentsOf: moving, at: adjustedDestination)
        return result
    }

    /// After removing an item from the backlog (status change or delete), compact priorities.
    public static func compactBacklogPriorities(among items: [BacklogItem], now: Date = Date()) {
        reassignPriorities(in: sortedBacklog(from: items), now: now)
    }
}
