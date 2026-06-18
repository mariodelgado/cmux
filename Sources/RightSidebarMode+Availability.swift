import Foundation
import CmuxSettings

extension RightSidebarMode {
    static func from(cliArgument rawValue: String) -> RightSidebarMode? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "files":
            return .files
        case "find":
            return .find
        case "vault", "sessions":
            return .sessions
        case "feed":
            return .feed
        case "dock":
            return .dock
        case "inspector", "openrouter":
            return .inspector
        case "tinyfish", "tinyfish-browser", "remote-browser":
            return .tinyfish
        default:
            return nil
        }
    }

    static func availableModes(defaults: UserDefaults = .standard) -> [RightSidebarMode] {
        availableModes(
            feedEnabled: RightSidebarBetaFeatureSettings.isFeedEnabled(defaults: defaults),
            dockEnabled: RightSidebarBetaFeatureSettings.isDockEnabled(defaults: defaults),
            inspectorEnabled: inspectorEnabledFromConfig(),
            tinyFishEnabled: tinyFishEnabledFromConfig()
        )
    }

    static func availableModes(feedEnabled: Bool, dockEnabled: Bool) -> [RightSidebarMode] {
        availableModes(feedEnabled: feedEnabled, dockEnabled: dockEnabled, inspectorEnabled: true, tinyFishEnabled: false)
    }

    static func availableModes(
        feedEnabled: Bool,
        dockEnabled: Bool,
        inspectorEnabled: Bool,
        tinyFishEnabled: Bool
    ) -> [RightSidebarMode] {
        allCases.filter {
            $0.isAvailable(
                feedEnabled: feedEnabled,
                dockEnabled: dockEnabled,
                inspectorEnabled: inspectorEnabled,
                tinyFishEnabled: tinyFishEnabled
            )
        }
    }

    func isAvailable(defaults: UserDefaults = .standard) -> Bool {
        if self == .inspector {
            return Self.inspectorEnabledFromConfig()
        }
        if self == .tinyfish {
            return Self.tinyFishEnabledFromConfig()
        }
        return isAvailable(
            feedEnabled: RightSidebarBetaFeatureSettings.isFeedEnabled(defaults: defaults),
            dockEnabled: RightSidebarBetaFeatureSettings.isDockEnabled(defaults: defaults)
        )
    }

    func isAvailable(feedEnabled: Bool, dockEnabled: Bool) -> Bool {
        isAvailable(feedEnabled: feedEnabled, dockEnabled: dockEnabled, inspectorEnabled: true, tinyFishEnabled: false)
    }

    func isAvailable(
        feedEnabled: Bool,
        dockEnabled: Bool,
        inspectorEnabled: Bool,
        tinyFishEnabled: Bool
    ) -> Bool {
        switch self {
        case .files, .find, .sessions:
            return true
        case .feed:
            return feedEnabled
        case .dock:
            return dockEnabled
        case .inspector:
            return inspectorEnabled
        case .tinyfish:
            return tinyFishEnabled
        }
    }

    private static func inspectorEnabledFromConfig() -> Bool {
        let catalog = SettingCatalog()
        let store = JSONConfigStore(fileURL: CmuxConfigLocation().userConfigFile)
        return store.snapshotValue(for: catalog.inspector.enabled)
    }

    private static func tinyFishEnabledFromConfig() -> Bool {
        let catalog = SettingCatalog()
        let store = JSONConfigStore(fileURL: CmuxConfigLocation().userConfigFile)
        guard store.snapshotValue(for: catalog.tinyfish.enabled) else { return false }
        if let keychainKey = try? KeychainSecretStore().snapshotValue(for: catalog.tinyfish.apiKey),
           !keychainKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        let legacyKey = JSONKey<String>(id: "tinyfish.apiKey", defaultValue: "")
        return !store.snapshotValue(for: legacyKey).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
