import Foundation

enum NewTerminalLauncherSettings {
    static let enabledKey = "newTerminalLauncher.enabled"
    static let defaultEnabled = true

    static let tailscaleKey = "newTerminalLauncher.tailscale"
    static let defaultTailscaleEnabled = true

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: enabledKey) != nil else {
            return defaultEnabled
        }
        return defaults.bool(forKey: enabledKey)
    }

    static func isTailscaleEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: tailscaleKey) != nil else {
            return defaultTailscaleEnabled
        }
        return defaults.bool(forKey: tailscaleKey)
    }
}
