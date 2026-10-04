import Foundation

enum YTDLPArgumentBuilder {
    static func analysis(url: URL) -> [String] {
        [
            "--dump-single-json",
            "--no-playlist",
            "--no-color",
            "--skip-download",
            "--no-warnings",
            url.absoluteString
        ]
    }

    static func audio(configuration: DownloadConfiguration, ffmpegLocation: URL? = nil) -> [String] {
        var arguments = commonDownloadArguments(
            destination: configuration.destination,
            ffmpegLocation: ffmpegLocation
        )

        switch configuration.audioFormat {
        case .mp3:
            arguments += [
                "--extract-audio",
                "--audio-format", "mp3",
                "--audio-quality", "\(configuration.audioQuality.rawValue)K"
            ]
        case .m4a:
            arguments += [
                "--extract-audio",
                "--audio-format", "m4a",
                "--audio-quality", "0"
            ]
        }

        arguments.append(configuration.url.absoluteString)
        return arguments
    }

    static func video(configuration: DownloadConfiguration, ffmpegLocation: URL? = nil) -> [String] {
        var arguments = commonDownloadArguments(
            destination: configuration.destination,
            ffmpegLocation: ffmpegLocation
        )
        let selector: String

        switch configuration.videoQuality {
        case .best:
            selector = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best"
        case .height(let height):
            selector = "bestvideo[height=\(height)][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height=\(height)]+bestaudio/best[height=\(height)]"
        }

        arguments += [
            "--format", selector,
            "--merge-output-format", "mp4",
            "--remux-video", "mp4",
            configuration.url.absoluteString
        ]
        return arguments
    }

    private static func commonDownloadArguments(destination: URL, ffmpegLocation: URL?) -> [String] {
        var arguments = [
            "--no-playlist",
            "--newline",
            "--progress",
            "--progress-template", "download:%(progress._percent_str)s|%(progress.speed)s|%(progress.eta)s",
            "--print", "after_move:filepath:%(filepath)s",
            "--paths", destination.path,
            "--output", "%(title)s.%(ext)s",
            "--windows-filenames"
        ]
        if let ffmpegLocation {
            arguments += ["--ffmpeg-location", ffmpegLocation.path]
        }
        return arguments
    }
}
