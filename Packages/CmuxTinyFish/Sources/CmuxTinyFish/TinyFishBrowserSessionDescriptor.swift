public import Foundation

/// A TinyFish browser session returned by the session-create API.
public struct TinyFishBrowserSessionDescriptor: Sendable, Equatable, Decodable {
    /// The TinyFish session id, for example `br-...`.
    public let sessionID: String
    /// The Chrome DevTools Protocol WebSocket endpoint.
    public let cdpURL: URL
    /// The HTTP base URL for the session.
    public let baseURL: URL

    private enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cdpURL = "cdp_url"
        case baseURL = "base_url"
    }

    /// Creates a TinyFish browser session descriptor.
    public init(sessionID: String, cdpURL: URL, baseURL: URL) {
        self.sessionID = sessionID
        self.cdpURL = cdpURL
        self.baseURL = baseURL
    }
}
