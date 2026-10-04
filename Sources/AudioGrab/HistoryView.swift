import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

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
                List(model.history.items) { item in
                    HistoryRow(item: item)
                        .environmentObject(model)
                        .contextMenu {
                            if item.fileExists {
                                Button("Open") { model.open(item.fileURL) }
                                Button("Show in Finder") { model.reveal(item.fileURL) }
                            }
                        }
                }
            }
        }
        .navigationTitle("History")
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var model: AppModel
    let item: HistoryItem

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
        }
        .padding(.vertical, 6)
    }

    private var detailText: String {
        let type = item.type.title
        let size = item.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        return ([type, item.details] + [size].compactMap { $0 }).joined(separator: " · ")
    }
}
