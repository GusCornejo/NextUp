import SwiftUI
import SwiftData
import BacklogCore
#if canImport(UIKit)
import UIKit
#endif

struct WheelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\BacklogItem.priority),
        SortDescriptor(\BacklogItem.createdAt),
    ])
    private var items: [BacklogItem]

    @State private var selectedCategory: MediaCategory?
    @State private var modeSelection: ModeOption = .uniform
    @State private var topNCount: Int = WheelMode.defaultTopN

    @State private var displaySlices: [BacklogItem] = []
    @State private var sliceWeights: [Double] = []
    @State private var rotationDegrees: Double = 0
    @State private var isSpinning = false
    @State private var pendingWinner: BacklogItem?
    @State private var resultItem: BacklogItem?
    @State private var showResult = false
    @State private var saveErrorMessage: String?
    @State private var statusMessage: String?

    private enum ModeOption: String, CaseIterable, Identifiable {
        case uniform
        case weighted
        case topN

        var id: String { rawValue }

        var title: String {
            switch self {
            case .uniform: "Uniform"
            case .weighted: "Weighted"
            case .topN: "Top N"
            }
        }

        func wheelMode(topN: Int) -> WheelMode {
            switch self {
            case .uniform: .uniform
            case .weighted: .weighted
            case .topN: .topN(topN)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CategoryFilterBar(selected: $selectedCategory)
                    .onChange(of: selectedCategory) { _, _ in
                        refreshPreviewSlices()
                    }

                modePicker
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if modeSelection == .topN {
                    Stepper("Top \(topNCount)", value: $topNCount, in: 1...20)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .onChange(of: topNCount) { _, _ in
                            refreshPreviewSlices()
                        }
                }

                Spacer(minLength: 8)

                wheelArea

                Spacer(minLength: 8)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                Button {
                    spin()
                } label: {
                    Label(
                        isSpinning ? "Spinning…" : "Spin",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSpinning || pool.isEmpty)
                .padding()
                .accessibilityIdentifier("nextup.wheel.spin")
            }
            .navigationTitle("Wheel")
            .onAppear { refreshPreviewSlices() }
            .onChange(of: modeSelection) { _, _ in
                refreshPreviewSlices()
            }
            .sheet(isPresented: $showResult, onDismiss: {
                resultItem = nil
                refreshPreviewSlices()
            }) {
                if let resultItem {
                    NavigationStack {
                        WheelResultView(
                            item: resultItem,
                            onStart: { startItem(resultItem) },
                            onSpinAgain: {
                                showResult = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    spin()
                                }
                            },
                            onSkip: {
                                showResult = false
                            }
                        )
                        .navigationTitle("Up Next")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showResult = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .alert("Couldn't Save", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $modeSelection) {
            ForEach(ModeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .disabled(isSpinning)
        .accessibilityIdentifier("nextup.wheel.mode")
    }

    private var wheelArea: some View {
        ZStack(alignment: .top) {
            if displaySlices.isEmpty {
                ContentUnavailableView(
                    pool.isEmpty ? "Nothing to spin" : "Ready to spin",
                    systemImage: "circle.dotted",
                    description: Text(
                        pool.isEmpty
                            ? "Add backlog items first, or clear the category filter."
                            : "Tap Spin to load the wheel."
                    )
                )
                .frame(maxWidth: 320)
            } else {
                SpinWheelGraphic(
                    slices: displaySlices,
                    weights: sliceWeights,
                    highlightedID: resultItem?.id ?? pendingWinner?.id
                )
                .rotationEffect(.degrees(rotationDegrees))
                .padding(.top, 28)
                .padding(.horizontal, 24)

                WheelPointer()
                    .offset(y: -2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pool: [BacklogItem] {
        WheelPicker.pool(from: Array(items), category: selectedCategory)
    }

    private var currentMode: WheelMode {
        modeSelection.wheelMode(topN: topNCount)
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
            mode: currentMode,
            category: selectedCategory
        )
        displaySlices = preview
        sliceWeights = WheelPicker.sliceWeights(for: preview, mode: currentMode)
        pendingWinner = nil
        if pool.isEmpty {
            statusMessage = nil
        } else {
            let plural = preview.count == 1 ? "" : "s"
            statusMessage =
                "\(pool.count) in pool · showing \(preview.count) slice\(plural)"
        }
    }

    private func spin() {
        guard !isSpinning else { return }
        guard let result = WheelPicker.spin(
            from: Array(items),
            mode: currentMode,
            category: selectedCategory
        ) else {
            statusMessage = "Nothing to spin in this pool."
            return
        }

        isSpinning = true
        showResult = false
        resultItem = nil
        displaySlices = result.slices
        sliceWeights = WheelPicker.sliceWeights(for: result.slices, mode: currentMode)
        pendingWinner = result.winner
        statusMessage = nil

        let target = targetRotationDegrees(
            slices: result.slices,
            weights: sliceWeights,
            winnerID: result.winner.id
        )
        // Several full turns, then land on the winner under the pointer.
        let landing = rotationDegrees.truncatingRemainder(dividingBy: 360)
        let normalizedLanding = landing < 0 ? landing + 360 : landing
        let delta = (target - normalizedLanding + 360)
            .truncatingRemainder(dividingBy: 360)
        let finalRotation = rotationDegrees + 360 * 5 + delta

        withAnimation(.easeOut(duration: 2.6)) {
            rotationDegrees = finalRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.65) {
            isSpinning = false
            resultItem = result.winner
            showResult = true
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
        }
    }

    /// Degrees to rotate so the winner's slice center sits under the top pointer.
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
                // Slices start at top; rotate so the winner midpoint lands under the pointer.
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
        refreshPreviewSlices()
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
    let context = ModelContext(container)
    for (index, title) in ["Arrival", "Hades", "OK Computer", "The Hobbit"].enumerated() {
        context.insert(
            BacklogItem(
                title: title,
                category: MediaCategory.allCases[index % MediaCategory.allCases.count],
                priority: index
            )
        )
    }
    return WheelView()
        .modelContainer(container)
}
