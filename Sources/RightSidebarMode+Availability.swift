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
        default:
            return nil
        }
    }

    static func availableModes(defaults: UserDefaults = .standard) -> [RightSidebarMode] {
        availableModes(
            feedEnabled: RightSidebarBetaFeatureSettings.isFeedEnabled(defaults: defaults),
            dockEnabled: RightSidebarBetaFeatureSettings.isDockEnabled(defaults: defaults),
            inspectorEnabled: inspectorEnabledFromConfig()
        )
    }

    static func availableModes(feedEnabled: Bool, dockEnabled: Bool) -> [RightSidebarMode] {
        availableModes(feedEnabled: feedEnabled, dockEnabled: dockEnabled, inspectorEnabled: true)
    }

    static func availableModes(
        feedEnabled: Bool,
        dockEnabled: Bool,
        inspectorEnabled: Bool
    ) -> [RightSidebarMode] {
        allCases.filter {
            $0.isAvailable(
                feedEnabled: feedEnabled,
                dockEnabled: dockEnabled,
                inspectorEnabled: inspectorEnabled
            )
        }
    }

    func isAvailable(defaults: UserDefaults = .standard) -> Bool {
        if self == .inspector {
            return Self.inspectorEnabledFromConfig()
        }
        return isAvailable(
            feedEnabled: RightSidebarBetaFeatureSettings.isFeedEnabled(defaults: defaults),
            dockEnabled: RightSidebarBetaFeatureSettings.isDockEnabled(defaults: defaults)
        )
    }

    func isAvailable(feedEnabled: Bool, dockEnabled: Bool) -> Bool {
        isAvailable(feedEnabled: feedEnabled, dockEnabled: dockEnabled, inspectorEnabled: true)
    }

    func isAvailable(
        feedEnabled: Bool,
        dockEnabled: Bool,
        inspectorEnabled: Bool
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
        }
    }

    private static func inspectorEnabledFromConfig() -> Bool {
        let catalog = SettingCatalog()
        let store = JSONConfigStore(fileURL: CmuxConfigLocation().userConfigFile)
        return store.snapshotValue(for: catalog.inspector.enabled)
    }
}
