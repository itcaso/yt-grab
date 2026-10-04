import Foundation

struct YTDLPResponse: Decodable {
    let title: String
    let channel: String?
    let uploader: String?
    let duration: Double?
    let thumbnail: String?
    let formats: [YTDLPFormatResponse]?
}

struct YTDLPFormatResponse: Decodable {
    let formatID: String
    let ext: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int64?
    let filesizeApprox: Int64?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case ext, width, height, fps, vcodec, acodec, filesize
        case filesizeApprox = "filesize_approx"
    }
}

extension YTDLPResponse {
    func metadata() -> MediaMetadata {
        MediaMetadata(
            title: title,
            channel: channel ?? uploader,
            duration: duration,
            thumbnailURL: thumbnail.flatMap(URL.init(string:)),
            formats: (formats ?? []).map {
                MediaFormat(
                    formatID: $0.formatID,
                    extensionName: $0.ext,
                    width: $0.width,
                    height: $0.height,
                    fps: $0.fps,
                    videoCodec: $0.vcodec,
                    audioCodec: $0.acodec,
                    fileSize: $0.filesize,
                    approximateFileSize: $0.filesizeApprox
                )
            }
        )
    }
}
