import Foundation

/// A Tailscale device that survived the launcher's tailnet filters.
struct NewTerminalLauncherTailscaleDevice: Equatable, Sendable {
    /// First DNS label, e.g. "mario-servarica" from "mario-servarica.tailbedcfa.ts.net".
    let hostLabel: String
    /// Full MagicDNS name without a trailing dot, e.g. "mario-servarica.tailbedcfa.ts.net".
    let magicDNSName: String
    /// Preferred Tailscale IP (100.x), if any.
    let tailscaleIP: String?
    /// Lowercased OS string, e.g. "linux", "macos".
    let os: String?
    let online: Bool

    /// Preferred SSH destination: MagicDNS name if present, else the 100.x IP.
    var sshDestination: String? {
        if !magicDNSName.isEmpty { return magicDNSName }
        return tailscaleIP
    }

    /// Keys this device can be matched against when de-duping with ssh-config /
    /// history cards: the MagicDNS name, the first label, and any 100.x IP.
    var matchKeys: Set<String> {
        var keys = Set<String>()
        func add(_ value: String?) {
            guard let value else { return }
            let normalized = NewTerminalLauncherSSHConfigEntry.normalizedDestinationKey(value)
            if !normalized.isEmpty { keys.insert(normalized) }
        }
        add(magicDNSName)
        add(hostLabel)
        add(tailscaleIP)
        return keys
    }
}

enum NewTerminalLauncherTailscaleFilter {
    /// Translate a decoded status payload into the filtered device list, applying
    /// the launcher's tailnet rules.
    static func devices(
        from status: NewTerminalLauncherTailscaleStatus
    ) -> [NewTerminalLauncherTailscaleDevice] {
        guard let selfDNS = status.`self`?.dnsName,
              let tailnetDomain = tailnetDomain(fromSelfDNSName: selfDNS) else {
            return []
        }

        var devices: [NewTerminalLauncherTailscaleDevice] = []
        for node in (status.peer ?? [:]).values {
            guard let device = device(from: node, tailnetDomain: tailnetDomain) else { continue }
            devices.append(device)
        }

        return devices.sorted { lhs, rhs in
            if lhs.online != rhs.online { return lhs.online }
            return lhs.hostLabel.localizedCaseInsensitiveCompare(rhs.hostLabel) == .orderedAscending
        }
    }

    /// Hosts we present by default. The brief: prefer OS in {linux, macOS},
    /// hide phones/tablets (iOS/android) by default.
    static let preferredOSValues: Set<String> = ["linux", "macos"]

    static func tailnetDomain(fromSelfDNSName selfDNS: String) -> String? {
        let trimmed = trimDNSName(selfDNS)
        guard let firstDot = trimmed.firstIndex(of: ".") else { return nil }
        let domain = String(trimmed[trimmed.index(after: firstDot)...])
        return domain.isEmpty ? nil : domain
    }

    private static func device(
        from node: NewTerminalLauncherTailscaleStatus.Node,
        tailnetDomain: String
    ) -> NewTerminalLauncherTailscaleDevice? {
        guard let rawDNS = node.dnsName else { return nil }
        let dnsName = trimDNSName(rawDNS)
        guard !dnsName.isEmpty else { return nil }

        // Same tailnet only.
        let suffix = "." + tailnetDomain
        guard dnsName.hasSuffix(suffix) || dnsName == tailnetDomain else { return nil }

        // Exclude Mullvad exit nodes (and any DNS containing "mullvad").
        let lowered = dnsName.lowercased()
        if lowered.contains("mullvad") { return nil }
        if node.exitNode == true { return nil }

        let os = node.os?.lowercased()
        // Default policy: hide non-{linux, macOS} (phones/tablets).
        if let os, !preferredOSValues.contains(os) { return nil }
        if os == nil { return nil }

        let hostLabel: String = {
            if let firstDot = dnsName.firstIndex(of: ".") {
                return String(dnsName[..<firstDot])
            }
            return dnsName
        }()

        let ip = preferredTailscaleIP(node.tailscaleIPs)

        return NewTerminalLauncherTailscaleDevice(
            hostLabel: hostLabel,
            magicDNSName: dnsName,
            tailscaleIP: ip,
            os: os,
            online: node.online ?? false
        )
    }

    private static func preferredTailscaleIP(_ ips: [String]?) -> String? {
        guard let ips else { return nil }
        // Prefer the IPv4 100.x address.
        if let v4 = ips.first(where: { $0.hasPrefix("100.") }) {
            return v4
        }
        return ips.first
    }

    private static func trimDNSName(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix(".") {
            trimmed.removeLast()
        }
        return trimmed
    }
}
