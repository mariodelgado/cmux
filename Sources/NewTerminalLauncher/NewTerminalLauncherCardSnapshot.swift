import Foundation

struct NewTerminalLauncherCardSnapshot: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case localShell
        case ssh
        case tailscale
    }

    /// Tailscale presence for a card (online/offline dot + OS icon hint).
    enum TailscalePresence: Equatable, Sendable {
        case online
        case offline
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let destination: String?
    let lastUsedAt: Date?
    let useCount: Int
    /// When non-nil, the card is backed by (or enriched with) a Tailscale device.
    let tailscalePresence: TailscalePresence?
    /// Lowercased Tailscale OS string ("linux", "macos") for icon selection.
    let tailscaleOS: String?

    init(
        id: String,
        kind: Kind,
        title: String,
        subtitle: String,
        destination: String?,
        lastUsedAt: Date?,
        useCount: Int,
        tailscalePresence: TailscalePresence? = nil,
        tailscaleOS: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.destination = destination
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.tailscalePresence = tailscalePresence
        self.tailscaleOS = tailscaleOS
    }

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
