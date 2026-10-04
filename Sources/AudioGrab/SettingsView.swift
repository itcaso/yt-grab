import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Download Location") {
                    HStack {
                        Text(model.settings.baseDirectory.path(percentEncoded: false))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…", action: model.settings.chooseBaseDirectory)
                    }
                }
                Toggle("Organize downloads into Audio and Video folders", isOn: $model.settings.organizeByType)
            }

            Section("Audio") {
                Picker("Default Format", selection: $model.settings.defaultAudioFormat) {
                    ForEach(AudioFormat.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Default Quality", selection: $model.settings.defaultAudioQuality) {
                    ForEach(AudioQuality.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Video") {
                Picker("Default Format", selection: $model.videoFormat) {
                    ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Default Quality", selection: $model.settings.defaultVideoQuality) {
                    Text(VideoQuality.best.title).tag(VideoQuality.best)
                }
            }

            Section("Downloads") {
                Toggle("Delete temporary files automatically", isOn: $model.settings.deleteTemporaryFiles)
                Toggle("Show notifications when download finishes", isOn: $model.settings.showNotifications)
            }

            Section("Dependencies") {
                DependencyRow(
                    status: model.ytDLPStatus,
                    explanation: L10n.text("yt-dlp analyzes links and downloads the available media streams.")
                )
                DependencyRow(
                    status: model.ffmpegStatus,
                    explanation: L10n.text("FFmpeg converts audio and joins video with audio.")
                )
                HStack {
                    Text("Install missing dependencies, then refresh their status.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh", action: model.refreshDependencies)
                }
                if !model.ytDLPStatus.isInstalled {
                    HStack {
                        Button(action: model.installYTDLP) {
                            HStack(spacing: 7) {
                                if model.isInstallingYTDLP { ProgressView().controlSize(.small) }
                                Text(model.isInstallingYTDLP ? "Installing yt-dlp…" : "Install yt-dlp automatically")
                            }
                        }
                        .disabled(model.isInstallingYTDLP)
                        Link(
                            "Official download",
                            destination: URL(string: "https://github.com/yt-dlp/yt-dlp/wiki/Installation")!
                        )
                    }
                    Text("The automatic installer downloads the official macOS executable, verifies its SHA-256 checksum and saves it in ~/.local/bin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !model.ffmpegStatus.isInstalled {
                    HStack {
                        Link("FFmpeg installation instructions", destination: URL(string: "https://ffmpeg.org/download.html")!)
                        Button("Copy Homebrew command", action: model.copyFFmpegInstallCommand)
                    }
                    Text("Install FFmpeg from its official download page, or use Homebrew in Terminal. YT-Grab will detect it after you refresh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = model.dependencyInstallMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("About YT-Grab") {
                LabeledContent("Development") {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Developed by")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Italo McFly (itcaso)")
                            .fontWeight(.semibold)
                    }
                }
                LabeledContent("Links") {
                    VStack(alignment: .trailing, spacing: 6) {
                        Link("Telegram · @itcaso", destination: URL(string: "https://t.me/itcaso")!)
                        Link("X · @itcaso", destination: URL(string: "https://x.com/itcaso")!)
                    }
                }
                LabeledContent("Version", value: appVersion)
                LabeledContent("License") {
                    Link(
                        "PolyForm Noncommercial 1.0.0",
                        destination: URL(string: "https://polyformproject.org/licenses/noncommercial/1.0.0")!
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }
}

private struct DependencyRow: View {
    let status: DependencyStatus
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LabeledContent(status.name) {
                HStack(spacing: 8) {
                    Image(systemName: status.isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(status.isInstalled ? .green : .red)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(status.isInstalled ? L10n.text("Installed") : L10n.text("Not Found"))
                        if let version = status.version {
                            Text(version).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
