import Foundation

struct DependencyStatus: Equatable {
    let name: String
    let executableURL: URL?
    let version: String?

    var isInstalled: Bool { executableURL != nil }
}

struct DependencyManager {
    static var searchDirectories: [String] {
        [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin", isDirectory: true).path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
    }

    func find(_ name: String) -> URL? {
        for directory in Self.searchDirectories {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    func status(for name: String, versionArguments: [String] = ["--version"]) async -> DependencyStatus {
        guard let executableURL = find(name) else {
            return DependencyStatus(name: name, executableURL: nil, version: nil)
        }

        let version = try? await ProcessRunner.runAndCapture(
            executableURL: executableURL,
            arguments: versionArguments
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return DependencyStatus(
            name: name,
            executableURL: executableURL,
            version: version?.components(separatedBy: .newlines).first
        )
    }
}
