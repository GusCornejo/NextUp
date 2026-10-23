import SwiftUI
import SwiftData
import BacklogCore

struct ContentView: View {
    var body: some View {
        TabView {
            BacklogListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .accessibilityIdentifier("nextup.tab.list")

            WheelView()
                .tabItem {
                    Label("Wheel", systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("nextup.tab.wheel")
        }
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
    return ContentView()
        .modelContainer(container)
}
