import AppKit
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let baseDirectory = "baseDirectory"
        static let organizeByType = "organizeByType"
        static let audioFormat = "audioFormat"
        static let audioQuality = "audioQuality"
        static let videoQuality = "videoQuality"
        static let deleteTemporaryFiles = "deleteTemporaryFiles"
        static let showNotifications = "showNotifications"
    }

    private let defaults = UserDefaults.standard

    @Published var baseDirectory: URL {
        didSet { defaults.set(baseDirectory.path, forKey: Key.baseDirectory) }
    }
    @Published var organizeByType: Bool {
        didSet { defaults.set(organizeByType, forKey: Key.organizeByType) }
    }
    @Published var defaultAudioFormat: AudioFormat {
        didSet { defaults.set(defaultAudioFormat.rawValue, forKey: Key.audioFormat) }
    }
    @Published var defaultAudioQuality: AudioQuality {
        didSet { defaults.set(defaultAudioQuality.rawValue, forKey: Key.audioQuality) }
    }
    @Published var defaultVideoQuality: VideoQuality {
        didSet { defaults.set(defaultVideoQuality.id, forKey: Key.videoQuality) }
    }
    @Published var deleteTemporaryFiles: Bool {
        didSet { defaults.set(deleteTemporaryFiles, forKey: Key.deleteTemporaryFiles) }
    }
    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: Key.showNotifications) }
    }

    init() {
        let defaultPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YT-Grab", isDirectory: true)
        baseDirectory = defaults.string(forKey: Key.baseDirectory).map(URL.init(fileURLWithPath:)) ?? defaultPath
        organizeByType = defaults.object(forKey: Key.organizeByType) as? Bool ?? true
        defaultAudioFormat = defaults.string(forKey: Key.audioFormat).flatMap(AudioFormat.init(rawValue:)) ?? .mp3
        defaultAudioQuality = defaults.object(forKey: Key.audioQuality)
            .flatMap { $0 as? Int }
            .flatMap(AudioQuality.init(rawValue:)) ?? .kbps320
        defaultVideoQuality = .best
        deleteTemporaryFiles = defaults.object(forKey: Key.deleteTemporaryFiles) as? Bool ?? true
        showNotifications = defaults.object(forKey: Key.showNotifications) as? Bool ?? true
    }

    func destination(for type: DownloadType) -> URL {
        organizeByType ? baseDirectory.appendingPathComponent(type.folderName, isDirectory: true) : baseDirectory
    }

    func chooseBaseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = baseDirectory
        panel.prompt = L10n.text("Choose")
        if panel.runModal() == .OK, let selected = panel.url {
            baseDirectory = selected
        }
    }
}
