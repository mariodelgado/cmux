import SwiftUI

struct SidebarRollingOutputPreviewLine: View, Equatable {
    private static let normalColor = Color(
        red: 0xA6 / 255.0,
        green: 0xAD / 255.0,
        blue: 0xC8 / 255.0
    )
    private static let idleColor = Color(
        red: 0x6C / 255.0,
        green: 0x70 / 255.0,
        blue: 0x86 / 255.0
    )
    private static let idleInterval: TimeInterval = 9
    private static let freshInterval: TimeInterval = 0.75

    let preview: SidebarRollingOutputPreview
    let fontScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    nonisolated static func == (
        lhs: SidebarRollingOutputPreviewLine,
        rhs: SidebarRollingOutputPreviewLine
    ) -> Bool {
        lhs.preview == rhs.preview &&
            lhs.fontScale == rhs.fontScale
    }

    var body: some View {
        TimelineView(.periodic(from: preview.lastChangedAt, by: 0.5)) { timeline in
            let age = timeline.date.timeIntervalSince(preview.lastChangedAt)
            let isFresh = age < Self.freshInterval
            let isIdle = age >= Self.idleInterval
            Text(preview.text)
                .font(.custom("SFMono Nerd Font", size: max(8, 10 * fontScale)))
                .fontWeight(emphasizesWithoutColor(isFresh: isFresh) ? .semibold : .regular)
                .foregroundStyle(isIdle ? Self.idleColor : Self.normalColor)
                .opacity(opacity(isFresh: isFresh, isIdle: isIdle))
                .lineLimit(1)
                .truncationMode(.tail)
                .contentTransition(.opacity)
                .scaleEffect(isFresh && !reduceMotion ? 1.018 : 1, anchor: .leading)
                .animation(reduceMotion ? .default : .smooth(duration: 0.24), value: preview.revision)
                .animation(.easeInOut(duration: 0.25), value: isIdle)
        }
    }

    private func emphasizesWithoutColor(isFresh: Bool) -> Bool {
        isFresh && (differentiateWithoutColor || reduceTransparency)
    }

    private func opacity(isFresh: Bool, isIdle: Bool) -> Double {
        if isFresh { return 1 }
        if isIdle {
            return differentiateWithoutColor || reduceTransparency ? 0.74 : 0.54
        }
        return 0.88
    }
}
