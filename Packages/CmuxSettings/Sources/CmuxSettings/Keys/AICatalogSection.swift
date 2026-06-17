import Foundation

/// Settings under the dotted-id prefix `ai.*`.
public struct AICatalogSection: SettingCatalogSection {
    public static let defaultEndpoint = "http://127.0.0.1:8765/v1"

    public let enabled = DefaultsKey<Bool>(
        id: "ai.enabled",
        defaultValue: true,
        userDefaultsKey: "aiEnabled"
    )

    public let endpoint = DefaultsKey<String>(
        id: "ai.endpoint",
        defaultValue: Self.defaultEndpoint,
        userDefaultsKey: "aiEndpoint"
    )

    public let appIntents = DefaultsKey<Bool>(
        id: "ai.appIntents",
        defaultValue: true,
        userDefaultsKey: "aiAppIntentsEnabled"
    )

    public let services = DefaultsKey<Bool>(
        id: "ai.services",
        defaultValue: true,
        userDefaultsKey: "aiServicesEnabled"
    )

    public let menuBar = DefaultsKey<Bool>(
        id: "ai.menuBar",
        defaultValue: true,
        userDefaultsKey: "aiMenuBarEnabled"
    )

    public init() {}
}
