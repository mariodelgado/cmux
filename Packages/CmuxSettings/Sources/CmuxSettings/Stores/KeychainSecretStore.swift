public import Foundation
import Security

/// Typed read/write/observe access to secret strings stored in macOS Keychain.
///
/// The store is an `actor`; reads, writes, and reset are `async`. It accepts
/// ``KeychainSecretKey`` values and never serializes the secret into
/// `cmux.json`. Observation mirrors ``SecretFileStore``: callers receive the
/// current secret and later changes through an `AsyncStream`.
public actor KeychainSecretStore {
    /// Posted in-process after any Keychain secret is written or cleared.
    public static let didChangeNotification = Notification.Name("cmux.keychainSecretStoreDidChange")

    /// `userInfo` key under which ``didChangeNotification`` carries the changed key id.
    public static let changedKeyIDKey = "keyID"

    /// Creates a Keychain secret store.
    public init() {}

    /// The current secret for `key`, or its ``KeychainSecretKey/defaultValue`` when absent/empty.
    ///
    /// - Parameter key: The Keychain-backed setting key to read.
    /// - Returns: The stored secret or the key default.
    /// - Throws: ``KeychainSecretStoreError`` if the Keychain query fails.
    public func value(for key: KeychainSecretKey) throws -> String {
        try Self.readValue(for: key)
    }

    /// Synchronously reads the current secret for code paths that must make
    /// availability decisions without entering the actor.
    ///
    /// - Parameter key: The Keychain-backed setting key to read.
    /// - Returns: The stored secret or the key default.
    /// - Throws: ``KeychainSecretStoreError`` if the Keychain query fails.
    public nonisolated func snapshotValue(for key: KeychainSecretKey) throws -> String {
        try Self.readValue(for: key)
    }

    private static func readValue(for key: KeychainSecretKey) throws -> String {
        var rawResult: CFTypeRef?
        let status = SecItemCopyMatching(readQuery(for: key) as CFDictionary, &rawResult)
        if status == errSecItemNotFound {
            return key.defaultValue
        }
        guard status == errSecSuccess else {
            throw KeychainSecretStoreError(operation: "SecItemCopyMatching", status: status)
        }
        guard let data = rawResult as? Data,
              let raw = String(data: data, encoding: .utf8),
              let normalized = Self.normalized(raw) else {
            return key.defaultValue
        }
        return normalized
    }

    /// Whether a non-empty secret is stored in Keychain for `key`.
    ///
    /// This inspects the Keychain item directly and ignores
    /// ``KeychainSecretKey/defaultValue``.
    public func hasValue(for key: KeychainSecretKey) -> Bool {
        guard let value = try? value(for: key) else { return false }
        if value == key.defaultValue {
            var rawResult: CFTypeRef?
            let status = SecItemCopyMatching(Self.readQuery(for: key) as CFDictionary, &rawResult)
            guard status == errSecSuccess else { return false }
        }
        return Self.normalized(value) != nil
    }

    /// Writes `value` to Keychain, or clears it when empty after newline trimming.
    ///
    /// - Parameters:
    ///   - value: The secret value to store.
    ///   - key: The Keychain-backed setting key to write.
    /// - Throws: ``KeychainSecretStoreError`` if add/update/delete fails.
    public func set(_ value: String, for key: KeychainSecretKey) throws {
        let normalized = value.trimmingCharacters(in: .newlines)
        if normalized.isEmpty {
            try reset(key)
            return
        }

        let data = Data(normalized.utf8)
        let updateStatus = SecItemUpdate(
            identityQuery(for: key) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            postChange(for: key)
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainSecretStoreError(operation: "SecItemUpdate", status: updateStatus)
        }

        var addQuery = identityQuery(for: key)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSecretStoreError(operation: "SecItemAdd", status: addStatus)
        }
        postChange(for: key)
    }

    /// Deletes the Keychain item for `key`, if present.
    ///
    /// - Parameter key: The Keychain-backed setting key to clear.
    /// - Throws: ``KeychainSecretStoreError`` if deletion fails.
    public func reset(_ key: KeychainSecretKey) throws {
        let status = SecItemDelete(identityQuery(for: key) as CFDictionary)
        if status == errSecSuccess {
            postChange(for: key)
            return
        }
        guard status == errSecItemNotFound else {
            throw KeychainSecretStoreError(operation: "SecItemDelete", status: status)
        }
    }

    /// An `AsyncStream` yielding the current secret and every later change.
    ///
    /// The first element is the current value; subsequent elements arrive when
    /// ``didChangeNotification`` fires for this key. Buffering is
    /// `.bufferingNewest(1)`.
    public nonisolated func values(for key: KeychainSecretKey) -> AsyncStream<String> {
        AsyncStream<String>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let (signals, signalContinuation) = AsyncStream<Void>.makeStream(
                bufferingPolicy: .bufferingNewest(1)
            )

            let observer = NotificationObserverToken(
                NotificationCenter.default.addObserver(
                    forName: KeychainSecretStore.didChangeNotification,
                    object: nil,
                    queue: nil
                ) { [weak self] note in
                    if let changedID = note.userInfo?[KeychainSecretStore.changedKeyIDKey] as? String,
                       changedID != key.id {
                        return
                    }
                    guard self != nil else { return }
                    signalContinuation.yield(())
                }
            )

            let drainTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                var lastYielded = (try? await self.value(for: key)) ?? key.defaultValue
                continuation.yield(lastYielded)

                for await _ in signals {
                    if Task.isCancelled { break }
                    let current = (try? await self.value(for: key)) ?? key.defaultValue
                    if current != lastYielded {
                        lastYielded = current
                        continuation.yield(current)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                drainTask.cancel()
                signalContinuation.finish()
                observer.remove()
            }
        }
    }

    private static func identityQuery(for key: KeychainSecretKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account
        ]
    }

    private static func readQuery(for key: KeychainSecretKey) -> [String: Any] {
        var query = identityQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    private func identityQuery(for key: KeychainSecretKey) -> [String: Any] {
        Self.identityQuery(for: key)
    }

    private func postChange(for key: KeychainSecretKey) {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: nil,
            userInfo: [Self.changedKeyIDKey: key.id]
        )
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .newlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
