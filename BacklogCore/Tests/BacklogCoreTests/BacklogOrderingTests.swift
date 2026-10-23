import Testing
@testable import BacklogCore
import Foundation

@Suite("BacklogOrdering")
struct BacklogOrderingTests {
    private func item(
        title: String,
        priority: Int,
        status: ItemStatus = .backlog
    ) -> BacklogItem {
        BacklogItem(title: title, status: status, priority: priority)
    }

    @Test("sortedBacklog keeps only backlog and orders by priority")
    func sortedBacklogFiltersAndSorts() {
        let items = [
            item(title: "C", priority: 2),
            item(title: "Done", priority: 0, status: .done),
            item(title: "A", priority: 0),
            item(title: "B", priority: 1),
            item(title: "Playing", priority: 0, status: .inProgress),
        ]

        let sorted = BacklogOrdering.sortedBacklog(from: items)
        #expect(sorted.map(\.title) == ["A", "B", "C"])
    }

    @Test("reassignPriorities writes contiguous ranks from zero")
    func reassignPriorities() {
        let items = [
            item(title: "Second", priority: 99),
            item(title: "First", priority: 50),
            item(title: "Third", priority: 7),
        ]

        BacklogOrdering.reassignPriorities(in: items)
        #expect(items.map(\.priority) == [0, 1, 2])
    }

    @Test("nextBottomPriority is the backlog count")
    func nextBottomPriority() {
        let items = [
            item(title: "A", priority: 0),
            item(title: "B", priority: 1),
            item(title: "Done", priority: 0, status: .done),
        ]
        #expect(BacklogOrdering.nextBottomPriority(among: items) == 2)
    }

    @Test("moveBacklog rewrites priorities after drag")
    func moveBacklogRewritesPriorities() {
        let items = [
            item(title: "A", priority: 0),
            item(title: "B", priority: 1),
            item(title: "C", priority: 2),
        ]

        BacklogOrdering.moveBacklog(items, from: IndexSet(integer: 2), to: 0)
        let sorted = BacklogOrdering.sortedBacklog(from: items)
        #expect(sorted.map(\.title) == ["C", "A", "B"])
        #expect(sorted.map(\.priority) == [0, 1, 2])
    }

    @Test("compactBacklogPriorities after status leave")
    func compactAfterStatusChange() {
        let a = item(title: "A", priority: 0)
        let b = item(title: "B", priority: 1)
        let c = item(title: "C", priority: 2)
        b.status = .inProgress

        BacklogOrdering.compactBacklogPriorities(among: [a, b, c])
        #expect(a.priority == 0)
        #expect(c.priority == 1)
    }
}
