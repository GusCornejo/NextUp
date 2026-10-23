import Testing
@testable import BacklogCore
import Foundation

@Suite("WheelPicker")
struct WheelPickerTests {
    private func item(
        title: String,
        priority: Int,
        status: ItemStatus = .backlog,
        category: MediaCategory = .movie,
        id: UUID = UUID()
    ) -> BacklogItem {
        BacklogItem(
            id: id,
            title: title,
            category: category,
            status: status,
            priority: priority
        )
    }

    @Test("pool includes only backlog status")
    func poolExcludesNonBacklog() {
        let items = [
            item(title: "A", priority: 0, status: .backlog),
            item(title: "B", priority: 1, status: .inProgress),
            item(title: "C", priority: 2, status: .done),
            item(title: "D", priority: 3, status: .backlog),
        ]

        let pool = WheelPicker.pool(from: items)
        #expect(pool.map(\.title) == ["A", "D"])
        #expect(pool.allSatisfy { $0.status == .backlog })
    }

    @Test("pool respects optional category filter")
    func poolFiltersCategory() {
        let items = [
            item(title: "Movie", priority: 0, category: .movie),
            item(title: "Album", priority: 1, category: .album),
            item(title: "Game", priority: 2, category: .game),
        ]

        let movies = WheelPicker.pool(from: items, category: .movie)
        #expect(movies.map(\.title) == ["Movie"])
    }

    @Test("pick never returns done or inProgress")
    func pickNeverReturnsNonBacklog() {
        let items = [
            item(title: "Backlog", priority: 0, status: .backlog),
            item(title: "Playing", priority: 0, status: .inProgress),
            item(title: "Finished", priority: 0, status: .done),
        ]

        var generator = SeededGenerator(seed: 42)
        for _ in 0..<500 {
            let picked = WheelPicker.pick(from: items, mode: .uniform, using: &generator)
            #expect(picked?.title == "Backlog")
            #expect(picked?.status == .backlog)
        }

        for mode: WheelMode in [.weighted, .topN] {
            var modeGenerator = SeededGenerator(seed: 7)
            for _ in 0..<200 {
                let picked = WheelPicker.pick(from: items, mode: mode, using: &modeGenerator)
                #expect(picked?.status == .backlog)
                #expect(picked?.status != .done)
                #expect(picked?.status != .inProgress)
            }
        }
    }

    @Test("pick returns nil when no backlog items exist")
    func pickNilWhenEmpty() {
        let items = [
            item(title: "Playing", priority: 0, status: .inProgress),
            item(title: "Finished", priority: 1, status: .done),
        ]
        #expect(WheelPicker.pick(from: items) == nil)
    }

    @Test("uniform slices cap at 12")
    func uniformSlicesCapAtTwelve() {
        let items = (0..<30).map { index in
            item(title: "Item \(index)", priority: index)
        }

        var generator = SeededGenerator(seed: 99)
        let slices = WheelPicker.slices(
            from: items,
            mode: .uniform,
            using: &generator
        )
        #expect(slices.count == WheelPicker.maxSlices)
        #expect(slices.allSatisfy { $0.status == .backlog })
    }

    @Test("top N keeps only the highest-priority items")
    func topNRestrictsPool() {
        let items = (0..<20).map { index in
            item(title: "P\(index)", priority: index)
        }

        var generator = SeededGenerator(seed: 1)
        let slices = WheelPicker.slices(
            from: items,
            mode: .topN(10),
            using: &generator
        )
        #expect(slices.count == 10)
        #expect(slices.map(\.priority) == Array(0..<10))
    }

    @Test("top N above 12 still shows at most 12 slices")
    func topNCapsAtTwelveSlices() {
        let items = (0..<30).map { index in
            item(title: "P\(index)", priority: index)
        }

        var generator = SeededGenerator(seed: 2)
        let slices = WheelPicker.slices(
            from: items,
            mode: .topN(20),
            using: &generator
        )
        #expect(slices.count == 12)
        #expect(slices.map(\.priority) == Array(0..<12))
    }

    @Test("weighted mode picks priority 0 more often than priority 9 over 10k spins")
    func weightedFavorsHigherPriority() {
        let ids = (0..<10).map { _ in UUID() }
        let items = (0..<10).map { index in
            item(
                title: "Item \(index + 1)",
                priority: index,
                id: ids[index]
            )
        }

        var counts: [UUID: Int] = Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
        var generator = SystemRandomNumberGenerator()
        let spins = 10_000

        for _ in 0..<spins {
            let picked = WheelPicker.pick(from: items, mode: .weighted, using: &generator)
            #expect(picked != nil)
            #expect(picked?.status == .backlog)
            if let id = picked?.id {
                counts[id, default: 0] += 1
            }
        }

        let topCount = counts[ids[0], default: 0]
        let bottomCount = counts[ids[9], default: 0]

        // Priority 0 weight = 1.0, priority 9 weight = 0.1 → expect roughly 10×.
        // Require a clear, measurable gap without being brittle.
        #expect(topCount > bottomCount)
        #expect(topCount > bottomCount * 3)
        #expect(topCount > spins / 20)
    }

    @Test("weight decreases as priority number increases")
    func weightOrdering() {
        #expect(WheelPicker.weight(forPriority: 0) > WheelPicker.weight(forPriority: 1))
        #expect(WheelPicker.weight(forPriority: 1) > WheelPicker.weight(forPriority: 9))
        #expect(WheelPicker.weight(forPriority: 0) == 1.0)
        #expect(WheelPicker.weight(forPriority: 9) == 0.1)
    }

    @Test("spin returns winner that is one of the slices and backlog-only")
    func spinReturnsConsistentWinner() throws {
        let items = (0..<15).map { index in
            item(title: "Item \(index)", priority: index)
        } + [
            item(title: "Playing", priority: 0, status: .inProgress),
            item(title: "Finished", priority: 1, status: .done),
        ]

        var generator = SeededGenerator(seed: 123)
        let result = WheelPicker.spin(
            from: items,
            mode: .weighted,
            using: &generator
        )
        let spin = try #require(result)
        #expect(spin.slices.count <= WheelPicker.maxSlices)
        #expect(spin.slices.contains(where: { $0.id == spin.winner.id }))
        #expect(spin.winner.status == .backlog)
        #expect(spin.slices.allSatisfy { $0.status == .backlog })
    }

    @Test("sliceWeights are equal for uniform and larger for higher priority when weighted")
    func sliceWeightsMatchMode() {
        let items = [
            item(title: "A", priority: 0),
            item(title: "B", priority: 9),
        ]
        let uniform = WheelPicker.sliceWeights(for: items, mode: .uniform)
        #expect(uniform == [1.0, 1.0])

        let weighted = WheelPicker.sliceWeights(for: items, mode: .weighted)
        #expect(weighted[0] > weighted[1])
    }
}

/// Deterministic RNG for reproducible unit tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545_F491_4F6C_DD1D
    }
}
