import Foundation

/// Decoded subset of `tailscale status --json`.
///
/// Only the fields the launcher needs are modeled; unknown keys are ignored by
/// `JSONDecoder`. All fields are optional because the CLI output shape varies
/// across Tailscale versions and login states.
struct NewTerminalLauncherTailscaleStatus: Decodable, Sendable {
    struct Node: Decodable, Sendable {
        let dnsName: String?
        let hostName: String?
        let tailscaleIPs: [String]?
        let os: String?
        let online: Bool?
        let exitNode: Bool?

        enum CodingKeys: String, CodingKey {
            case dnsName = "DNSName"
            case hostName = "HostName"
            case tailscaleIPs = "TailscaleIPs"
            case os = "OS"
            case online = "Online"
            case exitNode = "ExitNode"
        }
    }

    let `self`: Node?
    let peer: [String: Node]?

    enum CodingKeys: String, CodingKey {
        case `self` = "Self"
        case peer = "Peer"
    }
}
