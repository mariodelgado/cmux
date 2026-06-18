import Foundation

/// Settings under the dotted-id prefix `inspector.*`.
public struct InspectorCatalogSection: SettingCatalogSection {
    public static let defaultHost = "mario.servarica"

    public let enabled = JSONKey<Bool>(
        id: "inspector.enabled",
        defaultValue: true
    )

    public let host = JSONKey<String>(
        id: "inspector.host",
        defaultValue: Self.defaultHost
    )

    public init() {}
}
