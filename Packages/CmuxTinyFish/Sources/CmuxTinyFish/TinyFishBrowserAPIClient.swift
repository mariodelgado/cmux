/// Client protocol for TinyFish Browser REST endpoints.
public protocol TinyFishBrowserAPIClient: Sendable {
    /// Creates a remote browser session.
    ///
    /// - Parameters:
    ///   - apiKey: TinyFish API key sent as `X-API-Key`.
    ///   - startURL: Optional URL to open when creating the session.
    ///   - timeoutSeconds: Optional session timeout, clamped by the caller to TinyFish's accepted range.
    /// - Returns: The created session descriptor.
    func createSession(
        apiKey: String,
        startURL: String?,
        timeoutSeconds: Int?
    ) async throws -> TinyFishBrowserSessionDescriptor

    /// Reads usage for the current API key.
    ///
    /// - Parameter apiKey: TinyFish API key sent as `X-API-Key`.
    /// - Returns: The usage snapshot.
    func usage(apiKey: String) async throws -> TinyFishUsageSnapshot
}
