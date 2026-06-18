import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite struct NewTerminalLauncherTailscaleFilterTests {
    private func status(selfDNS: String, peers: [String: NewTerminalLauncherTailscaleStatus.Node]) -> NewTerminalLauncherTailscaleStatus {
        let payload: [String: Any] = [
            "Self": ["DNSName": selfDNS],
            "Peer": peers.mapValues { node -> [String: Any] in
                var dict: [String: Any] = [:]
                if let v = node.dnsName { dict["DNSName"] = v }
                if let v = node.hostName { dict["HostName"] = v }
                if let v = node.tailscaleIPs { dict["TailscaleIPs"] = v }
                if let v = node.os { dict["OS"] = v }
                if let v = node.online { dict["Online"] = v }
                if let v = node.exitNode { dict["ExitNode"] = v }
                return dict
            },
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(NewTerminalLauncherTailscaleStatus.self, from: data)
    }

    private func node(
        dns: String?,
        host: String? = nil,
        ips: [String]? = nil,
        os: String? = nil,
        online: Bool? = nil,
        exitNode: Bool? = nil
    ) -> NewTerminalLauncherTailscaleStatus.Node {
        .init(dnsName: dns, hostName: host, tailscaleIPs: ips, os: os, online: online, exitNode: exitNode)
    }

    @Test func computesTailnetDomainFromSelf() {
        #expect(
            NewTerminalLauncherTailscaleFilter.tailnetDomain(
                fromSelfDNSName: "marios-macbook-pro.tailbedcfa.ts.net"
            ) == "tailbedcfa.ts.net"
        )
        #expect(
            NewTerminalLauncherTailscaleFilter.tailnetDomain(
                fromSelfDNSName: "host.tailbedcfa.ts.net."
            ) == "tailbedcfa.ts.net"
        )
    }

    @Test func filtersForeignTailnetMullvadExitNodesAndPhones() {
        let s = status(
            selfDNS: "me.tailbedcfa.ts.net",
            peers: [
                "linux": node(dns: "box.tailbedcfa.ts.net", ips: ["100.1.1.1"], os: "linux", online: true),
                "mac": node(dns: "laptop.tailbedcfa.ts.net", ips: ["100.1.1.2"], os: "macOS", online: false),
                "phone": node(dns: "iphone.tailbedcfa.ts.net", os: "iOS", online: true),
                "foreign": node(dns: "x.othernet.ts.net", os: "linux", online: true),
                "mullvad": node(dns: "us-mullvad-exit.tailbedcfa.ts.net", os: "linux", online: true, exitNode: true),
                "exit": node(dns: "exit.tailbedcfa.ts.net", os: "linux", online: true, exitNode: true),
            ]
        )
        let devices = NewTerminalLauncherTailscaleFilter.devices(from: s)
        let labels = devices.map(\.hostLabel)
        #expect(labels.contains("box"))
        #expect(labels.contains("laptop"))
        #expect(!labels.contains("iphone"))
        #expect(!labels.contains { $0 == "x" })
        #expect(!labels.contains { $0.contains("mullvad") })
        #expect(!labels.contains("exit"))
        // Online sorts before offline.
        #expect(devices.first?.hostLabel == "box")
    }

    @Test func mergesEnrichesSSHConfigHostAndDedupes() {
        let device = NewTerminalLauncherTailscaleDevice(
            hostLabel: "mario-servarica",
            magicDNSName: "mario-servarica.tailbedcfa.ts.net",
            tailscaleIP: "100.112.92.19",
            os: "linux",
            online: true
        )
        // ssh-config Host whose HostName is the 100.x IP.
        let config = """
        Host mario.servarica
          HostName 100.112.92.19
          User mario
        """
        let cards = NewTerminalLauncherCandidateResolver().remoteCards(
            sshConfigText: config,
            zshHistoryText: nil,
            bashHistoryText: nil,
            tailscaleDevices: [device]
        )
        // Exactly one card for that host, enriched online, not a duplicate Tailscale-only card.
        let matching = cards.filter { $0.title == "mario.servarica" || $0.kind == .tailscale }
        #expect(matching.count == 1)
        let card = try! #require(cards.first { $0.title == "mario.servarica" })
        #expect(card.kind == .ssh)
        #expect(card.tailscalePresence == .online)
        #expect(card.destination == "mario.servarica")
    }

    @Test func tailscaleOnlyDeviceBecomesItsOwnCard() {
        let device = NewTerminalLauncherTailscaleDevice(
            hostLabel: "buildbox",
            magicDNSName: "buildbox.tailbedcfa.ts.net",
            tailscaleIP: "100.64.0.5",
            os: "linux",
            online: false
        )
        let cards = NewTerminalLauncherCandidateResolver().remoteCards(
            sshConfigText: "",
            zshHistoryText: nil,
            bashHistoryText: nil,
            tailscaleDevices: [device]
        )
        let card = try! #require(cards.first { $0.kind == .tailscale })
        #expect(card.title == "buildbox")
        #expect(card.destination == "buildbox.tailbedcfa.ts.net")
        #expect(card.tailscalePresence == .offline)
    }
}
