import Foundation

struct NewTerminalLauncherCandidateResolver: Sendable {
    func remoteCards(
        sshConfigText: String,
        zshHistoryText: String?,
        bashHistoryText: String?,
        tailscaleDevices: [NewTerminalLauncherTailscaleDevice] = []
    ) -> [NewTerminalLauncherCardSnapshot] {
        let configEntries = NewTerminalLauncherSSHConfigParser().parse(sshConfigText)
        let invocations = historyInvocations(
            zshHistoryText: zshHistoryText,
            bashHistoryText: bashHistoryText
        )

        var configByAlias: [String: NewTerminalLauncherSSHConfigEntry] = [:]
        for entry in configEntries where configByAlias[entry.aliasKey] == nil {
            configByAlias[entry.aliasKey] = entry
        }
        let configByDestination = Dictionary(
            grouping: configEntries,
            by: \.destinationKey
        ).compactMapValues(\.first)

        var historyByKey: [String: HistoryAggregate] = [:]
        var rawDestinationByKey: [String: String] = [:]
        for invocation in invocations {
            let rawKey = NewTerminalLauncherSSHConfigEntry.normalizedDestinationKey(invocation.destination)
            let matchedConfig = configByAlias[rawKey] ?? configByDestination[rawKey]
            let key = matchedConfig?.destinationKey ?? rawKey
            rawDestinationByKey[key] = invocation.destination
            historyByKey[key, default: HistoryAggregate()].record(invocation)
        }

        // Index Tailscale devices by every key they can be matched against, so an
        // ssh-config Host or a history destination that resolves to a MagicDNS
        // name / 100.x IP shows ONE card (enriched), not a duplicate.
        var deviceByKey: [String: NewTerminalLauncherTailscaleDevice] = [:]
        for device in tailscaleDevices {
            for key in device.matchKeys where deviceByKey[key] == nil {
                deviceByKey[key] = device
            }
        }
        var consumedDeviceNames = Set<String>()

        func matchedDevice(forKeys keys: [String?]) -> NewTerminalLauncherTailscaleDevice? {
            for key in keys {
                guard let key else { continue }
                let normalized = NewTerminalLauncherSSHConfigEntry.normalizedDestinationKey(key)
                if let device = deviceByKey[normalized] {
                    return device
                }
            }
            return nil
        }

        var consumedKeys = Set<String>()
        var cards: [RankedCard] = []
        for entry in configEntries {
            let aggregate = historyByKey[entry.destinationKey] ?? historyByKey[entry.aliasKey]
            consumedKeys.insert(entry.destinationKey)
            consumedKeys.insert(entry.aliasKey)
            let device = matchedDevice(forKeys: [entry.alias, entry.hostName, entry.displayHostName])
            if let device {
                consumedDeviceNames.insert(device.magicDNSName)
            }
            cards.append(
                RankedCard(
                    snapshot: NewTerminalLauncherCardSnapshot(
                        id: "ssh:\(entry.destinationKey)",
                        kind: .ssh,
                        title: entry.alias,
                        subtitle: entry.displayUserAndHost,
                        destination: entry.alias,
                        lastUsedAt: aggregate?.lastUsedAt,
                        useCount: aggregate?.useCount ?? 0,
                        tailscalePresence: device.map { $0.online ? .online : .offline },
                        tailscaleOS: device?.os
                    ),
                    rank: Rank(
                        wasUsed: aggregate != nil,
                        lastUsedAt: aggregate?.lastUsedAt,
                        lastSequence: aggregate?.lastSequence ?? 0,
                        useCount: aggregate?.useCount ?? 0,
                        tailscaleOnline: device?.online ?? false,
                        title: entry.alias
                    )
                )
            )
        }

        for (key, aggregate) in historyByKey where !consumedKeys.contains(key) {
            let destination = rawDestinationByKey[key] ?? key
            let device = matchedDevice(forKeys: [destination, key])
            if let device {
                consumedDeviceNames.insert(device.magicDNSName)
            }
            cards.append(
                RankedCard(
                    snapshot: NewTerminalLauncherCardSnapshot(
                        id: "ssh:\(key)",
                        kind: .ssh,
                        title: destination,
                        subtitle: destination,
                        destination: destination,
                        lastUsedAt: aggregate.lastUsedAt,
                        useCount: aggregate.useCount,
                        tailscalePresence: device.map { $0.online ? .online : .offline },
                        tailscaleOS: device?.os
                    ),
                    rank: Rank(
                        wasUsed: true,
                        lastUsedAt: aggregate.lastUsedAt,
                        lastSequence: aggregate.lastSequence,
                        useCount: aggregate.useCount,
                        tailscaleOnline: device?.online ?? false,
                        title: destination
                    )
                )
            )
        }

        // Tailscale-only devices (not represented by any ssh-config / history card).
        for device in tailscaleDevices where !consumedDeviceNames.contains(device.magicDNSName) {
            guard let destination = device.sshDestination else { continue }
            consumedDeviceNames.insert(device.magicDNSName)
            let subtitle = device.tailscaleIP.map { "\(device.magicDNSName) (\($0))" } ?? device.magicDNSName
            cards.append(
                RankedCard(
                    snapshot: NewTerminalLauncherCardSnapshot(
                        id: "tailscale:\(device.magicDNSName.lowercased())",
                        kind: .tailscale,
                        title: device.hostLabel,
                        subtitle: subtitle,
                        destination: destination,
                        lastUsedAt: nil,
                        useCount: 0,
                        tailscalePresence: device.online ? .online : .offline,
                        tailscaleOS: device.os
                    ),
                    rank: Rank(
                        wasUsed: false,
                        lastUsedAt: nil,
                        lastSequence: 0,
                        useCount: 0,
                        tailscaleOnline: device.online,
                        title: device.hostLabel
                    )
                )
            )
        }

        return cards.sorted { lhs, rhs in
            lhs.rank.sortsBefore(rhs.rank)
        }.map(\.snapshot)
    }

    private func historyInvocations(
        zshHistoryText: String?,
        bashHistoryText: String?
    ) -> [NewTerminalLauncherHistoryInvocation] {
        let parser = NewTerminalLauncherShellHistoryParser()
        var invocations: [NewTerminalLauncherHistoryInvocation] = []
        if let zshHistoryText {
            invocations += parser.parse(zshHistoryText, startingSequence: invocations.count)
        }
        if let bashHistoryText {
            invocations += parser.parse(bashHistoryText, startingSequence: invocations.count)
        }
        return invocations
    }
}

private struct HistoryAggregate: Sendable {
    var useCount = 0
    var lastUsedAt: Date?
    var lastSequence = 0

    mutating func record(_ invocation: NewTerminalLauncherHistoryInvocation) {
        useCount += 1
        lastSequence = max(lastSequence, invocation.sequence)
        if let invocationDate = invocation.lastUsedAt {
            if let current = lastUsedAt {
                lastUsedAt = max(current, invocationDate)
            } else {
                lastUsedAt = invocationDate
            }
        }
    }
}

private struct RankedCard: Sendable {
    let snapshot: NewTerminalLauncherCardSnapshot
    let rank: Rank
}

private struct Rank: Sendable {
    let wasUsed: Bool
    let lastUsedAt: Date?
    let lastSequence: Int
    let useCount: Int
    let tailscaleOnline: Bool
    let title: String

    func sortsBefore(_ other: Rank) -> Bool {
        if wasUsed != other.wasUsed {
            return wasUsed
        }
        if let lastUsedAt,
           let otherLastUsedAt = other.lastUsedAt,
           lastUsedAt != otherLastUsedAt {
            return lastUsedAt > otherLastUsedAt
        }
        if (lastUsedAt == nil) != (other.lastUsedAt == nil) {
            return lastUsedAt != nil
        }
        if lastSequence != other.lastSequence {
            return lastSequence > other.lastSequence
        }
        if useCount != other.useCount {
            return useCount > other.useCount
        }
        // Online Tailscale devices float above offline ones.
        if tailscaleOnline != other.tailscaleOnline {
            return tailscaleOnline
        }
        return title.localizedCaseInsensitiveCompare(other.title) == .orderedAscending
    }
}
