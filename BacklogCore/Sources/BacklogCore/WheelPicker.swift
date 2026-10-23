import Foundation

/// How the wheel builds its eligible pool and assigns slice weight.
public enum WheelMode: Sendable, Equatable, Hashable {
    /// Every backlog item has equal weight.
    case uniform
    /// Higher list priority (lower `priority` value) gets a larger slice.
    case weighted
    /// Only the top `n` backlog items by priority (default 10).
    case topN(Int)

    public static let defaultTopN = 10

    public static var topN: WheelMode { .topN(defaultTopN) }

    /// Short label for mode pickers.
    public var displayName: String {
        switch self {
        case .uniform: "Uniform"
        case .weighted: "Weighted"
        case .topN(let n): "Top \(n)"
        }
    }
}

/// One spin: the slices drawn on the wheel and the chosen winner.
/// Not `Sendable` — `BacklogItem` is a SwiftData `@Model` reference type.
public struct WheelSpinResult {
    public var slices: [BacklogItem]
    public var winner: BacklogItem

    public init(slices: [BacklogItem], winner: BacklogItem) {
        self.slices = slices
        self.winner = winner
    }
}

/// Pure spin-wheel logic shared by iPhone and Apple TV.
public enum WheelPicker {
    /// Maximum slices drawn on the wheel UI.
    public static let maxSlices = 12

    /// Weight for weighted mode: priority 0 → 1.0, priority 9 → 0.1, etc.
    public static func weight(forPriority priority: Int) -> Double {
        1.0 / Double(max(priority, 0) + 1)
    }

    /// Items eligible for the wheel: `backlog` only, optional category filter.
    public static func pool(
        from items: [BacklogItem],
        category: MediaCategory? = nil
    ) -> [BacklogItem] {
        items.filter { item in
            item.status == .backlog
                && (category == nil || item.category == category)
        }
    }

    /// Up to `maxSlices` items that appear on the wheel for the given mode.
    public static func slices(
        from items: [BacklogItem],
        mode: WheelMode = .uniform,
        category: MediaCategory? = nil,
        maxSlices: Int = maxSlices,
        using generator: inout some RandomNumberGenerator
    ) -> [BacklogItem] {
        var candidates = pool(from: items, category: category)
        candidates.sort(by: BacklogOrdering.prioritySort)

        switch mode {
        case .topN(let n):
            let limit = max(0, n)
            candidates = Array(candidates.prefix(limit))
        case .uniform, .weighted:
            break
        }

        guard candidates.count > maxSlices else {
            return candidates
        }

        switch mode {
        case .uniform:
            return sampleUniform(from: candidates, count: maxSlices, using: &generator)
        case .weighted:
            return sampleWeighted(from: candidates, count: maxSlices, using: &generator)
        case .topN:
            // Already ordered by priority; keep the best `maxSlices`.
            return Array(candidates.prefix(maxSlices))
        }
    }

    /// Convenience overload using the system RNG.
    public static func slices(
        from items: [BacklogItem],
        mode: WheelMode = .uniform,
        category: MediaCategory? = nil,
        maxSlices: Int = maxSlices
    ) -> [BacklogItem] {
        var generator = SystemRandomNumberGenerator()
        return slices(
            from: items,
            mode: mode,
            category: category,
            maxSlices: maxSlices,
            using: &generator
        )
    }

    /// Picks one item from the wheel slices for the given mode.
    public static func pick(
        from items: [BacklogItem],
        mode: WheelMode = .uniform,
        category: MediaCategory? = nil,
        maxSlices: Int = maxSlices,
        using generator: inout some RandomNumberGenerator
    ) -> BacklogItem? {
        let wheel = slices(
            from: items,
            mode: mode,
            category: category,
            maxSlices: maxSlices,
            using: &generator
        )
        guard !wheel.isEmpty else { return nil }

        return pick(fromSlices: wheel, mode: mode, using: &generator)
    }

    /// Convenience overload using the system RNG.
    public static func pick(
        from items: [BacklogItem],
        mode: WheelMode = .uniform,
        category: MediaCategory? = nil,
        maxSlices: Int = maxSlices
    ) -> BacklogItem? {
        var generator = SystemRandomNumberGenerator()
        return pick(
            from: items,
            mode: mode,
            category: category,
            maxSlices: maxSlices,
            using: &generator
        )
    }

    /// Picks a winner from an already-built slice list (same mode rules).
    public static func pick(
        fromSlices slices: [BacklogItem],
        mode: WheelMode,
        using generator: inout some RandomNumberGenerator
    ) -> BacklogItem? {
        guard !slices.isEmpty else { return nil }
        switch mode {
        case .uniform, .topN:
            let index = Int.random(in: 0..<slices.count, using: &generator)
            return slices[index]
        case .weighted:
            return pickWeighted(from: slices, using: &generator)
        }
    }

    /// Builds slices and picks a winner with one RNG pass (UI-safe).
    public static func spin(
        from items: [BacklogItem],
        mode: WheelMode = .uniform,
        category: MediaCategory? = nil,
        maxSlices: Int = maxSlices,
        using generator: inout some RandomNumberGenerator
    ) -> WheelSpinResult? {
        let wheel = slices(
            from: items,
            mode: mode,
            category: category,
            maxSlices: maxSlices,
            using: &generator
        )
        guard let winner = pick(fromSlices: wheel, mode: mode, using: &generator) else {
            return nil
        }
        return WheelSpinResult(slices: wheel, winner: winner)
    }

    /// Convenience overload using the system RNG.
    public static func spin(
        from items: [BacklogItem],
        mode: WheelMode = .uniform,
        category: MediaCategory? = nil,
        maxSlices: Int = maxSlices
    ) -> WheelSpinResult? {
        var generator = SystemRandomNumberGenerator()
        return spin(
            from: items,
            mode: mode,
            category: category,
            maxSlices: maxSlices,
            using: &generator
        )
    }

    /// Relative visual weights for drawing slice arcs (weighted mode).
    public static func sliceWeights(
        for slices: [BacklogItem],
        mode: WheelMode
    ) -> [Double] {
        guard !slices.isEmpty else { return [] }
        switch mode {
        case .uniform, .topN:
            return Array(repeating: 1.0, count: slices.count)
        case .weighted:
            return slices.map { weight(forPriority: $0.priority) }
        }
    }
}

// MARK: - Sampling helpers

extension WheelPicker {
    static func sampleUniform(
        from items: [BacklogItem],
        count: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [BacklogItem] {
        guard count > 0, !items.isEmpty else { return [] }
        if items.count <= count { return items }

        var remaining = items
        var result: [BacklogItem] = []
        result.reserveCapacity(count)

        for _ in 0..<count {
            let index = Int.random(in: 0..<remaining.count, using: &generator)
            result.append(remaining.remove(at: index))
        }

        result.sort(by: BacklogOrdering.prioritySort)
        return result
    }

    /// Weighted sampling without replacement (Efraimidis–Spirakis keys).
    static func sampleWeighted(
        from items: [BacklogItem],
        count: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [BacklogItem] {
        guard count > 0, !items.isEmpty else { return [] }
        if items.count <= count { return items }

        let keyed: [(item: BacklogItem, key: Double)] = items.map { item in
            let w = weight(forPriority: item.priority)
            // key = U^(1/w); higher weight → larger keys on average
            let u = Double.random(in: Double.leastNonzeroMagnitude..<1.0, using: &generator)
            let key = w > 0 ? pow(u, 1.0 / w) : 0
            return (item, key)
        }

        return keyed
            .sorted { $0.key > $1.key }
            .prefix(count)
            .map(\.item)
            .sorted(by: BacklogOrdering.prioritySort)
    }

    static func pickWeighted(
        from items: [BacklogItem],
        using generator: inout some RandomNumberGenerator
    ) -> BacklogItem? {
        guard !items.isEmpty else { return nil }

        let sliceWeights = items.map { weight(forPriority: $0.priority) }
        let total = sliceWeights.reduce(0, +)
        guard total > 0 else {
            let index = Int.random(in: 0..<items.count, using: &generator)
            return items[index]
        }

        var threshold = Double.random(in: 0..<total, using: &generator)
        for (item, sliceWeight) in zip(items, sliceWeights) {
            threshold -= sliceWeight
            if threshold < 0 {
                return item
            }
        }
        return items.last
    }
}
