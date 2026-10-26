import SwiftUI
import BacklogCore

/// Full-screen result after a spin — focusable buttons for the remote.
struct TVWheelResultView: View {
    let item: BacklogItem
    let onStart: () -> Void
    let onSpinAgain: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 60) {
            coverArt
                .frame(width: 280, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Up Next")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.largeTitle.weight(.bold))
                        .lineLimit(3)
                    Text(detailLine)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Button(action: onStart) {
                        Label("Start it", systemImage: "play.fill")
                            .frame(minWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
                    .accessibilityIdentifier("nextuptv.wheel.start")

                    Button(action: onSpinAgain) {
                        Label("Spin again", systemImage: "arrow.triangle.2.circlepath")
                            .frame(minWidth: 280)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .accessibilityIdentifier("nextuptv.wheel.again")

                    Button("Close", action: onDismiss)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("nextuptv.wheel.skip")
                }
                .focusSection()
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var coverArt: some View {
        AsyncImage(url: coverURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    Color.secondary.opacity(0.18)
                    Image(systemName: symbolName)
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var coverURL: URL? {
        guard let string = item.coverURL else { return nil }
        return URL(string: string)
    }

    private var detailLine: String {
        var parts: [String] = [item.category.singularName]
        if !item.subtitle.isEmpty { parts.append(item.subtitle) }
        if let year = item.year { parts.append(String(year)) }
        return parts.joined(separator: " · ")
    }

    private var symbolName: String {
        switch item.category {
        case .album: "music.note"
        case .game: "gamecontroller"
        case .movie: "film"
        case .tv: "tv"
        case .book: "book"
        }
    }
}
