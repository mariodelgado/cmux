import Foundation

actor NewTerminalLauncherCandidateCache {
    private let sshConfigPath: String
    private let zshHistoryPath: String
    private let bashHistoryPath: String
    private let tailscaleClient: NewTerminalLauncherTailscaleClient?
    /// Minimum interval between `tailscale status` invocations (it can be slow/large).
    private let tailscaleRefreshInterval: TimeInterval
    private let tailscaleEnabledProvider: @Sendable () -> Bool

    private var cachedSignature: InputSignature?
    private var cachedCards: [NewTerminalLauncherCardSnapshot] = []

    private var cachedTailscaleDevices: [NewTerminalLauncherTailscaleDevice] = []
    private var lastTailscaleRefresh: Date?

    init(
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        tailscaleClient: NewTerminalLauncherTailscaleClient? = NewTerminalLauncherTailscaleClient(),
        tailscaleRefreshInterval: TimeInterval = 30,
        tailscaleEnabledProvider: @escaping @Sendable () -> Bool = { NewTerminalLauncherSettings.isTailscaleEnabled() }
    ) {
        sshConfigPath = (homeDirectory as NSString).appendingPathComponent(".ssh/config")
        zshHistoryPath = (homeDirectory as NSString).appendingPathComponent(".zsh_history")
        bashHistoryPath = (homeDirectory as NSString).appendingPathComponent(".bash_history")
        self.tailscaleClient = tailscaleClient
        self.tailscaleRefreshInterval = tailscaleRefreshInterval
        self.tailscaleEnabledProvider = tailscaleEnabledProvider
    }

    func remoteCards() async -> [NewTerminalLauncherCardSnapshot] {
        let devices = refreshedTailscaleDevices()
        let signature = InputSignature(
            sshConfig: FileSignature(path: sshConfigPath),
            zshHistory: FileSignature(path: zshHistoryPath),
            bashHistory: FileSignature(path: bashHistoryPath),
            tailscaleDeviceCount: devices.count,
            tailscaleOnlineCount: devices.lazy.filter(\.online).count
        )
        if signature == cachedSignature {
            return cachedCards
        }

        let resolver = NewTerminalLauncherCandidateResolver()
        let cards = resolver.remoteCards(
            sshConfigText: Self.readText(atPath: sshConfigPath) ?? "",
            zshHistoryText: Self.readText(atPath: zshHistoryPath),
            bashHistoryText: Self.readText(atPath: bashHistoryPath),
            tailscaleDevices: devices
        )
        cachedSignature = signature
        cachedCards = cards
        return cards
    }

    /// Re-run `tailscale status` at most once per refresh interval; otherwise
    /// return the cached device list. Disabled flag => no devices (and no run).
    private func refreshedTailscaleDevices() -> [NewTerminalLauncherTailscaleDevice] {
        guard let tailscaleClient, tailscaleEnabledProvider() else {
            cachedTailscaleDevices = []
            lastTailscaleRefresh = nil
            return []
        }
        let now = Date()
        if let last = lastTailscaleRefresh,
           now.timeIntervalSince(last) < tailscaleRefreshInterval {
            return cachedTailscaleDevices
        }
        let devices = tailscaleClient.devices()
        cachedTailscaleDevices = devices
        lastTailscaleRefresh = now
        return devices
    }

    private static func readText(atPath path: String) -> String? {
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
}

private struct InputSignature: Equatable, Sendable {
    let sshConfig: FileSignature
    let zshHistory: FileSignature
    let bashHistory: FileSignature
    let tailscaleDeviceCount: Int
    let tailscaleOnlineCount: Int
}

private struct FileSignature: Equatable, Sendable {
    let exists: Bool
    let modificationDate: Date?
    let size: UInt64?

    init(path: String) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            exists = false
            modificationDate = nil
            size = nil
            return
        }
        exists = true
        modificationDate = attributes[.modificationDate] as? Date
        size = attributes[.size] as? UInt64
    }
}
