import SwiftUI
import BacklogCore

struct WheelResultView: View {
    let item: BacklogItem
    let onStart: () -> Void
    let onSpinAgain: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            AsyncImage(url: coverURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: symbolName)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 160, height: 220)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 6) {
                Text(item.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(detailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: onStart) {
                    Label("Start it", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("nextup.wheel.start")

                Button(action: onSpinAgain) {
                    Label("Spin again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("nextup.wheel.again")

                Button("Skip", action: onSkip)
                    .font(.body.weight(.medium))
                    .accessibilityIdentifier("nextup.wheel.skip")
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 8)
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
