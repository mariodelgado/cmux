import Foundation

@MainActor
final class SidebarRollingOutputPreviewSampler {
    private static let coalesceInterval: TimeInterval = 0.28

    private var workspaces: [Workspace] = []
    private var focusedWorkspaceId: UUID?
    private var tickObserver: NSObjectProtocol?
    private var releaseTickNotifications: (() -> Void)?
    private var pendingSampleTask: Task<Void, Never>?
    private var lastSampledAt: Date?
    private let formatter = SidebarRollingOutputPreviewFormatter()

    func configure(workspaces: [Workspace], focusedWorkspaceId: UUID?) {
        self.workspaces = workspaces
        self.focusedWorkspaceId = focusedWorkspaceId

        guard workspaces.contains(where: { $0.id != focusedWorkspaceId }) else {
            stopObserving()
            return
        }

        startObserving()
        scheduleSample(allowsImmediate: true)
    }

    func stop() {
        workspaces = []
        focusedWorkspaceId = nil
        stopObserving()
    }

    private func startObserving() {
        if releaseTickNotifications == nil {
            releaseTickNotifications = GhosttyApp.retainTickNotifications()
        }
        guard tickObserver == nil else { return }
        tickObserver = NotificationCenter.default.addObserver(
            forName: .ghosttyDidTick,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleSample()
            }
        }
    }

    private func stopObserving() {
        if let tickObserver {
            NotificationCenter.default.removeObserver(tickObserver)
            self.tickObserver = nil
        }
        releaseTickNotifications?()
        releaseTickNotifications = nil
        pendingSampleTask?.cancel()
        pendingSampleTask = nil
        lastSampledAt = nil
    }

    private func scheduleSample(allowsImmediate: Bool = false) {
        guard pendingSampleTask == nil else { return }

        let delay: TimeInterval
        if allowsImmediate {
            delay = 0
        } else if let lastSampledAt {
            delay = max(0, Self.coalesceInterval - Date().timeIntervalSince(lastSampledAt))
        } else {
            delay = 0
        }

        pendingSampleTask = Task { @MainActor [weak self] in
            if delay > 0 {
                // Coalescing deadline for Ghostty tick bursts; canceled when the sidebar stops sampling.
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.pendingSampleTask = nil
            self?.sampleBackgroundWorkspaces()
        }
    }

    private func sampleBackgroundWorkspaces() {
        let focusedWorkspaceId = self.focusedWorkspaceId
        let now = Date()
        lastSampledAt = now

        var seenWorkspaceIds = Set<UUID>()
        for workspace in workspaces where seenWorkspaceIds.insert(workspace.id).inserted {
            guard workspace.id != focusedWorkspaceId else { continue }
            guard let terminalPanel = workspace.terminalPanelForSidebarRollingOutputPreview() else {
                workspace.updateSidebarRollingOutputPreview(text: nil, sourcePanelId: nil, now: now)
                continue
            }

            let rawText = terminalPanel.surface.screenText() ?? terminalPanel.surface.visibleText()
            let latestLine = rawText.flatMap(formatter.latestLine)
            workspace.updateSidebarRollingOutputPreview(
                text: latestLine,
                sourcePanelId: latestLine == nil ? nil : terminalPanel.id,
                now: now
            )
        }
    }
}
