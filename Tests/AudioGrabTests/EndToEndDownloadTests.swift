import Foundation
import Testing
@testable import AudioGrab

struct EndToEndDownloadTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["YT_GRAB_E2E_URL"] != nil))
    func authorizedLocalMediaDownloadsAsAudioAndVideo() async throws {
        let environment = ProcessInfo.processInfo.environment
        let sourceURL = try #require(environment["YT_GRAB_E2E_URL"].flatMap(URL.init(string:)))
        let outputRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("YT-Grab-E2E-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputRoot) }

        let service = YTDLPService()
        let metadata = try await service.analyze(url: sourceURL)
        #expect(metadata.hasDownloadableVideo)

        let audioResult = try await service.download(
            configuration: configuration(url: sourceURL, type: .audio, destination: outputRoot.appendingPathComponent("Audio")),
            progress: { _ in }
        )
        #expect(audioResult.fileURL.pathExtension.lowercased() == "mp3")
        #expect((audioResult.size ?? 0) > 0)

        let stages = ProgressStages()
        let videoResult = try await service.download(
            configuration: configuration(url: sourceURL, type: .video, destination: outputRoot.appendingPathComponent("Video")),
            progress: { stages.insert($0.stage) }
        )
        #expect(videoResult.fileURL.pathExtension.lowercased() == "mp4")
        #expect((videoResult.size ?? 0) > 0)
        #expect(stages.contains(.downloadingVideo))

        let dependencies = DependencyManager()
        let ffmpeg = try #require(dependencies.find("ffmpeg"))
        _ = try await ProcessRunner.runAndCapture(
            executableURL: ffmpeg,
            arguments: ["-v", "error", "-i", audioResult.fileURL.path, "-map", "0:a:0", "-f", "null", "-"]
        )
        _ = try await ProcessRunner.runAndCapture(
            executableURL: ffmpeg,
            arguments: ["-v", "error", "-i", videoResult.fileURL.path, "-map", "0:v:0", "-map", "0:a:0", "-f", "null", "-"]
        )
    }

    private func configuration(url: URL, type: DownloadType, destination: URL) -> DownloadConfiguration {
        DownloadConfiguration(
            url: url,
            type: type,
            audioFormat: .mp3,
            audioQuality: .kbps320,
            videoFormat: .mp4,
            videoQuality: .best,
            destination: destination,
            deleteTemporaryFiles: true
        )
    }
}

private final class ProgressStages: @unchecked Sendable {
    private let lock = NSLock()
    private var stages: Set<DownloadStage> = []

    func insert(_ stage: DownloadStage) {
        lock.lock()
        stages.insert(stage)
        lock.unlock()
    }

    func contains(_ stage: DownloadStage) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stages.contains(stage)
    }
}
