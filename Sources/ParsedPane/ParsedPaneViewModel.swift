import Foundation

@MainActor
final class ParsedPaneViewModel: ObservableObject {
    private static let coalesceInterval: TimeInterval = 0.28
    private static let maxParsedLines = 5_000
    private static let maxParsedCharacters = 350_000

    @Published private(set) var snapshot: ParsedPaneRenderSnapshot?
    @Published private(set) var isParsing = false

    private weak var panel: TerminalPanel?
    private var isActive = false
    private var isVisible = false
    private var tickObserver: NSObjectProtocol?
    private var releaseTickNotifications: (() -> Void)?
    private var pendingSampleTask: Task<Void, Never>?
    private var parseTask: Task<Void, Never>?
    private var lastSampledAt: Date?
    private var lastRawText: String?
    private var parseGeneration: UInt64 = 0

    deinit {
        if let tickObserver {
            NotificationCenter.default.removeObserver(tickObserver)
        }
        releaseTickNotifications?()
        pendingSampleTask?.cancel()
        parseTask?.cancel()
    }

    func configure(panel: TerminalPanel, isActive: Bool, isVisible: Bool) {
        self.panel = panel
        self.isActive = isActive
        self.isVisible = isVisible

        guard isActive && isVisible else {
            stopObserving()
            return
        }

        startObserving()
        scheduleSample(allowsImmediate: true)
    }

    func stop() {
        isActive = false
        isVisible = false
        stopObserving()
        parseTask?.cancel()
        parseTask = nil
        isParsing = false
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
        guard isActive && isVisible else { return }
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
                // Coalesces Ghostty tick bursts; canceled when the pane leaves Parsed mode.
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.pendingSampleTask = nil
            self?.sampleNow()
        }
    }

    private func sampleNow() {
        guard isActive && isVisible, let panel else { return }
        lastSampledAt = Date()
        guard let rawText = sampledText(from: panel),
              !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            parseTask?.cancel()
            parseTask = nil
            lastRawText = nil
            snapshot = nil
            isParsing = false
            return
        }
        let trimmedRawText = Self.tail(rawText)
        guard trimmedRawText != lastRawText else { return }
        lastRawText = trimmedRawText
        let content = ParsedPaneContent.make(rawText: trimmedRawText)
        parseGeneration &+= 1
        let generation = parseGeneration
        isParsing = true

        parseTask?.cancel()
        parseTask = Task.detached(priority: .utility) {
            let snapshot = ParsedViewDetector().detect(content)
            await MainActor.run { [weak self] in
                guard let self, self.parseGeneration == generation else { return }
                self.snapshot = snapshot
                self.isParsing = false
            }
        }
    }

    private func sampledText(from panel: TerminalPanel) -> String? {
        let history = panel.surface.surfaceText()
        let active = panel.surface.activeText()
        if let history, !history.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let active,
               !active.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !history.hasSuffix(active) {
                return history + "\n" + active
            }
            return history
        }
        if let screen = panel.surface.screenText(),
           !screen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return screen
        }
        return panel.surface.visibleText()
    }

    private static func tail(_ text: String) -> String {
        var result = text
        if result.count > maxParsedCharacters {
            result = String(result.suffix(maxParsedCharacters))
        }
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > maxParsedLines else { return result }
        return lines.suffix(maxParsedLines).joined(separator: "\n")
    }
}
