import Foundation

struct NewTerminalLauncherCardSnapshot: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case localShell
        case ssh
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let destination: String?
    let lastUsedAt: Date?
    let useCount: Int

    static func localShell(subtitle: String) -> NewTerminalLauncherCardSnapshot {
        NewTerminalLauncherCardSnapshot(
            id: "local-shell",
            kind: .localShell,
            title: String(localized: "newTerminalLauncher.localShell.title", defaultValue: "Local Shell"),
            subtitle: subtitle,
            destination: nil,
            lastUsedAt: nil,
            useCount: 0
        )
    }
}
