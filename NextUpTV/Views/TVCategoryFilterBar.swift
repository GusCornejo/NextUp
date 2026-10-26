import SwiftUI
import BacklogCore

/// Focusable category chips for the Siri Remote (no swipe-only interaction).
struct TVCategoryFilterBar: View {
    @Binding var selected: MediaCategory?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                filterChip(title: "All", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(MediaCategory.allCases, id: \.self) { category in
                    filterChip(
                        title: category.displayName,
                        isSelected: selected == category
                    ) {
                        selected = category
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .focusSection()
        }
        .accessibilityIdentifier("nextuptv.categoryFilter")
    }

    private func filterChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Color.accentColor : Color.secondary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
