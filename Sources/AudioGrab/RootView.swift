import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $model.navigation) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 210)
        } detail: {
            switch model.navigation ?? .download {
            case .download:
                DownloadView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.state == .analyzed || model.state == .complete {
                    Button {
                        model.downloadAnother()
                    } label: {
                        Label("New Download", systemImage: "plus")
                    }
                }
            }
        }
    }
}
