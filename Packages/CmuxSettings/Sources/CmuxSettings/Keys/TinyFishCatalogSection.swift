import Foundation

/// Settings under the dotted-id prefix `tinyfish.*`.
public struct TinyFishCatalogSection: SettingCatalogSection {
    /// Whether the TinyFish remote browser sidebar mode is enabled.
    public let enabled = JSONKey<Bool>(
        id: "tinyfish.enabled",
        defaultValue: false
    )

    /// The TinyFish Browser API key stored in macOS Keychain.
    public let apiKey = KeychainSecretKey(
        id: "tinyfish.apiKey",
        service: "com.cmux.tinyfish.browser",
        account: "apiKey"
    )

    /// Session timeout passed to TinyFish when creating a browser.
    public let timeoutSeconds = JSONKey<Int>(
        id: "tinyfish.timeoutSeconds",
        defaultValue: 300
    )

    /// Creates the TinyFish settings section.
    public init() {}
}
