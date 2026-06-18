import Foundation

/// Settings under the dotted-id prefix `sidebarAppearance.*`.
public struct SidebarAppearanceCatalogSection: SettingCatalogSection {
    public let matchTerminalBackground = DefaultsKey<Bool>(
        id: "sidebarAppearance.matchTerminalBackground",
        defaultValue: false,
        userDefaultsKey: "sidebarMatchTerminalBackground"
    )

    public let tintColorHex = DefaultsKey<String>(
        id: "sidebarAppearance.tintColor",
        defaultValue: "#000000",
        userDefaultsKey: "sidebarTintHex"
    )

    public let lightModeTintColorHex = DefaultsKey<String>(
        id: "sidebarAppearance.lightModeTintColor",
        defaultValue: "",
        userDefaultsKey: "sidebarTintHexLight"
    )

    public let darkModeTintColorHex = DefaultsKey<String>(
        id: "sidebarAppearance.darkModeTintColor",
        defaultValue: "",
        userDefaultsKey: "sidebarTintHexDark"
    )

    public let tintOpacity = DefaultsKey<Double>(
        id: "sidebarAppearance.tintOpacity",
        defaultValue: 0.18,
        userDefaultsKey: "sidebarTintOpacity"
    )

    public let blurOpacity = DefaultsKey<Double>(
        id: "sidebarAppearance.blurOpacity",
        defaultValue: 1.0,
        userDefaultsKey: "sidebarBlurOpacity"
    )

    public let cornerRadius = DefaultsKey<Double>(
        id: "sidebarAppearance.cornerRadius",
        defaultValue: 0.0,
        userDefaultsKey: "sidebarCornerRadius"
    )

    public let preset = DefaultsKey<SidebarPresetOption>(
        id: "sidebarAppearance.preset",
        defaultValue: .nativeSidebar,
        userDefaultsKey: "sidebarPreset"
    )

    public let material = DefaultsKey<SidebarMaterialOption>(
        id: "sidebarAppearance.material",
        defaultValue: .sidebar,
        userDefaultsKey: "sidebarMaterial"
    )

    public let blendMode = DefaultsKey<SidebarBlendModeOption>(
        id: "sidebarAppearance.blendMode",
        defaultValue: .withinWindow,
        userDefaultsKey: "sidebarBlendMode"
    )

    public let state = DefaultsKey<SidebarStateOption>(
        id: "sidebarAppearance.state",
        defaultValue: .followWindow,
        userDefaultsKey: "sidebarState"
    )

    /// When `true`, the right sidebar panel restores its prior translucent
    /// material look (gradient backdrop, vibrant cards). Defaults to `false`
    /// so the right panel is a solid, fully opaque Catppuccin Mocha fill that
    /// keeps text legible. The left sidebar is unaffected (always Liquid Glass).
    public let rightPanelTranslucent = DefaultsKey<Bool>(
        id: "rightPanel.translucent",
        defaultValue: false,
        userDefaultsKey: "rightPanelTranslucent"
    )

    public init() {}
}
