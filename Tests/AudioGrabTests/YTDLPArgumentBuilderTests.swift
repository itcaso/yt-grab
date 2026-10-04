import Foundation
import Testing
@testable import AudioGrab

struct YTDLPArgumentBuilderTests {
    private let url = URL(string: "https://www.youtube.com/watch?v=authorized")!
    private let destination = URL(fileURLWithPath: "/tmp/AudioGrab Tests")
    private let ffmpeg = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")

    @Test func analysisUsesArgumentArrayAndNoShell() {
        let arguments = YTDLPArgumentBuilder.analysis(url: url)
        #expect(arguments.last == url.absoluteString)
        #expect(arguments.contains("--dump-single-json"))
        #expect(!arguments.contains("sh"))
        #expect(!arguments.contains("-c"))
    }

    @Test func mp3ArgumentsUseSelectedQuality() {
        let configuration = makeConfiguration(type: .audio, audioFormat: .mp3, audioQuality: .kbps320)
        let arguments = YTDLPArgumentBuilder.audio(configuration: configuration, ffmpegLocation: ffmpeg)
        #expect(value(after: "--audio-format", in: arguments) == "mp3")
        #expect(value(after: "--audio-quality", in: arguments) == "320K")
        #expect(value(after: "--paths", in: arguments) == destination.path)
        #expect(value(after: "--ffmpeg-location", in: arguments) == ffmpeg.path)
    }

    @Test func m4aArgumentsPreserveM4AOutput() {
        let configuration = makeConfiguration(type: .audio, audioFormat: .m4a, audioQuality: .kbps256)
        let arguments = YTDLPArgumentBuilder.audio(configuration: configuration)
        #expect(value(after: "--audio-format", in: arguments) == "m4a")
    }

    @Test func exactVideoHeightDoesNotSilentlyChooseLowerQuality() {
        let configuration = makeConfiguration(type: .video, videoQuality: .height(1080))
        let arguments = YTDLPArgumentBuilder.video(configuration: configuration, ffmpegLocation: ffmpeg)
        let selector = value(after: "--format", in: arguments)
        #expect(selector != nil)
        #expect(selector?.contains("height=1080") == true)
        #expect(selector?.contains("height<=1080") == false)
        #expect(value(after: "--merge-output-format", in: arguments) == "mp4")
        #expect(value(after: "--ffmpeg-location", in: arguments) == ffmpeg.path)
    }

    @Test func availableQualitiesComeOnlyFromAnalyzedFormats() {
        let metadata = MediaMetadata(
            title: "Test",
            channel: nil,
            duration: nil,
            thumbnailURL: nil,
            formats: [
                makeFormat(id: "1", height: 360),
                makeFormat(id: "2", height: 720),
                makeFormat(id: "3", height: 1080),
                makeFormat(id: "4", height: 240),
                makeFormat(id: "audio", height: nil, videoCodec: "none")
            ]
        )
        #expect(metadata.availableVideoQualities == [.best, .height(1080), .height(720), .height(360), .height(240)])
        #expect(metadata.hasDownloadableVideo)
        #expect(metadata.supports(videoQuality: .height(720)))
        #expect(!metadata.supports(videoQuality: .height(1440)))
    }

    @Test func officialChecksumFileIsParsedByExactFilename() {
        let contents = "abc123  yt-dlp\ndef456 *yt-dlp_macos\n"
        #expect(DependencyInstaller.expectedChecksum(in: contents, filename: "yt-dlp_macos") == "def456")
        #expect(DependencyInstaller.expectedChecksum(in: contents, filename: "missing") == nil)
    }

    @Test func audioOnlyMetadataRejectsEveryVideoQuality() {
        let metadata = MediaMetadata(
            title: "Audio only",
            channel: nil,
            duration: nil,
            thumbnailURL: nil,
            formats: [makeFormat(id: "audio", height: nil, videoCodec: "none")]
        )
        #expect(!metadata.hasDownloadableVideo)
        #expect(!metadata.supports(videoQuality: .best))
        #expect(!metadata.supports(videoQuality: .height(720)))
    }

    private func makeConfiguration(
        type: DownloadType,
        audioFormat: AudioFormat = .mp3,
        audioQuality: AudioQuality = .kbps320,
        videoQuality: VideoQuality = .best
    ) -> DownloadConfiguration {
        DownloadConfiguration(
            url: url,
            type: type,
            audioFormat: audioFormat,
            audioQuality: audioQuality,
            videoFormat: .mp4,
            videoQuality: videoQuality,
            destination: destination
        )
    }

    private func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private func makeFormat(id: String, height: Int?, videoCodec: String = "avc1") -> MediaFormat {
        MediaFormat(
            formatID: id,
            extensionName: "mp4",
            width: nil,
            height: height,
            fps: nil,
            videoCodec: videoCodec,
            audioCodec: "none",
            fileSize: nil,
            approximateFileSize: nil
        )
    }
}
