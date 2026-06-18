import CmuxSettings
import Foundation

enum ParsedViewSettings {
    private static let catalog = ParsedViewCatalogSection()

    static let enabledKey = catalog.enabled.userDefaultsKey
    static let defaultEnabled = catalog.enabled.defaultValue
}
