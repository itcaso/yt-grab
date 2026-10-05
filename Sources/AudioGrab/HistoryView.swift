import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var deletionRequest: HistoryDeletionRequest?

    var body: some View {
        Group {
            if model.history.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("No Downloads Yet")
                        .font(.title2.bold())
                    Text("Completed audio and video downloads will appear here.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(L10n.format("%d history items", model.history.items.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            deletionRequest = .all
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)

                    Divider()

                    List(model.history.items) { item in
                        HistoryRow(item: item) {
                            deletionRequest = .item(item)
                        }
                        .environmentObject(model)
                        .contextMenu {
                            if item.fileExists {
                                Button("Open") { model.open(item.fileURL) }
                                Button("Show in Finder") { model.reveal(item.fileURL) }
                                Divider()
                            }
                            Button("Remove from History", role: .destructive) {
                                deletionRequest = .item(item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .alert(deletionTitle, isPresented: deletionAlertIsPresented) {
            Button(deletionButtonTitle, role: .destructive, action: performDeletion)
            Button("Cancel", role: .cancel) { deletionRequest = nil }
        } message: {
            Text(deletionMessage)
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { deletionRequest != nil },
            set: { if !$0 { deletionRequest = nil } }
        )
    }

    private var deletionTitle: String {
        switch deletionRequest {
        case .item: L10n.text("Remove Download from History?")
        case .all: L10n.text("Clear All Download History?")
        case nil: ""
        }
    }

    private var deletionButtonTitle: String {
        switch deletionRequest {
        case .item: L10n.text("Remove")
        case .all: L10n.text("Clear History")
        case nil: ""
        }
    }

    private var deletionMessage: String {
        L10n.text("Downloaded files will not be deleted from your Mac.")
    }

    private func performDeletion() {
        switch deletionRequest {
        case .item(let item): model.history.remove(item)
        case .all: model.history.clear()
        case nil: break
        }
        deletionRequest = nil
    }
}

private enum HistoryDeletionRequest {
    case item(HistoryItem)
    case all
}

private struct HistoryRow: View {
    @EnvironmentObject private var model: AppModel
    let item: HistoryItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.symbol)
                .font(.title3)
                .foregroundStyle(item.type == .audio ? .purple : .blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).lineLimit(1)
                Text(detailText).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if item.fileExists {
                Button { model.open(item.fileURL) } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.plain)
                .help("Open")
                Button { model.reveal(item.fileURL) } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            } else {
                Text(L10n.text("File moved")).font(.caption).foregroundStyle(.tertiary)
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove from History")
        }
        .padding(.vertical, 6)
    }

    private var detailText: String {
        let type = item.type.title
        let size = item.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        return ([type, item.details] + [size].compactMap { $0 }).joined(separator: " · ")
    }
}
