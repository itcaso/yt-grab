import CryptoKit
import Foundation

enum DependencyInstallerError: LocalizedError {
    case invalidResponse
    case checksumMissing
    case checksumMismatch
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            L10n.text("The yt-dlp download server returned an invalid response.")
        case .checksumMissing:
            L10n.text("The official checksum for yt-dlp could not be found.")
        case .checksumMismatch:
            L10n.text("The yt-dlp download did not pass its security verification.")
        case .verificationFailed:
            L10n.text("yt-dlp was installed, but it could not be started.")
        }
    }
}

struct DependencyInstaller: Sendable {
    private let binaryURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
    private let checksumsURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS")!

    func installYTDLP() async throws -> String {
        async let binaryDownload = URLSession.shared.data(from: binaryURL)
        async let checksumDownload = URLSession.shared.data(from: checksumsURL)
        let ((binary, binaryResponse), (checksums, checksumsResponse)) = try await (binaryDownload, checksumDownload)

        guard Self.isSuccessful(binaryResponse), Self.isSuccessful(checksumsResponse),
              let checksumText = String(data: checksums, encoding: .utf8) else {
            throw DependencyInstallerError.invalidResponse
        }
        guard let expected = Self.expectedChecksum(in: checksumText, filename: "yt-dlp_macos") else {
            throw DependencyInstallerError.checksumMissing
        }

        let actual = SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw DependencyInstallerError.checksumMismatch
        }

        let fileManager = FileManager.default
        let binDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin", isDirectory: true)
        try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)

        let destination = binDirectory.appendingPathComponent("yt-dlp")
        let temporary = binDirectory.appendingPathComponent(".yt-dlp-download-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporary) }

        try binary.write(to: temporary, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }

        let version = try await ProcessRunner.runAndCapture(
            executableURL: destination,
            arguments: ["--version"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else { throw DependencyInstallerError.verificationFailed }
        return version
    }

    static func expectedChecksum(in contents: String, filename: String) -> String? {
        for line in contents.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2 else { continue }
            let listedName = fields.last.map(String.init)?.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
            if listedName == filename { return String(fields[0]) }
        }
        return nil
    }

    private static func isSuccessful(_ response: URLResponse) -> Bool {
        guard let response = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(response.statusCode)
    }
}
