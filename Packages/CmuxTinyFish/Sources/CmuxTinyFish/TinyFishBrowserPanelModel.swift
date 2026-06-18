public import AppKit
import Foundation
public import Observation

/// Main-actor view model for the TinyFish remote browser panel.
@MainActor
@Observable
public final class TinyFishBrowserPanelModel {
    /// Text currently shown in the URL bar.
    public var urlText: String
    /// Text staged for insertion into the selected remote element.
    public var typedText: String = ""
    /// Whether element overlay hotspots are visible.
    public var overlayVisible: Bool = true
    /// The selected overlay element id.
    public var selectedElementID: String?

    /// Whether an async operation is running.
    public private(set) var isLoading: Bool = false
    /// Current error message, if any.
    public private(set) var errorMessage: String?
    /// Active TinyFish session id.
    public private(set) var sessionID: String?
    /// Compact usage text for the footer.
    public private(set) var usageText: String = ""
    /// Latest rendered frame data.
    public private(set) var frame: TinyFishBrowserFrame?
    /// Latest screenshot image decoded from ``frame``.
    public private(set) var image: NSImage?

    private let service: any TinyFishBrowserServiceProtocol

    /// Creates a TinyFish browser panel model.
    ///
    /// - Parameters:
    ///   - service: Service used to create and drive remote browser sessions.
    ///   - initialURL: Initial URL text.
    public init(
        service: any TinyFishBrowserServiceProtocol = TinyFishBrowserService(),
        initialURL: String = "https://example.com"
    ) {
        self.service = service
        self.urlText = initialURL
    }

    /// Creates a new remote browser session.
    public func createNewSession(apiKey: String, timeoutSeconds: Int) {
        let startURL = Self.normalizedURL(urlText)
        run { [service] in
            try await service.createSession(
                apiKey: apiKey,
                startURL: startURL,
                timeoutSeconds: timeoutSeconds
            )
        }
    }

    /// Navigates the existing session, or creates one if no session exists.
    public func submitURL(apiKey: String, timeoutSeconds: Int) {
        if sessionID == nil {
            createNewSession(apiKey: apiKey, timeoutSeconds: timeoutSeconds)
            return
        }
        guard let url = Self.normalizedURL(urlText) else {
            refresh()
            return
        }
        run { [service] in
            try await service.navigate(to: url)
        }
    }

    /// Refreshes the screenshot and overlay for the current session.
    public func refresh() {
        run { [service] in
            try await service.refresh()
        }
    }

    /// Closes the current local CDP connection and clears panel state.
    public func closeSession() {
        Task { [service] in
            await service.closeSession()
        }
        sessionID = nil
        frame = nil
        image = nil
        selectedElementID = nil
        usageText = ""
        errorMessage = nil
    }

    /// Clicks an overlay element, selecting it for later typed input.
    public func click(element: TinyFishRemoteElement) {
        selectedElementID = element.id
        run { [service] in
            try await service.click(at: element.rect.center)
        }
    }

    /// Clicks a raw viewport point.
    public func click(at point: TinyFishViewportPoint) {
        selectedElementID = nil
        run { [service] in
            try await service.click(at: point)
        }
    }

    /// Types the staged text into the selected element.
    public func typeIntoSelectedElement() {
        let text = typedText
        guard !text.isEmpty else { return }
        let element = selectedElement
        run { [service] in
            try await service.typeText(text, into: element)
        } onSuccess: { [weak self] in
            self?.typedText = ""
        }
    }

    /// Scrolls the current page.
    public func scroll(deltaY: Double) {
        run { [service] in
            try await service.scroll(deltaY: deltaY)
        }
    }

    /// Reads usage for the configured API key.
    public func refreshUsage(apiKey: String) {
        Task { [weak self, service] in
            do {
                let usage = try await service.usage(apiKey: apiKey)
                await MainActor.run {
                    self?.usageText = usage.displayText
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = Self.displayMessage(for: error)
                }
            }
        }
    }

    private var selectedElement: TinyFishRemoteElement? {
        guard let selectedElementID else { return nil }
        return frame?.elements.first { $0.id == selectedElementID }
    }

    private func run(
        operation: @escaping @Sendable () async throws -> TinyFishBrowserSnapshot,
        onSuccess: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task { [weak self] in
            do {
                let snapshot = try await operation()
                await MainActor.run {
                    self?.apply(snapshot)
                    onSuccess?()
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                    self?.errorMessage = Self.displayMessage(for: error)
                }
            }
        }
    }

    private func apply(_ snapshot: TinyFishBrowserSnapshot) {
        sessionID = snapshot.session.sessionID
        frame = snapshot.frame
        image = NSImage(data: snapshot.frame.pngData)
        if let usage = snapshot.usage {
            usageText = usage.displayText
        }
        if let selectedElementID,
           !snapshot.frame.elements.contains(where: { $0.id == selectedElementID }) {
            self.selectedElementID = nil
        }
        isLoading = false
    }

    private static func normalizedURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private static func displayMessage(for error: any Error) -> String {
        if let localized = error as? any LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
