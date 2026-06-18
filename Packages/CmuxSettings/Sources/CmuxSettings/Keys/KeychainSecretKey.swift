import Foundation

/// A strongly-typed handle to a secret string persisted in the macOS Keychain.
///
/// `KeychainSecretKey` is for credentials that should be editable through
/// Settings without being written to `cmux.json` or cmux-owned files. The
/// matching store is ``KeychainSecretStore``.
public struct KeychainSecretKey: Sendable, Equatable {
    /// The dotted identifier used by settings UI, search, and diagnostics.
    public let id: String

    /// The Keychain service name.
    public let service: String

    /// The Keychain account name.
    public let account: String

    /// The value returned when the Keychain item is absent or empty.
    public let defaultValue: String

    /// Creates a Keychain-backed secret key.
    ///
    /// - Parameters:
    ///   - id: The dotted settings identifier.
    ///   - service: The Keychain service name.
    ///   - account: The Keychain account name.
    ///   - defaultValue: The fallback when the item is missing or empty; defaults to `""`.
    public init(
        id: String,
        service: String,
        account: String,
        defaultValue: String = ""
    ) {
        precondition(!id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "KeychainSecretKey.id must not be empty")
        precondition(!service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "KeychainSecretKey.service must not be empty")
        precondition(!account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "KeychainSecretKey.account must not be empty")
        self.id = id
        self.service = service
        self.account = account
        self.defaultValue = defaultValue
    }
}
