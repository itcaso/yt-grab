import AppKit
import Foundation
import UserNotifications

enum NavigationItem: String, CaseIterable, Identifiable {
    case download = "Download"
    case history = "History"
    case settings = "Settings"
    var id: String { rawValue }
    var title: String { L10n.text(rawValue) }
    var symbol: String {
        switch self {
        case .download: "arrow.down.circle"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

enum MainState: Equatable {
    case empty
    case analyzing
    case analyzed
    case downloading
    case complete
}

enum VideoValidationError: LocalizedError {
    case noDownloadableVideo
    case selectedQualityUnavailable

    var errorDescription: String? {
        switch self {
        case .noDownloadableVideo:
            L10n.text("This link does not contain a downloadable video stream.")
        case .selectedQualityUnavailable:
            L10n.text("The selected video quality is no longer available. Choose another quality and try again.")
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var navigation: NavigationItem? = .download
    @Published var downloadType: DownloadType = .audio
    @Published var urlText = ""
    @Published var state: MainState = .empty
    @Published var metadata: MediaMetadata?
    @Published var audioFormat: AudioFormat = .mp3
    @Published var audioQuality: AudioQuality = .kbps320
    @Published var videoFormat: VideoFormat = .mp4
    @Published var videoQuality: VideoQuality = .best
    @Published var stage: DownloadStage = .idle
    @Published var progress: Double?
    @Published var speed: String?
    @Published var eta: String?
    @Published var result: DownloadResult?
    @Published var errorMessage: String?
    @Published var ytDLPStatus = DependencyStatus(name: "yt-dlp", executableURL: nil, version: nil)
    @Published var ffmpegStatus = DependencyStatus(name: "FFmpeg", executableURL: nil, version: nil)
    @Published var isInstallingYTDLP = false
    @Published var dependencyInstallMessage: String?
    @Published var isValidatingVideo = false

    @Published var settings = AppSettings()
    let history = HistoryStore()
    private let service = YTDLPService()
    private let dependencies = DependencyManager()
    private let dependencyInstaller = DependencyInstaller()
    private var operation: Task<Void, Never>?

    init() {
        audioFormat = settings.defaultAudioFormat
        audioQuality = settings.defaultAudioQuality
        videoQuality = settings.defaultVideoQuality
        refreshDependencies()
    }

    var parsedURL: URL? {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    var availableVideoQualities: [VideoQuality] {
        metadata?.availableVideoQualities ?? [.best]
    }

    var destination: URL {
        settings.destination(for: downloadType)
    }

    var canDownloadSelection: Bool {
        downloadType == .audio || metadata?.hasDownloadableVideo == true
    }

    func selectType(_ type: DownloadType) {
        downloadType = type
        if type == .video, !availableVideoQualities.contains(videoQuality) {
            videoQuality = .best
        }
    }

    func analyze() {
        guard let url = parsedURL else {
            errorMessage = L10n.text("Enter a valid http or https link.")
            return
        }
        errorMessage = nil
        state = .analyzing
        operation?.cancel()
        operation = Task {
            do {
                metadata = try await service.analyze(url: url)
                if !availableVideoQualities.contains(videoQuality) { videoQuality = .best }
                state = .analyzed
            } catch is CancellationError {
                state = metadata == nil ? .empty : .analyzed
            } catch {
                state = .empty
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    func download() {
        guard let url = parsedURL, let metadata else { return }
        errorMessage = nil
        let selectedType = downloadType
        let selectedVideoQuality = videoQuality
        let selectedAudioFormat = audioFormat
        let selectedAudioQuality = audioQuality
        let selectedVideoFormat = videoFormat
        let selectedDestination = destination
        let shouldDeleteTemporaryFiles = settings.deleteTemporaryFiles

        operation?.cancel()
        operation = Task {
            do {
                var confirmedMetadata = metadata
                if selectedType == .video {
                    isValidatingVideo = true
                    let refreshedMetadata = try await service.analyze(url: url)
                    self.metadata = refreshedMetadata
                    guard refreshedMetadata.hasDownloadableVideo else {
                        throw VideoValidationError.noDownloadableVideo
                    }
                    guard refreshedMetadata.supports(videoQuality: selectedVideoQuality) else {
                        videoQuality = .best
                        throw VideoValidationError.selectedQualityUnavailable
                    }
                    confirmedMetadata = refreshedMetadata
                    isValidatingVideo = false
                }

                state = .downloading
                stage = selectedType == .video ? .downloadingVideo : .downloading
                progress = 0
                result = nil

                let configuration = DownloadConfiguration(
                    url: url,
                    type: selectedType,
                    audioFormat: selectedAudioFormat,
                    audioQuality: selectedAudioQuality,
                    videoFormat: selectedVideoFormat,
                    videoQuality: selectedVideoQuality,
                    destination: selectedDestination,
                    deleteTemporaryFiles: shouldDeleteTemporaryFiles
                )
                let detail = selectedType == .audio
                    ? "\(selectedAudioFormat.rawValue) · \(selectedAudioQuality.title)"
                    : "\(selectedVideoFormat.rawValue) · \(selectedVideoQuality.title)"

                let completed = try await service.download(configuration: configuration) { [weak self] update in
                    Task { @MainActor in
                        self?.stage = update.stage
                        if let fraction = update.fraction {
                            self?.progress = fraction
                        }
                        self?.speed = update.speed
                        self?.eta = update.eta
                    }
                }
                result = completed
                stage = .completed
                progress = 1
                state = .complete
                history.add(HistoryItem(
                    title: confirmedMetadata.title,
                    type: selectedType,
                    details: detail,
                    fileURL: completed.fileURL,
                    fileSize: completed.size
                ))
                sendCompletionNotification(title: confirmedMetadata.title)
            } catch is CancellationError {
                isValidatingVideo = false
                stage = .cancelled
                state = .analyzed
            } catch {
                isValidatingVideo = false
                stage = .failed
                state = .analyzed
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    func cancel() {
        service.cancel()
        operation?.cancel()
    }

    func downloadAnother() {
        operation?.cancel()
        urlText = ""
        metadata = nil
        result = nil
        isValidatingVideo = false
        stage = .idle
        progress = nil
        speed = nil
        eta = nil
        errorMessage = nil
        state = .empty
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func refreshDependencies() {
        Task {
            async let yt = dependencies.status(for: "yt-dlp")
            async let ffmpeg = dependencies.status(for: "ffmpeg", versionArguments: ["-version"])
            ytDLPStatus = await yt
            ffmpegStatus = await ffmpeg
        }
    }

    func installYTDLP() {
        guard !isInstallingYTDLP else { return }
        isInstallingYTDLP = true
        dependencyInstallMessage = nil
        Task {
            defer { isInstallingYTDLP = false }
            do {
                let version = try await dependencyInstaller.installYTDLP()
                ytDLPStatus = await dependencies.status(for: "yt-dlp")
                dependencyInstallMessage = L10n.format("yt-dlp %@ was installed and verified successfully.", version)
            } catch {
                dependencyInstallMessage = error.localizedDescription
            }
        }
    }

    func copyFFmpegInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew install ffmpeg", forType: .string)
        dependencyInstallMessage = L10n.text("The Homebrew command was copied. Paste it into Terminal, wait for it to finish, then select Refresh.")
    }

    func configureDocumentationScreenshot(state screenshotState: String) {
        let demoMetadata = MediaMetadata(
            title: L10n.text("YT-Grab Demo Video"),
            channel: "YT-Grab",
            duration: 154,
            thumbnailURL: nil,
            formats: [
                MediaFormat(formatID: "1080", extensionName: "mp4", width: 1920, height: 1080, fps: 30, videoCodec: "h264", audioCodec: "none", fileSize: 48_000_000, approximateFileSize: nil),
                MediaFormat(formatID: "720", extensionName: "mp4", width: 1280, height: 720, fps: 30, videoCodec: "h264", audioCodec: "none", fileSize: 28_000_000, approximateFileSize: nil),
                MediaFormat(formatID: "audio", extensionName: "m4a", width: nil, height: nil, fps: nil, videoCodec: "none", audioCodec: "aac", fileSize: 4_000_000, approximateFileSize: nil)
            ]
        )

        navigation = .download
        downloadType = .video
        urlText = "https://example.com/videos/yt-grab-demo"
        metadata = demoMetadata
        errorMessage = nil
        videoQuality = .height(1080)

        switch screenshotState {
        case "input":
            metadata = nil
            state = .empty
        case "downloading":
            state = .downloading
            stage = .downloadingVideo
            progress = 0.64
            speed = "2.8 MiB/s"
            eta = "00:08"
        case "history":
            navigation = .history
            state = .empty
            let availableFile = URL(fileURLWithPath: "/Applications/YT-Grab.app")
            history.setDocumentationItems([
                HistoryItem(
                    title: L10n.text("YT-Grab Demo Video"),
                    type: .video,
                    details: "MP4 · 1080p",
                    fileURL: availableFile,
                    fileSize: 48_000_000
                ),
                HistoryItem(
                    title: L10n.text("Demo Podcast Episode"),
                    type: .audio,
                    details: "MP3 · 320 kbps",
                    fileURL: availableFile,
                    fileSize: 9_500_000
                )
            ])
        default:
            break
        }
    }

    private func sendCompletionNotification(title: String) {
        guard settings.showNotifications else { return }
        let notificationTitle = L10n.text("Download Complete")
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else { return }

                let content = UNMutableNotificationContent()
                content.title = notificationTitle
                content.body = title
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                try await center.add(request)
            } catch {
                // Notification permission or delivery failures must never interrupt a completed download.
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("requested format is not available") {
            return L10n.text("The selected video quality is no longer available. Analyze the link again and choose another quality.")
        }
        if message.localizedCaseInsensitiveContains("ffmpeg") {
            return L10n.text("FFmpeg is required to process or merge this download. Check Settings and try again.")
        }
        return message
    }
}
