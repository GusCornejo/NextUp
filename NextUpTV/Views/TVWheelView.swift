import SwiftUI
import SwiftData
import BacklogCore

/// Living-room wheel: focusable category chips + one primary Spin button.
struct TVWheelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\BacklogItem.priority),
        SortDescriptor(\BacklogItem.createdAt),
    ])
    private var items: [BacklogItem]

    @State private var selectedCategory: MediaCategory?
    @State private var modeSelection: ModeOption = .uniform
    @State private var displaySlices: [BacklogItem] = []
    @State private var sliceWeights: [Double] = []
    @State private var rotationDegrees: Double = 0
    @State private var isSpinning = false
    @State private var pendingWinner: BacklogItem?
    @State private var resultItem: BacklogItem?
    @State private var showResult = false
    @State private var statusMessage: String?
    @State private var saveErrorMessage: String?
    @FocusState private var spinFocused: Bool

    private enum ModeOption: String, CaseIterable, Identifiable {
        case uniform
        case weighted
        case topN

        var id: String { rawValue }

        var title: String {
            switch self {
            case .uniform: "Uniform"
            case .weighted: "Weighted"
            case .topN: "Top 10"
            }
        }

        var wheelMode: WheelMode {
            switch self {
            case .uniform: .uniform
            case .weighted: .weighted
            case .topN: .topN(WheelMode.defaultTopN)
            }
        }
    }

    var body: some View {
        ZStack {
            mainContent

            if showResult, let resultItem {
                TVWheelResultView(
                    item: resultItem,
                    onStart: { startItem(resultItem) },
                    onSpinAgain: {
                        showResult = false
                        self.resultItem = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            spin()
                        }
                    },
                    onDismiss: {
                        showResult = false
                        self.resultItem = nil
                        refreshPreviewSlices()
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showResult)
        .onAppear {
            refreshPreviewSlices()
            spinFocused = true
        }
        .onChange(of: selectedCategory) { _, _ in refreshPreviewSlices() }
        .onChange(of: modeSelection) { _, _ in refreshPreviewSlices() }
        .alert("Couldn't Save", isPresented: saveErrorPresented) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 24) {
            Text("Wheel")
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 48)

            TVCategoryFilterBar(selected: $selectedCategory)

            modePicker
                .padding(.horizontal, 48)

            HStack(alignment: .center, spacing: 48) {
                wheelArea
                    .frame(maxWidth: 560)
                    .padding(.leading, 48)

                VStack(alignment: .leading, spacing: 20) {
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        spin()
                    } label: {
                        Label(
                            isSpinning ? "Spinning…" : "Spin",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .frame(minWidth: 260)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
                    .disabled(isSpinning || pool.isEmpty || showResult)
                    .focused($spinFocused)
                    .accessibilityIdentifier("nextuptv.wheel.spin")

                    Text("Select the Spin button on the remote to pick what’s next.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 360, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 36)
    }

    private var modePicker: some View {
        HStack(spacing: 16) {
            ForEach(ModeOption.allCases) { option in
                Button {
                    modeSelection = option
                } label: {
                    Text(option.title)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .tint(modeSelection == option ? Color.accentColor : Color.secondary)
                .disabled(isSpinning || showResult)
            }
        }
        .focusSection()
        .accessibilityIdentifier("nextuptv.wheel.mode")
    }

    private var wheelArea: some View {
        ZStack(alignment: .top) {
            if displaySlices.isEmpty {
                ContentUnavailableView(
                    pool.isEmpty ? "Nothing to spin" : "Ready to spin",
                    systemImage: "circle.dotted",
                    description: Text(
                        pool.isEmpty
                            ? "No backlog items match this filter."
                            : "Press Spin to load the wheel."
                    )
                )
            } else {
                TVSpinWheelGraphic(
                    slices: displaySlices,
                    weights: sliceWeights,
                    highlightedID: resultItem?.id ?? pendingWinner?.id
                )
                .rotationEffect(.degrees(rotationDegrees))
                .padding(.top, 36)

                TVWheelPointer()
                    .offset(y: -4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pool: [BacklogItem] {
        WheelPicker.pool(from: Array(items), category: selectedCategory)
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func refreshPreviewSlices() {
        guard !isSpinning else { return }
        let preview = WheelPicker.slices(
            from: Array(items),
            mode: modeSelection.wheelMode,
            category: selectedCategory
        )
        displaySlices = preview
        sliceWeights = WheelPicker.sliceWeights(
            for: preview,
            mode: modeSelection.wheelMode
        )
        pendingWinner = nil
        if pool.isEmpty {
            statusMessage = nil
        } else {
            let plural = preview.count == 1 ? "" : "s"
            statusMessage =
                "\(pool.count) in pool · \(preview.count) slice\(plural)"
        }
    }

    private func spin() {
        guard !isSpinning, !showResult else { return }
        guard let result = WheelPicker.spin(
            from: Array(items),
            mode: modeSelection.wheelMode,
            category: selectedCategory
        ) else {
            statusMessage = "Nothing to spin in this pool."
            return
        }

        isSpinning = true
        resultItem = nil
        displaySlices = result.slices
        sliceWeights = WheelPicker.sliceWeights(
            for: result.slices,
            mode: modeSelection.wheelMode
        )
        pendingWinner = result.winner
        statusMessage = nil

        let target = targetRotationDegrees(
            slices: result.slices,
            weights: sliceWeights,
            winnerID: result.winner.id
        )
        let landing = rotationDegrees.truncatingRemainder(dividingBy: 360)
        let normalizedLanding = landing < 0 ? landing + 360 : landing
        let delta = (target - normalizedLanding + 360)
            .truncatingRemainder(dividingBy: 360)
        let finalRotation = rotationDegrees + 360 * 5 + delta

        withAnimation(.easeOut(duration: 2.6)) {
            rotationDegrees = finalRotation
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2650))
            isSpinning = false
            resultItem = result.winner
            showResult = true
        }
    }

    private func targetRotationDegrees(
        slices: [BacklogItem],
        weights: [Double],
        winnerID: UUID
    ) -> Double {
        let total = max(weights.reduce(0, +), 0.0001)
        var startFraction = 0.0
        for (index, item) in slices.enumerated() {
            let fraction = (index < weights.count ? weights[index] : 1) / total
            if item.id == winnerID {
                let midFraction = startFraction + fraction / 2
                return -midFraction * 360
            }
            startFraction += fraction
        }
        return 0
    }

    private func startItem(_ item: BacklogItem) {
        item.status = .inProgress
        item.updatedAt = Date()
        BacklogOrdering.compactBacklogPriorities(among: Array(items))
        if let message = modelContext.saveReportingFailure(operation: "start from wheel") {
            saveErrorMessage = message
            return
        }
        showResult = false
        resultItem = nil
        refreshPreviewSlices()
    }
}
