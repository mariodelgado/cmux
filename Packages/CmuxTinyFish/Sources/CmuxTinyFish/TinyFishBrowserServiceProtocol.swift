/// Service protocol behind the TinyFish panel model.
public protocol TinyFishBrowserServiceProtocol: Sendable {
    /// Creates a new session and returns its first rendered snapshot.
    func createSession(apiKey: String, startURL: String?, timeoutSeconds: Int) async throws -> TinyFishBrowserSnapshot

    /// Closes the local CDP connection and clears current session state.
    func closeSession() async

    /// Navigates the current session and returns the refreshed snapshot.
    func navigate(to url: String) async throws -> TinyFishBrowserSnapshot

    /// Captures the current session without changing the page.
    func refresh() async throws -> TinyFishBrowserSnapshot

    /// Clicks a viewport point and returns the refreshed snapshot.
    func click(at point: TinyFishViewportPoint) async throws -> TinyFishBrowserSnapshot

    /// Clicks an optional element, inserts text, and returns the refreshed snapshot.
    func typeText(_ text: String, into element: TinyFishRemoteElement?) async throws -> TinyFishBrowserSnapshot

    /// Scrolls the current page and returns the refreshed snapshot.
    func scroll(deltaY: Double) async throws -> TinyFishBrowserSnapshot

    /// Reads usage for the given API key.
    func usage(apiKey: String) async throws -> TinyFishUsageSnapshot
}
