import SwiftUI
import BacklogCore

struct TVBacklogRowView: View {
    let item: BacklogItem

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .background(
                    Color.secondary.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(subtitleText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
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
