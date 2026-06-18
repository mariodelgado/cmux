public import Foundation

/// Chrome DevTools Protocol operations needed by the TinyFish browser panel.
public protocol TinyFishCDPClientProtocol: Sendable {
    /// Connects to a CDP WebSocket endpoint and attaches to the page target.
    ///
    /// - Parameter cdpURL: The CDP WebSocket URL returned by TinyFish.
    func connect(to cdpURL: URL) async throws

    /// Closes the WebSocket connection.
    func close() async

    /// Navigates the page and waits for the load event.
    ///
    /// - Parameter url: Absolute URL string.
    func navigate(to url: String) async throws

    /// Captures a screenshot and current overlay elements.
    ///
    /// - Returns: A rendered browser frame.
    func captureFrame() async throws -> TinyFishBrowserFrame

    /// Clicks a viewport point in CSS pixels.
    ///
    /// - Parameter point: Viewport point.
    func click(at point: TinyFishViewportPoint) async throws

    /// Inserts text at the focused element.
    ///
    /// - Parameter text: Text to insert.
    func insertText(_ text: String) async throws

    /// Dispatches a mouse-wheel scroll event.
    ///
    /// - Parameter deltaY: Vertical wheel delta.
    func scroll(deltaY: Double) async throws
}
