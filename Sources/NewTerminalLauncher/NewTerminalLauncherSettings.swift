import Foundation

enum NewTerminalLauncherSettings {
    static let enabledKey = "newTerminalLauncher.enabled"
    static let defaultEnabled = true

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: enabledKey) != nil else {
            return defaultEnabled
        }
        return defaults.bool(forKey: enabledKey)
    }
}
