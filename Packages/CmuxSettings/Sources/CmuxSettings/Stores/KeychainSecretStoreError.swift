import Foundation
import Security

/// Errors raised by ``KeychainSecretStore`` when a Keychain operation fails.
public struct KeychainSecretStoreError: Error, Equatable, Sendable {
    /// The operation that failed.
    public let operation: String

    /// The OSStatus returned by Security.framework.
    public let status: OSStatus

    /// Creates a Keychain store error.
    ///
    /// - Parameters:
    ///   - operation: The operation that failed.
    ///   - status: The OSStatus returned by Security.framework.
    public init(operation: String, status: OSStatus) {
        self.operation = operation
        self.status = status
    }
}

extension KeychainSecretStoreError: LocalizedError {
    public var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) {
            return "\(operation) failed: \(message)"
        }
        return "\(operation) failed with OSStatus \(status)"
    }
}
