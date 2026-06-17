import CmuxSettings
import Foundation

struct AIFeatureSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled() -> Bool {
        let settings = UserDefaultsSettingsClient(defaults: defaults)
        return settings.value(for: SettingCatalog().ai.enabled)
    }

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        AIFeatureSettings(defaults: defaults).isEnabled()
    }
}
