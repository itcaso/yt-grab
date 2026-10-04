import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []

    private var historyURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("YT-Grab", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    init() {
        load()
    }

    func add(_ item: HistoryItem) {
        items.insert(item, at: 0)
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func setDocumentationItems(_ documentationItems: [HistoryItem]) {
        items = documentationItems
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // History persistence must never interrupt a completed download.
        }
    }
}
