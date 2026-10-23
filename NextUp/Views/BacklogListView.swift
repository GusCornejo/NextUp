import SwiftUI
import SwiftData
import BacklogCore

struct BacklogListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: [
        SortDescriptor(\BacklogItem.priority),
        SortDescriptor(\BacklogItem.createdAt),
    ])
    var items: [BacklogItem]

    @State var selectedCategory: MediaCategory?
    @State var isAddingItem = false
    @State var isDoneExpanded = false
    @State var saveErrorMessage: String?

    var isFilteringByCategory: Bool { selectedCategory != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CategoryFilterBar(selected: $selectedCategory)

                List {
                    upNextSection
                    backlogSection
                    inProgressSection
                    doneSection
                }
                .listStyle(.insetGrouped)
                .environment(
                    \.editMode,
                    isFilteringByCategory ? .constant(.inactive) : nil
                )
                .overlay {
                    if filteredItems.isEmpty {
                        ContentUnavailableView(
                            "No items yet",
                            systemImage: "tray",
                            description: Text(
                                "Add something manually to start your backlog."
                            )
                        )
                    }
                }
            }
            .navigationTitle("Next Up")
            .toolbar { toolbarContent }
            .sheet(isPresented: $isAddingItem) {
                AddItemView()
            }
            .alert("Couldn't Save", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isAddingItem = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("nextup.add")
            .accessibilityLabel("Add item")
        }
        if !isFilteringByCategory {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
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
    context.insert(BacklogItem(title: "Arrival", category: .movie, priority: 0))
    context.insert(BacklogItem(title: "Hades", category: .game, priority: 1))

    return BacklogListView()
        .modelContainer(container)
}
