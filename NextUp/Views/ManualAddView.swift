import SwiftUI
import SwiftData
import BacklogCore

struct ManualAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allItems: [BacklogItem]

    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var yearText: String = ""
    @State private var category: MediaCategory
    @State private var saveErrorMessage: String?

    init(initialCategory: MediaCategory = .movie) {
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("nextup.add.title")

                    TextField("Subtitle (optional)", text: $subtitle)
                        .textInputAutocapitalization(.words)

                    TextField("Year (optional)", text: $yearText)
                        .keyboardType(.numberPad)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(MediaCategory.allCases, id: \.self) { category in
                            Text(category.singularName).tag(category)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Add Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("nextup.add.save")
                }
            }
            .alert("Couldn't Save", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let year = Int(yearText.trimmingCharacters(in: .whitespacesAndNewlines))
        let priority = BacklogOrdering.nextBottomPriority(among: Array(allItems))
        let now = Date()

        let item = BacklogItem(
            title: trimmedTitle,
            subtitle: trimmedSubtitle,
            year: year,
            category: category,
            status: .backlog,
            priority: priority,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(item)
        if let message = modelContext.saveReportingFailure(operation: "add item") {
            saveErrorMessage = message
            return
        }
        dismiss()
    }
}
