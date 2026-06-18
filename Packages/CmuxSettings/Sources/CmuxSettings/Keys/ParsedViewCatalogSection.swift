import Foundation

/// Settings under the dotted-id prefix `parsedView.*`.
public struct ParsedViewCatalogSection: SettingCatalogSection {
    /// Enables the per-pane native parsed terminal view.
    public let enabled = DefaultsKey<Bool>(
        id: "parsedView.enabled",
        defaultValue: true,
        userDefaultsKey: "parsedView.enabled"
    )

    public init() {}
}
