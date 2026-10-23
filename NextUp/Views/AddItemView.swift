import SwiftUI
import SwiftData
import BacklogCore

/// Category → search → save; manual add remains available as a fallback.
struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [BacklogItem]

    @State private var category: MediaCategory = .movie
    @State private var query: String = ""
    @State private var results: [MediaSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var saveErrorMessage: String?
    @State private var showManualAdd = false
    @State private var searchTask: Task<Void, Never>?

    private let searcher = MediaSearchFacade(
        tmdbAPIKey: APIKeyStore.tmdbAPIKey,
        rawgAPIKey: APIKeyStore.rawgAPIKey
    )

    var body: some View {
        NavigationStack {
            List {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(MediaCategory.allCases, id: \.self) { item in
                            Text(item.singularName).tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: category) { _, _ in
                        results = []
                        searchError = nil
                        scheduleSearch()
                    }
                }

                Section {
                    TextField("Search \(category.displayName.lowercased())", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("nextup.search.query")
                        .onChange(of: query) { _, _ in
                            scheduleSearch()
                        }

                    if let keyHint = missingKeyHint {
                        Text(keyHint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if isSearching {
                        ProgressView("Searching…")
                    }

                    if let searchError {
                        Text(searchError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    ForEach(results) { result in
                        Button {
                            save(result)
                        } label: {
                            SearchResultRow(result: result)
                        }
                        .accessibilityIdentifier("nextup.search.result")
                    }
                } header: {
                    Text("Search")
                } footer: {
                    Text(footerText)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Manually") {
                        showManualAdd = true
                    }
                    .accessibilityIdentifier("nextup.add.manual")
                }
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddView(initialCategory: category)
            }
            .alert("Couldn't Save", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private var footerText: String {
        switch category {
        case .movie, .tv:
            return "Powered by TMDB. Needs TMDB_API_KEY in Config/Secrets.xcconfig."
        case .game:
            return "Powered by RAWG. Needs RAWG_API_KEY in Config/Secrets.xcconfig."
        case .album:
            return "Powered by MusicBrainz + Cover Art Archive (no key)."
        case .book:
            return "Powered by Open Library (no key)."
        }
    }

    private var missingKeyHint: String? {
        switch category {
        case .movie, .tv:
            return APIKeyStore.hasTMDBKey
                ? nil
                : "Add your TMDB API key to Config/Secrets.xcconfig, then rebuild."
        case .game:
            return APIKeyStore.hasRAWGKey
                ? nil
                : "Add your RAWG API key to Config/Secrets.xcconfig, then rebuild."
        case .album, .book:
            return nil
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let snapshotQuery = query
        let snapshotCategory = category
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch(query: snapshotQuery, category: snapshotCategory)
        }
    }

    @MainActor
    private func performSearch(query: String, category: MediaCategory) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            searchError = nil
            isSearching = false
            return
        }

        if category == .movie || category == .tv, !APIKeyStore.hasTMDBKey {
            results = []
            searchError = MediaSearchError.missingAPIKey("TMDB_API_KEY").localizedDescription
            return
        }
        if category == .game, !APIKeyStore.hasRAWGKey {
            results = []
            searchError = MediaSearchError.missingAPIKey("RAWG_API_KEY").localizedDescription
            return
        }

        isSearching = true
        searchError = nil
        defer { isSearching = false }

        do {
            results = try await searcher.search(query: trimmed, category: category)
            if results.isEmpty {
                searchError = "No results. Try another query or add manually."
            }
        } catch let error as MediaSearchError {
            results = []
            searchError = error.localizedDescription
        } catch {
            results = []
            searchError = error.localizedDescription
        }
    }

    private func save(_ result: MediaSearchResult) {
        let priority = BacklogOrdering.nextBottomPriority(among: Array(allItems))
        let now = Date()
        let item = BacklogItem(
            title: result.title,
            subtitle: result.subtitle,
            coverURL: result.coverURL,
            externalID: result.externalID,
            year: result.year,
            category: result.category,
            status: .backlog,
            priority: priority,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(item)
        if let message = modelContext.saveReportingFailure(operation: "add from search") {
            saveErrorMessage = message
            return
        }
        dismiss()
    }
}

private struct SearchResultRow: View {
    let result: MediaSearchResult

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: coverURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 44, height: 66)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var coverURL: URL? {
        guard let coverURL = result.coverURL else { return nil }
        return URL(string: coverURL)
    }

    private var detailLine: String {
        var parts: [String] = []
        if !result.subtitle.isEmpty { parts.append(result.subtitle) }
        if let year = result.year { parts.append(String(year)) }
        return parts.isEmpty ? result.category.singularName : parts.joined(separator: " · ")
    }
}
