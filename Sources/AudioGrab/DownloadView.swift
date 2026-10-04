import SwiftUI

struct DownloadView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                Group {
                    switch model.state {
                    case .empty, .analyzing:
                        emptyContent
                    case .analyzed:
                        analyzedContent
                    case .downloading:
                        downloadingContent
                    case .complete:
                        completeContent
                    }
                }
                .frame(maxWidth: 580)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
            .animation(.easeInOut(duration: 0.2), value: model.state)
        }
        .navigationTitle("Download")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("YTGrabAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text("YT-Grab")
                .font(.largeTitle.bold())
            Text("Download media you have permission to save.")
                .foregroundStyle(.secondary)
        }
    }

    private var typePicker: some View {
        HStack(spacing: 12) {
            ForEach(DownloadType.allCases) { type in
                Button {
                    model.selectType(type)
                } label: {
                    Label(type.title, systemImage: type.symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SelectionCardButtonStyle(isSelected: model.downloadType == type))
            }
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 22) {
            Text("What do you want to download?")
                .font(.title3.weight(.semibold))
            typePicker

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste a YouTube link")
                    .font(.subheadline.weight(.medium))
                TextField("https://youtube.com/…", text: $model.urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit(model.analyze)
                    .disabled(model.state == .analyzing)
            }

            Button(action: model.analyze) {
                if model.state == .analyzing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Analyzing…")
                    }
                    .frame(minWidth: 110)
                } else {
                    Text("Analyze").frame(minWidth: 110)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.parsedURL == nil || model.state == .analyzing)
        }
    }

    private var analyzedContent: some View {
        VStack(spacing: 20) {
            typePicker
            if let metadata = model.metadata {
                MediaCard(metadata: metadata)
            }
            optionsCard
            if model.downloadType == .video, let metadata = model.metadata {
                HStack(spacing: 8) {
                    Image(systemName: metadata.hasDownloadableVideo ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundStyle(metadata.hasDownloadableVideo ? .green : .red)
                    Text(metadata.hasDownloadableVideo
                         ? L10n.format("Video link verified · %d qualities available", max(metadata.availableVideoQualities.count - 1, 1))
                         : L10n.text("No downloadable video stream was found at this link."))
                        .font(.callout)
                    Spacer()
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Destination")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.destination.path(percentEncoded: false))
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Change…", action: model.settings.chooseBaseDirectory)
            }
            Button(action: model.download) {
                HStack(spacing: 8) {
                    if model.isValidatingVideo { ProgressView().controlSize(.small) }
                    Label(
                        model.isValidatingVideo
                            ? L10n.text("Validating video…")
                            : (model.downloadType == .audio ? L10n.text("Download Audio") : L10n.text("Download Video")),
                        systemImage: model.isValidatingVideo ? "checkmark.shield" : "arrow.down.circle.fill"
                    )
                }
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isValidatingVideo || !model.canDownloadSelection)
        }
    }

    private var optionsCard: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 12) {
                if model.downloadType == .audio {
                    GridRow {
                        Text("Format").foregroundStyle(.secondary)
                        Picker("Format", selection: $model.audioFormat) {
                            ForEach(AudioFormat.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("Quality").foregroundStyle(.secondary)
                        Picker("Quality", selection: $model.audioQuality) {
                            ForEach(AudioQuality.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                } else {
                    GridRow {
                        Text("Quality").foregroundStyle(.secondary)
                        Picker("Quality", selection: $model.videoQuality) {
                            ForEach(model.availableVideoQualities) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("Format").foregroundStyle(.secondary)
                        Picker("Format", selection: $model.videoFormat) {
                            ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var downloadingContent: some View {
        VStack(spacing: 20) {
            if let metadata = model.metadata { MediaCard(metadata: metadata) }
            VStack(spacing: 12) {
                Text(model.stage.title)
                    .font(.headline)
                let displayedProgress = model.progress ?? 0
                ProgressView(value: displayedProgress, total: 1)
                    .progressViewStyle(.linear)
                    .animation(.easeOut(duration: 0.25), value: displayedProgress)
                Text(displayedProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .animation(.easeOut(duration: 0.2), value: displayedProgress)
                if model.speed != nil || model.eta != nil {
                    Text([model.speed, model.eta.map { L10n.format("%@ remaining", $0) }].compactMap { $0 }.joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))

            Button("Cancel", role: .destructive, action: model.cancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private var completeContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Download Complete")
                .font(.title2.bold())
            if let result = model.result {
                Text(result.fileURL.lastPathComponent)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(completionDetails(result))
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open") { model.open(result.fileURL) }
                        .buttonStyle(.borderedProminent)
                    Button("Show in Finder") { model.reveal(result.fileURL) }
                        .buttonStyle(.bordered)
                }
            }
            Divider().padding(.vertical, 4)
            Button("Download Another", action: model.downloadAnother)
                .controlSize(.large)
        }
    }

    private func completionDetails(_ result: DownloadResult) -> String {
        let format = model.downloadType == .audio ? model.audioFormat.rawValue : model.videoFormat.rawValue
        let quality = model.downloadType == .audio ? model.audioQuality.title : model.videoQuality.title
        let size = result.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? L10n.text("Unknown size")
        return "\(format) · \(quality) · \(size)"
    }
}

private struct SelectionCardButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.secondary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.16), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.callout)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 580)
    }
}

private struct MediaCard: View {
    let metadata: MediaMetadata

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: metadata.thumbnailURL) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "play.rectangle").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 144, height: 81)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(metadata.title)
                    .font(.headline)
                    .lineLimit(2)
                Text([metadata.channel, durationText].compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }

    private var durationText: String? {
        guard let duration = metadata.duration else { return nil }
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
