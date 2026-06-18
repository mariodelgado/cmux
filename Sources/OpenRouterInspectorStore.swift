import Foundation
import Observation

@MainActor
@Observable
final class OpenRouterInspectorStore {
    private enum ActionKind {
        case switchNow
        case setDefault
    }

    var snapshot = OpenRouterInspectorSnapshot.empty
    var isLoading = false
    var isRunningAction = false
    var lastErrorMessage: String?
    var actionMessage: String?
    var actionIsError = false
    var lastUpdated: Date?

    @ObservationIgnored private let service: OpenRouterInspectorSSHService
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var activeHost: String?

    init(service: OpenRouterInspectorSSHService = OpenRouterInspectorSSHService()) {
        self.service = service
    }

    deinit {
        refreshTask?.cancel()
    }

    func synchronize(isActive: Bool, host: String) {
        let normalizedHost = Self.normalizedHost(host)
        guard isActive else {
            stop()
            return
        }
        guard !normalizedHost.isEmpty else {
            stop()
            snapshot = .empty
            lastErrorMessage = OpenRouterInspectorSSHError.blankHost.errorDescription
            return
        }
        guard refreshTask == nil || activeHost != normalizedHost else { return }
        stop()
        activeHost = normalizedHost
        refreshTask = Task { [weak self] in
            var force = true
            while !Task.isCancelled {
                await self?.refresh(host: normalizedHost, force: force)
                force = false
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        activeHost = nil
        isLoading = false
    }

    func refreshNow(host: String) {
        let normalizedHost = Self.normalizedHost(host)
        Task { [weak self] in
            await self?.refresh(host: normalizedHost, force: true)
        }
    }

    func switchNow(session: OpenRouterInspectorSession, target: String, host: String) {
        guard let window = session.window else {
            actionMessage = String(localized: "openRouterInspector.switch.missingWindow", defaultValue: "This session has no tmux window number.")
            actionIsError = true
            return
        }
        let normalizedHost = Self.normalizedHost(host)
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        isRunningAction = true
        actionMessage = String(localized: "openRouterInspector.switch.running", defaultValue: "Switching model...")
        actionIsError = false
        Task { [weak self, service] in
            let outcome = await service.switchNow(
                host: normalizedHost,
                session: session.session,
                window: window,
                target: target
            )
            await self?.applyActionOutcome(
                outcome,
                kind: .switchNow,
                refreshHost: normalizedHost
            )
        }
    }

    func setDefault(target: String, host: String) {
        let normalizedHost = Self.normalizedHost(host)
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        isRunningAction = true
        actionMessage = String(localized: "openRouterInspector.default.running", defaultValue: "Setting default...")
        actionIsError = false
        Task { [weak self, service] in
            let outcome = await service.setDefault(host: normalizedHost, target: target)
            await self?.applyActionOutcome(
                outcome,
                kind: .setDefault,
                refreshHost: normalizedHost
            )
        }
    }

    private func refresh(host: String, force: Bool) async {
        guard !host.isEmpty else {
            lastErrorMessage = OpenRouterInspectorSSHError.blankHost.errorDescription
            return
        }
        isLoading = true
        do {
            let nextSnapshot = try await service.inspect(host: host, force: force)
            guard !Task.isCancelled else { return }
            snapshot = nextSnapshot
            lastUpdated = nextSnapshot.receivedAt
            lastErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            lastErrorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func applyActionOutcome(
        _ outcome: OpenRouterInspectorCommandOutcome,
        kind: ActionKind,
        refreshHost: String
    ) async {
        isRunningAction = false
        if outcome.isSuccess {
            actionIsError = false
            actionMessage = outcome.stdout.nilIfBlank ?? successMessage(for: kind)
            await refresh(host: refreshHost, force: true)
            return
        }

        actionIsError = true
        let detail = Self.failureDetail(from: outcome)
        actionMessage = failureMessage(for: kind, detail: detail)
    }

    private func successMessage(for kind: ActionKind) -> String {
        switch kind {
        case .switchNow:
            return String(localized: "openRouterInspector.switch.success", defaultValue: "Switched model and requested restart + resume.")
        case .setDefault:
            return String(localized: "openRouterInspector.default.success", defaultValue: "Default updated for the next session.")
        }
    }

    private func failureMessage(for kind: ActionKind, detail: String) -> String {
        switch kind {
        case .switchNow:
            return String.localizedStringWithFormat(
                String(localized: "openRouterInspector.switch.failed", defaultValue: "Model switch failed: %@"),
                detail
            )
        case .setDefault:
            return String.localizedStringWithFormat(
                String(localized: "openRouterInspector.default.failed", defaultValue: "Default update failed: %@"),
                detail
            )
        }
    }

    private static func failureDetail(from outcome: OpenRouterInspectorCommandOutcome) -> String {
        if let executionError = outcome.executionError?.nilIfBlank {
            return executionError
        }
        if outcome.timedOut {
            return String(localized: "openRouterInspector.error.timedOut", defaultValue: "SSH command timed out.")
        }
        if let stderr = outcome.stderr.nilIfBlank {
            return stderr
        }
        if let stdout = outcome.stdout.nilIfBlank {
            return stdout
        }
        return String.localizedStringWithFormat(
            String(localized: "openRouterInspector.error.exitStatus", defaultValue: "Exit status %@"),
            outcome.exitStatus.map(String.init) ?? String(localized: "openRouterInspector.error.noStatus", defaultValue: "unknown")
        )
    }

    private static func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
