import Foundation
import Testing
@testable import AudioGrab

@MainActor
struct HistoryStoreTests {
    @Test func removingEntriesPersistsWithoutDeletingDownloadedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YT-Grab-HistoryTests-\(UUID().uuidString)", isDirectory: true)
        let historyURL = root.appendingPathComponent("history.json")
        let downloadedFile = root.appendingPathComponent("downloaded-video.mp4")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("media".utf8).write(to: downloadedFile)
        defer { try? FileManager.default.removeItem(at: root) }

        let audio = HistoryItem(
            title: "Audio",
            type: .audio,
            details: "MP3 · 320 kbps",
            fileURL: root.appendingPathComponent("audio.mp3"),
            fileSize: 5
        )
        let video = HistoryItem(
            title: "Video",
            type: .video,
            details: "MP4 · 1080p",
            fileURL: downloadedFile,
            fileSize: 5
        )

        let store = HistoryStore(historyURL: historyURL)
        store.add(audio)
        store.add(video)
        store.remove(audio)

        #expect(store.items.map(\.id) == [video.id])
        #expect(FileManager.default.fileExists(atPath: downloadedFile.path))

        let reloaded = HistoryStore(historyURL: historyURL)
        #expect(reloaded.items.map(\.id) == [video.id])
        reloaded.clear()

        #expect(reloaded.items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: downloadedFile.path))
        #expect(HistoryStore(historyURL: historyURL).items.isEmpty)
    }
}
