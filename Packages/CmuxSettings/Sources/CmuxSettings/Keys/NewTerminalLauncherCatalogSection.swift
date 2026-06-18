import Foundation

/// Settings under the dotted-id prefix `newTerminalLauncher.*`.
public struct NewTerminalLauncherCatalogSection: SettingCatalogSection {
    public let enabled = DefaultsKey<Bool>(
        id: "newTerminalLauncher.enabled",
        defaultValue: true,
        userDefaultsKey: "newTerminalLauncher.enabled"
    )

    public let tailscale = DefaultsKey<Bool>(
        id: "newTerminalLauncher.tailscale",
        defaultValue: true,
        userDefaultsKey: "newTerminalLauncher.tailscale"
    )

    public init() {}
}
