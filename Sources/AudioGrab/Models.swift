import Foundation

enum DownloadType: String, CaseIterable, Codable, Identifiable {
    case audio
    case video

    var id: String { rawValue }
    var title: String { L10n.text(rawValue.capitalized) }
    var symbol: String { self == .audio ? "music.note" : "film" }
    var folderName: String { title }
}

enum AudioFormat: String, CaseIterable, Codable, Identifiable {
    case mp3 = "MP3"
    case m4a = "M4A"
    var id: String { rawValue }
}

enum AudioQuality: Int, CaseIterable, Codable, Identifiable {
    case kbps128 = 128
    case kbps192 = 192
    case kbps256 = 256
    case kbps320 = 320
    var id: Int { rawValue }
    var title: String { "\(rawValue) kbps" }
}

enum VideoFormat: String, CaseIterable, Codable, Identifiable {
    case mp4 = "MP4"
    var id: String { rawValue }
}

enum VideoQuality: Hashable, Codable, Identifiable, Comparable {
    case best
    case height(Int)

    var id: String {
        switch self {
        case .best: "best"
        case .height(let value): "\(value)p"
        }
    }

    var title: String {
        switch self {
        case .best: L10n.text("Best Available")
        case .height(let value): value == 2160 ? "2160p / 4K" : "\(value)p"
        }
    }

    static func < (lhs: VideoQuality, rhs: VideoQuality) -> Bool {
        lhs.sortValue < rhs.sortValue
    }

    private var sortValue: Int {
        switch self {
        case .best: Int.max
        case .height(let value): value
        }
    }
}

struct MediaFormat: Codable, Hashable, Identifiable {
    let formatID: String
    let extensionName: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let videoCodec: String?
    let audioCodec: String?
    let fileSize: Int64?
    let approximateFileSize: Int64?

    var id: String { formatID }
    var hasVideo: Bool { videoCodec != nil && videoCodec != "none" }
    var hasAudio: Bool { audioCodec != nil && audioCodec != "none" }
}

struct MediaMetadata: Codable, Hashable {
    let title: String
    let channel: String?
    let duration: Double?
    let thumbnailURL: URL?
    let formats: [MediaFormat]

    var availableVideoQualities: [VideoQuality] {
        let heights = Set(formats.compactMap { format -> Int? in
            guard format.hasVideo, let height = format.height, height > 0 else { return nil }
            return height
        })
        return [.best] + heights.sorted(by: >).map(VideoQuality.height)
    }

    var hasDownloadableVideo: Bool {
        formats.contains(where: \.hasVideo)
    }

    func supports(videoQuality: VideoQuality) -> Bool {
        guard hasDownloadableVideo else { return false }
        return videoQuality == .best || availableVideoQualities.contains(videoQuality)
    }
}

enum DownloadStage: String, Codable {
    case idle
    case downloading = "Downloading"
    case downloadingVideo = "Downloading Video"
    case downloadingAudio = "Downloading Audio"
    case merging = "Merging Audio & Video"
    case processing = "Processing"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case failed = "Failed"

    var title: String { L10n.text(rawValue) }
}

struct DownloadResult: Equatable {
    let fileURL: URL
    let size: Int64?
}

struct HistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let type: DownloadType
    let details: String
    let fileURL: URL
    let fileSize: Int64?
    let completedAt: Date

    init(title: String, type: DownloadType, details: String, fileURL: URL, fileSize: Int64?) {
        id = UUID()
        self.title = title
        self.type = type
        self.details = details
        self.fileURL = fileURL
        self.fileSize = fileSize
        completedAt = Date()
    }

    var fileExists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }
}

struct DownloadConfiguration {
    let url: URL
    let type: DownloadType
    let audioFormat: AudioFormat
    let audioQuality: AudioQuality
    let videoFormat: VideoFormat
    let videoQuality: VideoQuality
    let destination: URL
}
