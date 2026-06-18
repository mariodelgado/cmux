import CmuxProcess
import Foundation

nonisolated enum OpenRouterInspectorSSHError: Error, LocalizedError, Sendable {
    case blankHost
    case timedOut
    case launchFailure(String)
    case commandFailed(status: Int32?, stderr: String)
    case emptyOutput
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .blankHost:
            return String(localized: "openRouterInspector.error.blankHost", defaultValue: "Inspector host is empty.")
        case .timedOut:
            return String(localized: "openRouterInspector.error.timedOut", defaultValue: "SSH command timed out.")
        case .launchFailure(let message):
            return String.localizedStringWithFormat(
                String(localized: "openRouterInspector.error.launchFailure", defaultValue: "SSH failed to start: %@"),
                message
            )
        case .commandFailed(let status, let stderr):
            let statusText = status.map(String.init) ?? String(localized: "openRouterInspector.error.noStatus", defaultValue: "unknown")
            let detail = stderr.nilIfBlank ?? String(localized: "openRouterInspector.error.noOutput", defaultValue: "No error output.")
            return String.localizedStringWithFormat(
                String(localized: "openRouterInspector.error.commandFailed", defaultValue: "SSH exited %@: %@"),
                statusText,
                detail
            )
        case .emptyOutput:
            return String(localized: "openRouterInspector.error.emptyOutput", defaultValue: "Inspector returned no JSON.")
        case .invalidJSON(let message):
            return String.localizedStringWithFormat(
                String(localized: "openRouterInspector.error.invalidJSON", defaultValue: "Inspector JSON could not be parsed: %@"),
                message
            )
        }
    }
}

actor OpenRouterInspectorSSHService {
    private static let inspectorScriptPath = "~/.tmux/cc-inspector.sh"
    private static let switchScriptPath = "~/.tmux/cc-switch.sh"

    private let commandRunner: any CommandRunning
    private let minimumRefreshInterval: TimeInterval
    private let inspectTimeout: TimeInterval
    private let actionTimeout: TimeInterval

    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var lastInspectStartedAt: Date?

    init(
        commandRunner: any CommandRunning = CommandRunner(),
        minimumRefreshInterval: TimeInterval = 5,
        inspectTimeout: TimeInterval = 12,
        actionTimeout: TimeInterval = 20
    ) {
        self.commandRunner = commandRunner
        self.minimumRefreshInterval = minimumRefreshInterval
        self.inspectTimeout = inspectTimeout
        self.actionTimeout = actionTimeout
    }

    func inspect(host: String, force: Bool = false) async throws -> OpenRouterInspectorSnapshot {
        try await runQueued {
            let host = host.trimmedForCommand
            guard !host.isEmpty else { throw OpenRouterInspectorSSHError.blankHost }
            try await self.waitForRefreshThrottleIfNeeded(force: force)
            self.lastInspectStartedAt = Date()
            let result = await self.commandRunner.run(
                directory: FileManager.default.homeDirectoryForCurrentUser.path,
                executable: "ssh",
                arguments: Self.inspectArguments(host: host),
                timeout: self.inspectTimeout
            )
            return try Self.parseInspectionResult(result, receivedAt: Date())
        }
    }

    func switchNow(
        host: String,
        session: String,
        window: Int,
        target: String
    ) async -> OpenRouterInspectorCommandOutcome {
        await runQueued {
            let host = host.trimmedForCommand
            guard !host.isEmpty else { return Self.errorOutcome(OpenRouterInspectorSSHError.blankHost) }
            let result = await self.commandRunner.run(
                directory: FileManager.default.homeDirectoryForCurrentUser.path,
                executable: "ssh",
                arguments: Self.switchNowArguments(
                    host: host,
                    session: session,
                    window: window,
                    target: target
                ),
                timeout: self.actionTimeout
            )
            return Self.outcome(from: result)
        }
    }

    func setDefault(host: String, target: String) async -> OpenRouterInspectorCommandOutcome {
        await runQueued {
            let host = host.trimmedForCommand
            guard !host.isEmpty else { return Self.errorOutcome(OpenRouterInspectorSSHError.blankHost) }
            let result = await self.commandRunner.run(
                directory: FileManager.default.homeDirectoryForCurrentUser.path,
                executable: "ssh",
                arguments: Self.defaultArguments(host: host, target: target),
                timeout: self.actionTimeout
            )
            return Self.outcome(from: result)
        }
    }

    nonisolated static func inspectArguments(host: String) -> [String] {
        [host.trimmedForCommand, inspectorScriptPath]
    }

    nonisolated static func switchNowArguments(
        host: String,
        session: String,
        window: Int,
        target: String
    ) -> [String] {
        [
            host.trimmedForCommand,
            [
                switchScriptPath,
                shellQuotedArgument(session),
                String(window),
                "restart",
                shellQuotedArgument(target),
            ].joined(separator: " "),
        ]
    }

    nonisolated static func defaultArguments(host: String, target: String) -> [String] {
        [
            host.trimmedForCommand,
            [
                switchScriptPath,
                "default",
                shellQuotedArgument(target),
            ].joined(separator: " "),
        ]
    }

    nonisolated static func shellQuotedArgument(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func waitForRefreshThrottleIfNeeded(force: Bool) async throws {
        guard !force,
              minimumRefreshInterval > 0,
              let lastInspectStartedAt else {
            return
        }
        let remaining = minimumRefreshInterval - Date().timeIntervalSince(lastInspectStartedAt)
        guard remaining > 0 else { return }
        let nanoseconds = UInt64(remaining * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    private func runQueued<T: Sendable>(_ operation: @escaping () async throws -> T) async throws -> T {
        await waitForTurn()
        defer { finishTurn() }
        guard !Task.isCancelled else { throw CancellationError() }
        return try await operation()
    }

    private func runQueued<T: Sendable>(_ operation: @escaping () async -> T) async -> T {
        await waitForTurn()
        defer { finishTurn() }
        return await operation()
    }

    private func waitForTurn() async {
        if !isRunning {
            isRunning = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func finishTurn() {
        guard !waiters.isEmpty else {
            isRunning = false
            return
        }
        let continuation = waiters.removeFirst()
        continuation.resume()
    }

    private nonisolated static func parseInspectionResult(
        _ result: CommandResult,
        receivedAt: Date
    ) throws -> OpenRouterInspectorSnapshot {
        if result.timedOut { throw OpenRouterInspectorSSHError.timedOut }
        if let executionError = result.executionError {
            throw OpenRouterInspectorSSHError.launchFailure(executionError)
        }
        guard result.exitStatus == 0 else {
            throw OpenRouterInspectorSSHError.commandFailed(
                status: result.exitStatus,
                stderr: result.stderr ?? ""
            )
        }
        guard let stdout = result.stdout?.nilIfBlank else {
            throw OpenRouterInspectorSSHError.emptyOutput
        }
        do {
            return try OpenRouterInspectorSnapshot.decode(stdout: stdout, receivedAt: receivedAt)
        } catch {
            throw OpenRouterInspectorSSHError.invalidJSON(String(describing: error))
        }
    }

    private nonisolated static func outcome(from result: CommandResult) -> OpenRouterInspectorCommandOutcome {
        OpenRouterInspectorCommandOutcome(
            exitStatus: result.exitStatus,
            stdout: result.stdout ?? "",
            stderr: result.stderr ?? "",
            timedOut: result.timedOut,
            executionError: result.executionError
        )
    }

    private nonisolated static func errorOutcome(_ error: OpenRouterInspectorSSHError) -> OpenRouterInspectorCommandOutcome {
        OpenRouterInspectorCommandOutcome(
            exitStatus: nil,
            stdout: "",
            stderr: "",
            timedOut: false,
            executionError: error.errorDescription
        )
    }
}

private extension String {
    var trimmedForCommand: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
