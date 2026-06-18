import CmuxSettings
import Foundation
import Observation

/// `@Observable` view-model that projects one ``KeychainSecretKey`` value into
/// SwiftUI-bindable state.
///
/// Same shape as ``SecretValueModel`` but bound to a ``KeychainSecretStore``.
/// The secret lives in macOS Keychain, never in the shared `cmux.json`. Set /
/// reset failures populate ``lastWriteError`` and are pushed into the injected
/// ``SettingsErrorLog`` so the UI surfaces them centrally.
@MainActor
@Observable
public final class KeychainSecretValueModel {
    /// The most recently observed secret. SwiftUI views read this synchronously.
    public private(set) var current: String

    /// Error from the most recent set/reset attempt, or `nil`.
    public private(set) var lastWriteError: Error?

    private let store: KeychainSecretStore
    private let key: KeychainSecretKey
    private let errorLog: SettingsErrorLog

    /// Owns the change-stream subscription and cancels it when this model deallocates.
    @ObservationIgnored private let observation = SettingReadDriver<String>()

    /// Creates a model bound to ``key`` in ``store``.
    ///
    /// - Parameters:
    ///   - store: The Keychain secret store to read from and write to.
    ///   - key: The secret to observe.
    ///   - errorLog: Global log that write failures are pushed into.
    public convenience init(
        store: KeychainSecretStore,
        key: KeychainSecretKey,
        errorLog: SettingsErrorLog
    ) {
        self.init(
            store: store,
            key: key,
            errorLog: errorLog,
            makeStream: { store.values(for: key) }
        )
    }

    /// Designated initializer with an injectable change-stream factory.
    ///
    /// - Parameters:
    ///   - store: The Keychain secret store used for writes (`set`/`reset`).
    ///   - key: The secret to observe.
    ///   - errorLog: Global log that write failures are pushed into.
    ///   - makeStream: Builds the change stream this model iterates.
    init(
        store: KeychainSecretStore,
        key: KeychainSecretKey,
        errorLog: SettingsErrorLog,
        makeStream: @escaping () -> AsyncStream<String>
    ) {
        self.store = store
        self.key = key
        self.errorLog = errorLog
        self.current = key.defaultValue
        observation.activate(makeStream) { [weak self] value in
            self?.current = value
        }
    }

    /// Persists the secret. The observation stream is the single writer of
    /// ``current``. On failure ``lastWriteError`` is populated and recorded.
    public func set(_ value: String) {
        let keyID = key.id
        Task { [weak self, store, key] in
            do {
                try await store.set(value, for: key)
                self?.lastWriteError = nil
            } catch {
                self?.lastWriteError = error
                self?.errorLog.record(error, keyID: keyID)
            }
        }
    }

    /// Clears the secret from Keychain. ``current`` updates when the stream observes the reset.
    public func reset() {
        let keyID = key.id
        Task { [weak self, store, key] in
            do {
                try await store.reset(key)
                await MainActor.run { self?.lastWriteError = nil }
            } catch {
                await MainActor.run {
                    self?.lastWriteError = error
                    self?.errorLog.record(error, keyID: keyID)
                }
            }
        }
    }
}
