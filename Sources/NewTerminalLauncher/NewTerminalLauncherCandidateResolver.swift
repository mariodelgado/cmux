import Foundation

struct NewTerminalLauncherCandidateResolver: Sendable {
    func remoteCards(
        sshConfigText: String,
        zshHistoryText: String?,
        bashHistoryText: String?
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

        var consumedKeys = Set<String>()
        var cards: [RankedCard] = []
        for entry in configEntries {
            let aggregate = historyByKey[entry.destinationKey] ?? historyByKey[entry.aliasKey]
            consumedKeys.insert(entry.destinationKey)
            consumedKeys.insert(entry.aliasKey)
            cards.append(
                RankedCard(
                    snapshot: NewTerminalLauncherCardSnapshot(
                        id: "ssh:\(entry.destinationKey)",
                        kind: .ssh,
                        title: entry.alias,
                        subtitle: entry.displayUserAndHost,
                        destination: entry.alias,
                        lastUsedAt: aggregate?.lastUsedAt,
                        useCount: aggregate?.useCount ?? 0
                    ),
                    rank: Rank(
                        wasUsed: aggregate != nil,
                        lastUsedAt: aggregate?.lastUsedAt,
                        lastSequence: aggregate?.lastSequence ?? 0,
                        useCount: aggregate?.useCount ?? 0,
                        title: entry.alias
                    )
                )
            )
        }

        for (key, aggregate) in historyByKey where !consumedKeys.contains(key) {
            let destination = rawDestinationByKey[key] ?? key
            cards.append(
                RankedCard(
                    snapshot: NewTerminalLauncherCardSnapshot(
                        id: "ssh:\(key)",
                        kind: .ssh,
                        title: destination,
                        subtitle: destination,
                        destination: destination,
                        lastUsedAt: aggregate.lastUsedAt,
                        useCount: aggregate.useCount
                    ),
                    rank: Rank(
                        wasUsed: true,
                        lastUsedAt: aggregate.lastUsedAt,
                        lastSequence: aggregate.lastSequence,
                        useCount: aggregate.useCount,
                        title: destination
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
        return title.localizedCaseInsensitiveCompare(other.title) == .orderedAscending
    }
}
