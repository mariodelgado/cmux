public import Foundation

/// Errors surfaced by the TinyFish browser integration.
public enum TinyFishBrowserError: Error, Sendable, Equatable {
    /// No API key is configured.
    case missingAPIKey
    /// The API key or URL was invalid.
    case invalidRequest(String)
    /// TinyFish returned a structured API error.
    case api(code: String, message: String, details: TinyFishJSONValue?)
    /// TinyFish returned an unexpected HTTP response.
    case unexpectedStatus(Int)
    /// CDP returned an error object.
    case cdp(code: Int, message: String)
    /// CDP did not expose a page target.
    case pageTargetUnavailable
    /// A CDP load wait exceeded its deadline.
    case loadTimeout
    /// A CDP response was missing expected data.
    case malformedResponse(String)
}

extension TinyFishBrowserError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "tinyfish.error.missingAPIKey", defaultValue: "TinyFish API key is not configured.")
        case .invalidRequest(let message):
            return message
        case .api(let code, let message, _):
            return "\(code): \(message)"
        case .unexpectedStatus(let status):
            return String(localized: "tinyfish.error.unexpectedStatus", defaultValue: "TinyFish returned HTTP \(status).")
        case .cdp(let code, let message):
            return "CDP \(code): \(message)"
        case .pageTargetUnavailable:
            return String(localized: "tinyfish.error.pageTargetUnavailable", defaultValue: "TinyFish session did not expose a page target.")
        case .loadTimeout:
            return String(localized: "tinyfish.error.loadTimeout", defaultValue: "Timed out waiting for the remote page to load.")
        case .malformedResponse(let message):
            return message
        }
    }
}
