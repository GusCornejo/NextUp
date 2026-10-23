import SwiftUI
import BacklogCore

struct BacklogRowView: View {
    let item: BacklogItem

    var body: some View {
        HStack(spacing: 12) {
            categoryGlyph
                .frame(width: 36, height: 36)
                .background(
                    Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.category.singularName)")
    }

    private var subtitleText: String {
        var parts: [String] = [item.category.singularName]
        if !item.subtitle.isEmpty {
            parts.append(item.subtitle)
        }
        if let year = item.year {
            parts.append(String(year))
        }
        return parts.joined(separator: " · ")
    }

    private var categoryGlyph: some View {
        Image(systemName: symbolName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
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
