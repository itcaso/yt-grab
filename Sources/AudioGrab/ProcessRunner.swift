@preconcurrency import Foundation

enum ProcessRunnerError: LocalizedError {
    case launchFailed(String)
    case failed(exitCode: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message): message
        case .failed(_, let output): output.isEmpty ? L10n.text("The download tool exited unexpectedly.") : output
        }
    }
}

final class RunningProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    func set(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let activeProcess = process
        lock.unlock()
        activeProcess?.interrupt()
    }
}

private final class ProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var output = ""

    func consume(_ data: Data, onLine: @Sendable (String) -> Void) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let newline = buffer.firstRange(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newline.lowerBound)
            buffer.removeSubrange(buffer.startIndex...newline.lowerBound)
            if let line = String(data: lineData, encoding: .utf8) {
                output += line + "\n"
                lines.append(line)
            }
        }
        lock.unlock()
        lines.forEach(onLine)
    }

    func finish(with data: Data, onLine: @Sendable (String) -> Void) -> String {
        lock.lock()
        buffer.append(data)
        let remainder = buffer.isEmpty ? nil : String(data: buffer, encoding: .utf8)
        if let remainder { output += remainder }
        let finalOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeAll()
        lock.unlock()
        if let remainder { onLine(remainder) }
        return finalOutput
    }

    func appendLine(_ line: String) {
        lock.lock()
        output += line + "\n"
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return output
    }
}

enum ProcessRunner {
    static func runAndCapture(executableURL: URL, arguments: [String]) async throws -> String {
        let handle = RunningProcess()
        let collected = ProcessOutput()
        try await run(
            executableURL: executableURL,
            arguments: arguments,
            handle: handle,
            onLine: { line in collected.appendLine(line) }
        )
        return collected.string
    }

    static func run(
        executableURL: URL,
        arguments: [String],
        handle: RunningProcess,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                let pipe = Pipe()
                let output = ProcessOutput()

                process.executableURL = executableURL
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe
                handle.set(process)

                pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    output.consume(data, onLine: onLine)
                }

                process.terminationHandler = { process in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
                    let finalOutput = output.finish(with: remainder, onLine: onLine)

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else if Task.isCancelled || process.terminationReason == .uncaughtSignal {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: ProcessRunnerError.failed(
                            exitCode: process.terminationStatus,
                            output: finalOutput
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            handle.cancel()
        }
    }
}
