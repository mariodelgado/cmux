import Foundation

@MainActor
final class SidebarAIInsightCoordinator {
    private struct Key: Hashable {
        let workspaceId: UUID
        let panelId: UUID
    }

    private struct Entry {
        var latestFingerprint: String?
        var cachedSummary: String?
        var cachedSummaryFingerprint: String?
        var cachedStatus: AIPaneStatus?
        var cachedStatusFingerprint: String?
        var pendingFingerprint: String?
        var pendingRequestID: UUID?
        var lastRequestedAt: Date?
    }

    private struct Candidate {
        let key: Key
        weak var workspace: Workspace?
        let sampleText: String
        let latestLine: String?
        let observedAt: Date
        let priority: UInt64
        let requestID: UUID
    }

    private static let minimumRequestInterval: TimeInterval = 9

    private let router: AIRouter
    private let notificationStore: TerminalNotificationStore
    private var entries: [Key: Entry] = [:]
    private var queuedCandidates: [Key: Candidate] = [:]
    private var workerTask: Task<Void, Never>?
    private var focusedWorkspaceId: UUID?

    init(
        router: AIRouter = .shared,
        notificationStore: TerminalNotificationStore? = nil
    ) {
        self.router = router
        self.notificationStore = notificationStore ?? .shared
    }

    func configure(focusedWorkspaceId: UUID?) {
        self.focusedWorkspaceId = focusedWorkspaceId
    }

    func stop() {
        workerTask?.cancel()
        workerTask = nil
        entries.removeAll()
        queuedCandidates.removeAll()
        focusedWorkspaceId = nil
    }

    func cachedSummary(workspaceId: UUID, panelId: UUID, sampleText: String?) -> String? {
        guard AIFeatureSettings.isEnabled(),
              let sampleText,
              let entry = entries[Key(workspaceId: workspaceId, panelId: panelId)],
              entry.cachedSummaryFingerprint == sampleText else { return nil }
        return entry.cachedSummary
    }

    func observeSample(
        workspace: Workspace,
        panelId: UUID,
        sampleText: String?,
        latestLine: String?,
        now: Date,
        priority: UInt64
    ) {
        let key = Key(workspaceId: workspace.id, panelId: panelId)
        guard let sampleText, AIFeatureSettings.isEnabled() else {
            entries.removeValue(forKey: key)
            queuedCandidates.removeValue(forKey: key)
            notificationStore.applyAIPaneStatus(
                .working,
                tabId: workspace.id,
                surfaceId: panelId,
                panelId: panelId,
                summary: nil
            )
            return
        }

        var entry = entries[key] ?? Entry()
        entry.latestFingerprint = sampleText
        let hasCachedSummary = entry.cachedSummaryFingerprint == sampleText
        let hasCachedStatus = entry.cachedStatusFingerprint == sampleText
        if hasCachedSummary, hasCachedStatus {
            entries[key] = entry
            return
        }
        if entry.pendingFingerprint == sampleText {
            entries[key] = entry
            return
        }
        if let lastRequestedAt = entry.lastRequestedAt,
           now.timeIntervalSince(lastRequestedAt) < Self.minimumRequestInterval {
            entries[key] = entry
            return
        }

        let requestID = UUID()
        entry.pendingFingerprint = sampleText
        entry.pendingRequestID = requestID
        entry.lastRequestedAt = now
        entries[key] = entry
        queuedCandidates[key] = Candidate(
            key: key,
            workspace: workspace,
            sampleText: sampleText,
            latestLine: latestLine,
            observedAt: now,
            priority: priority,
            requestID: requestID
        )
        startWorkerIfNeeded()
    }

    private func startWorkerIfNeeded() {
        guard workerTask == nil else { return }
        workerTask = Task { @MainActor [weak self] in
            await self?.processQueuedCandidates()
        }
    }

    private func processQueuedCandidates() async {
        defer { workerTask = nil }
        while !Task.isCancelled, let candidate = nextCandidate() {
            queuedCandidates.removeValue(forKey: candidate.key)
            guard entries[candidate.key]?.pendingRequestID == candidate.requestID else { continue }

            let summary = await router.summarizeTerminalOutput(text: candidate.sampleText)
            guard !Task.isCancelled else { return }
            let status = await router.classifyTerminalOutput(text: candidate.sampleText)
            guard !Task.isCancelled else { return }

            applyResult(summary: summary, status: status, for: candidate)
        }
    }

    private func nextCandidate() -> Candidate? {
        queuedCandidates.values.max { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.observedAt < rhs.observedAt
        }
    }

    private func applyResult(summary: String?, status: AIPaneStatus?, for candidate: Candidate) {
        guard var entry = entries[candidate.key],
              entry.pendingRequestID == candidate.requestID,
              entry.pendingFingerprint == candidate.sampleText,
              entry.latestFingerprint == candidate.sampleText else { return }

        entry.pendingFingerprint = nil
        entry.pendingRequestID = nil
        if let summary {
            entry.cachedSummary = summary
            entry.cachedSummaryFingerprint = candidate.sampleText
        }
        if let status {
            entry.cachedStatus = status
            entry.cachedStatusFingerprint = candidate.sampleText
        }
        entries[candidate.key] = entry

        if let summary,
           let workspace = candidate.workspace,
           workspace.id != focusedWorkspaceId {
            workspace.updateSidebarRollingOutputPreview(
                text: summary,
                sourcePanelId: candidate.key.panelId,
                now: Date()
            )
        }

        notificationStore.applyAIPaneStatus(
            status ?? .working,
            tabId: candidate.key.workspaceId,
            surfaceId: candidate.key.panelId,
            panelId: candidate.key.panelId,
            summary: summary ?? candidate.latestLine
        )
    }
}
