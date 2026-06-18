import Foundation

/// Runs `tailscale status --json` off-main and returns the filtered device list.
///
/// Graceful no-op (returns `[]`) when the Tailscale CLI is absent, not running,
/// times out, or emits output we cannot parse. Never blocks the main thread:
/// callers invoke `devices()` from a background context.
struct NewTerminalLauncherTailscaleClient: Sendable {
    /// Candidate CLI locations, in priority order. The bundled app binary first,
    /// then `tailscale` resolved via PATH-style search.
    static let candidateExecutablePaths: [String] = [
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/usr/bin/tailscale",
    ]

    private let timeout: TimeInterval

    init(timeout: TimeInterval = 6) {
        self.timeout = timeout
    }

    /// Resolve, run, parse, and filter. Returns `[]` on any failure.
    func devices() -> [NewTerminalLauncherTailscaleDevice] {
        guard let executablePath = Self.resolveExecutablePath(),
              let data = runStatus(executablePath: executablePath),
              !data.isEmpty,
              let status = try? JSONDecoder().decode(NewTerminalLauncherTailscaleStatus.self, from: data) else {
            return []
        }
        return NewTerminalLauncherTailscaleFilter.devices(from: status)
    }

    static func resolveExecutablePath() -> String? {
        if let direct = candidateExecutablePaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) {
            return direct
        }
        // Fall back to `tailscale` on PATH.
        return Self.resolveOnPath("tailscale")
    }

    private func runStatus(executablePath: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["status", "--json"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        // Drain stdout concurrently so a large payload cannot deadlock the pipe.
        let collected = OutputCollector()
        let handle = stdout.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let chunk = fileHandle.availableData
            if chunk.isEmpty {
                fileHandle.readabilityHandler = nil
            } else {
                collected.append(chunk)
            }
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            handle.readabilityHandler = nil
            return nil
        }

        // Read anything still buffered after termination.
        let remaining = (try? handle.readToEnd()) ?? Data()
        handle.readabilityHandler = nil
        if !remaining.isEmpty {
            collected.append(remaining)
        }

        guard process.terminationStatus == 0 else { return nil }
        return collected.data
    }

    private static func resolveOnPath(_ name: String) -> String? {
        let pathValue = ProcessInfo.processInfo.environment["PATH"]
            ?? "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        for directory in pathValue.split(separator: ":") {
            let candidate = (String(directory) as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

/// Thread-safe accumulator for piped output.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ chunk: Data) {
        lock.lock()
        buffer.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
