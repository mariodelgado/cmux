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

    func appIntentsEnabled() -> Bool {
        let settings = UserDefaultsSettingsClient(defaults: defaults)
        return settings.value(for: SettingCatalog().ai.appIntents)
    }

    func servicesEnabled() -> Bool {
        let settings = UserDefaultsSettingsClient(defaults: defaults)
        return settings.value(for: SettingCatalog().ai.services)
    }

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        AIFeatureSettings(defaults: defaults).isEnabled()
    }

    static func appIntentsEnabled(defaults: UserDefaults = .standard) -> Bool {
        AIFeatureSettings(defaults: defaults).appIntentsEnabled()
    }

    static func servicesEnabled(defaults: UserDefaults = .standard) -> Bool {
        AIFeatureSettings(defaults: defaults).servicesEnabled()
    }
}
