import SwiftUI

struct NewTerminalLauncherCardView: View {
    let snapshot: NewTerminalLauncherCardSnapshot
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 26, height: 26)

                    Spacer(minLength: 8)

                    if let lastUsedText {
                        Text(lastUsedText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(RightSidebarCatppuccinMochaPalette.overlay0)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(RightSidebarCatppuccinMochaPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(snapshot.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(RightSidebarCatppuccinMochaPalette.subtext0)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(minHeight: 132, maxHeight: 148, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .background {
            cardBackground
        }
        .overlay {
            shape.stroke(borderColor, lineWidth: isSelected ? 1.4 : 1)
        }
        .clipShape(shape)
        .shadow(color: Color.black.opacity(isHovered || isSelected ? 0.24 : 0.14), radius: 18, y: 8)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                onSelect()
            }
        }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    @ViewBuilder
    private var cardBackground: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            shape
                .fill(Color.clear)
                .glassEffect(
                    .regular
                        .tint(RightSidebarCatppuccinMochaPalette.surface0.opacity(backgroundTintOpacity))
                        .interactive(isHovered || isSelected),
                    in: shape
                )
                .overlay {
                    shape.fill(selectionFill)
                }
        } else {
            fallbackCardBackground
        }
        #else
        fallbackCardBackground
        #endif
    }

    private var fallbackCardBackground: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(RightSidebarCatppuccinMochaPalette.surface0.opacity(backgroundTintOpacity))
            }
            .overlay {
                shape.fill(selectionFill)
            }
    }

    private var selectionFill: Color {
        if isSelected {
            return RightSidebarCatppuccinMochaPalette.mauve.opacity(0.16)
        }
        if isHovered {
            return RightSidebarCatppuccinMochaPalette.blue.opacity(0.10)
        }
        return .clear
    }

    private var backgroundTintOpacity: Double {
        isHovered || isSelected ? 0.46 : 0.28
    }

    private var borderColor: Color {
        if isSelected {
            return RightSidebarCatppuccinMochaPalette.mauve.opacity(0.78)
        }
        if isHovered {
            return RightSidebarCatppuccinMochaPalette.blue.opacity(0.48)
        }
        return RightSidebarCatppuccinMochaPalette.softHairline
    }

    private var iconName: String {
        switch snapshot.kind {
        case .localShell:
            return "terminal.fill"
        case .ssh:
            return "server.rack"
        }
    }

    private var iconColor: Color {
        switch snapshot.kind {
        case .localShell:
            return RightSidebarCatppuccinMochaPalette.mauve
        case .ssh:
            return RightSidebarCatppuccinMochaPalette.blue
        }
    }

    private var lastUsedText: String? {
        guard let lastUsedAt = snapshot.lastUsedAt else { return nil }
        let relative = NewTerminalLauncherRelativeDateFormatter.shared.localizedString(
            for: lastUsedAt,
            relativeTo: Date()
        )
        return String.localizedStringWithFormat(
            String(localized: "newTerminalLauncher.lastUsed", defaultValue: "Last used %@"),
            relative
        )
    }
}

private enum NewTerminalLauncherRelativeDateFormatter {
    static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
