import AppKit
import SwiftUI

extension String {
    static let cmuxDefaultMonospacedFontFamily = "SFMono Nerd Font"
}

extension Font {
    static func cmuxMonospaced(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(String.cmuxDefaultMonospacedFontFamily, size: size).weight(weight)
    }
}

extension NSFont {
    static func cmuxMonospaced(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont(name: String.cmuxDefaultMonospacedFontFamily, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: weight)
    }
}

struct RightSidebarCatppuccinMochaPalette {
    private init() {}

    static let baseNS = nsColor(red: 0x1e, green: 0x1e, blue: 0x2e)
    static let mantleNS = nsColor(red: 0x18, green: 0x18, blue: 0x25)
    static let crustNS = nsColor(red: 0x11, green: 0x11, blue: 0x1b)
    static let surface0NS = nsColor(red: 0x31, green: 0x32, blue: 0x44)
    static let surface1NS = nsColor(red: 0x45, green: 0x47, blue: 0x5a)
    static let textNS = nsColor(red: 0xcd, green: 0xd6, blue: 0xf4)
    static let subtext0NS = nsColor(red: 0xa6, green: 0xad, blue: 0xc8)
    static let overlay0NS = nsColor(red: 0x6c, green: 0x70, blue: 0x86)
    static let mauveNS = nsColor(red: 0xcb, green: 0xa6, blue: 0xf7)
    static let blueNS = nsColor(red: 0x89, green: 0xb4, blue: 0xfa)

    static let base = Color(nsColor: baseNS)
    static let mantle = Color(nsColor: mantleNS)
    static let crust = Color(nsColor: crustNS)
    static let surface0 = Color(nsColor: surface0NS)
    static let surface1 = Color(nsColor: surface1NS)
    static let text = Color(nsColor: textNS)
    static let subtext0 = Color(nsColor: subtext0NS)
    static let overlay0 = Color(nsColor: overlay0NS)
    static let mauve = Color(nsColor: mauveNS)
    static let blue = Color(nsColor: blueNS)
    static let hairline = surface1.opacity(0.52)
    static let softHairline = surface1.opacity(0.38)
    static let insetGroupFill = surface0
    static let panelBackdrop = mantle

    static var panelBackground: LinearGradient {
        LinearGradient(
            colors: [mantle, base, base],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private static func nsColor(red: Int, green: Int, blue: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: alpha
        )
    }
}

struct RightSidebarCatppuccinDivider: View {
    enum Orientation {
        case horizontal
        case vertical
    }

    var orientation: Orientation = .horizontal

    var body: some View {
        Rectangle()
            .fill(RightSidebarCatppuccinMochaPalette.hairline)
            .frame(
                maxWidth: orientation == .horizontal ? .infinity : nil,
                maxHeight: orientation == .vertical ? .infinity : nil
            )
            .frame(
                width: orientation == .vertical ? 1 : nil,
                height: orientation == .horizontal ? 1 : nil
            )
    }
}

enum HeaderChromeIconStyle {
    static let opacity = 0.86
    static let hoveredOpacity = 0.96
    static let pressedOpacity = 1.0
    static let disabledOpacity = 0.34
    static let weight: Font.Weight = .regular
    static let foregroundColor = RightSidebarCatppuccinMochaPalette.subtext0
    static let sidebarGlyphStrokeWidth: CGFloat = 1

    static func iconFrameSize(forIconSize iconSize: CGFloat) -> CGFloat {
        HeaderChromeControlMetrics.iconFrameSize(forIconSize: iconSize)
    }

    static func symbol(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .cmuxSymbolRasterSize(RightSidebarChromeMetrics.headerIconSize, weight: weight)
    }

    static func foregroundOpacity(isHovering: Bool, isPressed: Bool, isEnabled: Bool = true) -> Double {
        guard isEnabled else { return disabledOpacity }
        if isPressed {
            return pressedOpacity
        }
        if isHovering {
            return hoveredOpacity
        }
        return opacity
    }

    static func backgroundOpacity(
        hoverBackground: Bool,
        isHovering: Bool,
        isPressed: Bool,
        isEnabled: Bool = true
    ) -> Double {
        guard isEnabled else { return 0 }
        if isPressed {
            return 0.18
        }
        if isHovering {
            return hoverBackground ? 0.12 : 0.10
        }
        return 0
    }

    static func borderOpacity(
        buttonBackground: Bool,
        isHovering: Bool,
        isPressed: Bool,
        isEnabled: Bool = true
    ) -> Double {
        guard isEnabled else { return buttonBackground ? 0.04 : 0 }
        if isPressed {
            return 0.44
        }
        if isHovering {
            return 0.32
        }
        return buttonBackground ? 0.22 : 0
    }
}

enum RightSidebarChromeControlStyle {
    static let modeIconSize: CGFloat = 11
    static let secondaryIconSize: CGFloat = 10
    static let labelSize: CGFloat = 11
    static let iconWeight = HeaderChromeIconStyle.weight
    static let labelWeight = HeaderChromeIconStyle.weight
    static let foregroundColor = HeaderChromeIconStyle.foregroundColor

    static func foregroundOpacity(isSelected: Bool, isHovered: Bool, isEnabled: Bool = true) -> Double {
        guard isEnabled else { return HeaderChromeIconStyle.disabledOpacity }
        if isSelected {
            return HeaderChromeIconStyle.pressedOpacity
        }
        return HeaderChromeIconStyle.foregroundOpacity(
            isHovering: isHovered,
            isPressed: false,
            isEnabled: isEnabled
        )
    }
}

struct RightSidebarChromeBarModifier: ViewModifier {
    var leadingPadding: CGFloat
    var trailingPadding: CGFloat
    var height: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, RightSidebarChromeMetrics.barVerticalPadding)
            .frame(height: height)
            .background(RightSidebarCatppuccinMochaPalette.mantle)
    }
}

struct RightSidebarChromePillModifier: ViewModifier {
    var isSelected: Bool
    var isHovered: Bool
    var horizontalPadding: CGFloat = RightSidebarChromeMetrics.controlHorizontalPadding
    var geometryKeyPrefix: String?

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(height: RightSidebarChromeMetrics.controlHeight)
            .reportRightSidebarChromeNamedGeometryForBonsplitUITest(
                keyPrefix: geometryKeyPrefix,
                isVisible: true
            )
            .background(
                RoundedRectangle(cornerRadius: RightSidebarChromeMetrics.controlCornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: RightSidebarChromeMetrics.controlCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .contentShape(
                RoundedRectangle(cornerRadius: RightSidebarChromeMetrics.controlCornerRadius, style: .continuous)
            )
    }

    private var foregroundColor: Color {
        if isSelected {
            return RightSidebarCatppuccinMochaPalette.text
        }
        return RightSidebarChromeControlStyle.foregroundColor.opacity(
            RightSidebarChromeControlStyle.foregroundOpacity(
                isSelected: isSelected,
                isHovered: isHovered
            )
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return RightSidebarCatppuccinMochaPalette.mauve.opacity(0.18)
        }
        if isHovered {
            return RightSidebarCatppuccinMochaPalette.blue.opacity(0.10)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return RightSidebarCatppuccinMochaPalette.mauve.opacity(0.42)
        }
        if isHovered {
            return RightSidebarCatppuccinMochaPalette.surface1.opacity(0.46)
        }
        return Color.clear
    }

    private var borderWidth: CGFloat {
        isSelected || isHovered ? 1 : 0
    }
}

struct RightSidebarChromeBottomBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            WindowChromeBorder(
                orientation: .horizontal,
                ignoresSafeArea: false,
                color: RightSidebarCatppuccinMochaPalette.surface1
                    .opacity(0.52)
            )
        }
    }
}

struct RightSidebarHeaderIconButtonStyle: ButtonStyle {
    var iconGeometryKeyPrefix: String? = nil

    func makeBody(configuration: Configuration) -> some View {
        RightSidebarHeaderIconButtonStyleBody(
            configuration: configuration,
            iconGeometryKeyPrefix: iconGeometryKeyPrefix
        )
    }
}

private struct RightSidebarHeaderIconButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let iconGeometryKeyPrefix: String?
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .symbolRenderingMode(.monochrome)
            .frame(
                width: RightSidebarChromeMetrics.headerIconFrameSize,
                height: RightSidebarChromeMetrics.headerIconFrameSize
            )
            .reportRightSidebarChromeNamedGeometryForBonsplitUITest(
                keyPrefix: iconGeometryKeyPrefix,
                isVisible: true
            )
            .frame(
                width: RightSidebarChromeMetrics.headerControlSize,
                height: RightSidebarChromeMetrics.headerControlSize
            )
            .foregroundStyle(foregroundColor)
            .background {
                RoundedRectangle(cornerRadius: RightSidebarChromeMetrics.headerControlCornerRadius, style: .continuous)
                    .fill(headerBackgroundColor)
                    .opacity(backgroundOpacity)
            }
            .overlay {
                RoundedRectangle(cornerRadius: RightSidebarChromeMetrics.headerControlCornerRadius, style: .continuous)
                    .stroke(headerBorderColor, lineWidth: backgroundOpacity > 0 ? 1 : 0)
            }
            .contentShape(
                RoundedRectangle(cornerRadius: RightSidebarChromeMetrics.headerControlCornerRadius, style: .continuous)
            )
            .onHover { isHovering = $0 }
    }

    private var foregroundOpacity: Double {
        HeaderChromeIconStyle.foregroundOpacity(
            isHovering: isHovering,
            isPressed: configuration.isPressed,
            isEnabled: isEnabled
        )
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return RightSidebarCatppuccinMochaPalette.overlay0.opacity(HeaderChromeIconStyle.disabledOpacity)
        }
        if configuration.isPressed || isHovering {
            return RightSidebarCatppuccinMochaPalette.text.opacity(foregroundOpacity)
        }
        return HeaderChromeIconStyle.foregroundColor.opacity(foregroundOpacity)
    }

    private var backgroundOpacity: Double {
        HeaderChromeIconStyle.backgroundOpacity(
            hoverBackground: false,
            isHovering: isHovering,
            isPressed: configuration.isPressed,
            isEnabled: isEnabled
        )
    }

    private var headerBackgroundColor: Color {
        if configuration.isPressed {
            return RightSidebarCatppuccinMochaPalette.mauve
        }
        return RightSidebarCatppuccinMochaPalette.surface0
    }

    private var headerBorderColor: Color {
        if configuration.isPressed {
            return RightSidebarCatppuccinMochaPalette.mauve.opacity(0.42)
        }
        return RightSidebarCatppuccinMochaPalette.surface1.opacity(0.38)
    }
}

struct RightSidebarInsetGroupModifier: ViewModifier {
    var cornerRadius: CGFloat = RightSidebarChromeMetrics.insetGroupCornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RightSidebarCatppuccinMochaPalette.insetGroupFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(RightSidebarCatppuccinMochaPalette.hairline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func rightSidebarChromeBar(
        leadingPadding: CGFloat = RightSidebarChromeMetrics.barHorizontalPadding,
        trailingPadding: CGFloat = RightSidebarChromeMetrics.barHorizontalPadding,
        height: CGFloat = RightSidebarChromeMetrics.secondaryBarHeight
    ) -> some View {
        modifier(
            RightSidebarChromeBarModifier(
                leadingPadding: leadingPadding,
                trailingPadding: trailingPadding,
                height: height
            )
        )
    }

    func rightSidebarChromePill(
        isSelected: Bool,
        isHovered: Bool,
        horizontalPadding: CGFloat = RightSidebarChromeMetrics.controlHorizontalPadding,
        geometryKeyPrefix: String? = nil
    ) -> some View {
        modifier(
            RightSidebarChromePillModifier(
                isSelected: isSelected,
                isHovered: isHovered,
                horizontalPadding: horizontalPadding,
                geometryKeyPrefix: geometryKeyPrefix
            )
        )
    }

    func rightSidebarChromeBottomBorder() -> some View {
        modifier(RightSidebarChromeBottomBorderModifier())
    }

    func rightSidebarInsetGroup(
        cornerRadius: CGFloat = RightSidebarChromeMetrics.insetGroupCornerRadius
    ) -> some View {
        modifier(RightSidebarInsetGroupModifier(cornerRadius: cornerRadius))
    }

    func rightSidebarHeaderControlAlignment() -> some View {
        alignmentGuide(VerticalAlignment.center) { dimensions in
            dimensions[VerticalAlignment.center] + RightSidebarChromeMetrics.headerControlCenterAlignmentAdjustment
        }
    }
}
