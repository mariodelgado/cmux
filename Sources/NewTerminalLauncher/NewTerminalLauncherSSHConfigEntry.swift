import Foundation

struct NewTerminalLauncherSSHConfigEntry: Equatable, Sendable {
    let alias: String
    let hostName: String?
    let user: String?

    var displayHostName: String {
        guard let hostName,
              !hostName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return alias
        }
        return hostName
    }

    var displayUserAndHost: String {
        if let user, !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(user)@\(displayHostName)"
        }
        return displayHostName
    }

    var destinationKey: String {
        Self.normalizedDestinationKey(displayUserAndHost)
    }

    var aliasKey: String {
        Self.normalizedDestinationKey(alias)
    }

    static func normalizedDestinationKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
