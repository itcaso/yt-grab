import Foundation

struct DownloadProgress: Sendable {
    let stage: DownloadStage
    let fraction: Double?
    let speed: String?
    let eta: String?
}

enum YTDLPServiceError: LocalizedError {
    case missingYTDLP
    case missingFFmpeg
    case invalidResponse
    case noOutputFile

    var errorDescription: String? {
        switch self {
        case .missingYTDLP: L10n.text("yt-dlp is required. Install it from Settings to analyze and download media.")
        case .missingFFmpeg: L10n.text("FFmpeg is required to create the selected output. Install it and try again.")
        case .invalidResponse: L10n.text("The media information could not be read. Check the link and try again.")
        case .noOutputFile: L10n.text("The download finished, but the output file could not be located.")
        }
    }
}

final class YTDLPService: @unchecked Sendable {
    private let dependencies = DependencyManager()
    private var activeProcess: RunningProcess?

    func analyze(url: URL) async throws -> MediaMetadata {
        guard let executableURL = dependencies.find("yt-dlp") else {
            throw YTDLPServiceError.missingYTDLP
        }

        let output = try await ProcessRunner.runAndCapture(
            executableURL: executableURL,
            arguments: YTDLPArgumentBuilder.analysis(url: url)
        )
        guard let data = output.data(using: .utf8) else { throw YTDLPServiceError.invalidResponse }

        do {
            return try JSONDecoder().decode(YTDLPResponse.self, from: data).metadata()
        } catch {
            throw YTDLPServiceError.invalidResponse
        }
    }

    func download(
        configuration: DownloadConfiguration,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> DownloadResult {
        guard let executableURL = dependencies.find("yt-dlp") else {
            throw YTDLPServiceError.missingYTDLP
        }
        guard let ffmpegURL = dependencies.find("ffmpeg") else {
            throw YTDLPServiceError.missingFFmpeg
        }

        try FileManager.default.createDirectory(
            at: configuration.destination,
            withIntermediateDirectories: true
        )

        let arguments = configuration.type == .audio
            ? YTDLPArgumentBuilder.audio(configuration: configuration, ffmpegLocation: ffmpegURL)
            : YTDLPArgumentBuilder.video(configuration: configuration, ffmpegLocation: ffmpegURL)
        let handle = RunningProcess()
        activeProcess = handle
        let outputFile = LockedValue<URL>()

        defer { activeProcess = nil }

        try await ProcessRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            handle: handle
        ) { line in
            if line.hasPrefix("filepath:") {
                outputFile.set(URL(fileURLWithPath: String(line.dropFirst("filepath:".count))))
                return
            }

            let lower = line.lowercased()
            if lower.contains("merging formats") || lower.contains("merger") {
                progress(DownloadProgress(stage: .merging, fraction: nil, speed: nil, eta: nil))
            } else if lower.contains("extractaudio") || lower.contains("post-process") {
                progress(DownloadProgress(stage: .processing, fraction: nil, speed: nil, eta: nil))
            } else if line.hasPrefix("download:") {
                let fields = String(line.dropFirst("download:".count)).split(separator: "|", omittingEmptySubsequences: false)
                let rawPercent = fields.first.map(String.init)?.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                let fraction = rawPercent.flatMap(Double.init).map { min(max($0 / 100, 0), 1) }
                let speed = fields.count > 1 ? String(fields[1]) : nil
                let eta = fields.count > 2 ? String(fields[2]) : nil
                let stage: DownloadStage = configuration.type == .video ? .downloadingVideo : .downloading
                progress(DownloadProgress(stage: stage, fraction: fraction, speed: speed, eta: eta))
            }
        }

        guard let fileURL = outputFile.value else { throw YTDLPServiceError.noOutputFile }
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return DownloadResult(fileURL: fileURL, size: values?.fileSize.map(Int64.init))
    }

    func cancel() {
        activeProcess?.cancel()
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    var value: Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
