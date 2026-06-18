import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite struct NewTerminalLauncherCandidateResolverTests {
    @Test func parsesConfigExcludesWildcardsAndRanksUsedHostsFirst() {
        let config = """
        Host prod
          HostName prod.example.com
          User deploy

        Host *.internal *
          HostName ignored.example.com
          User ignored

        Host staging
          HostName staging.example.com
          User ubuntu

        Host archive
          HostName archive.example.com
          User ops
        """
        let zshHistory = """
        : 1700000000:0;ssh staging
        : 1700000100:0;ssh -p 2222 prod
        : 1700000200:0;mosh raw.example.net
        """

        let cards = NewTerminalLauncherCandidateResolver().remoteCards(
            sshConfigText: config,
            zshHistoryText: zshHistory,
            bashHistoryText: nil
        )

        #expect(cards.map(\.title) == ["raw.example.net", "prod", "staging", "archive"])
        #expect(!cards.contains { $0.title == "*.internal" || $0.title == "*" })
        #expect(cards.first(where: { $0.title == "prod" })?.subtitle == "deploy@prod.example.com")
        #expect(cards.first(where: { $0.title == "archive" })?.lastUsedAt == nil)
    }

    @Test func historyAliasMatchesConfigAndKeepsAliasDestination() throws {
        let config = """
        Host workbox
          HostName 10.0.0.2
          User ec2-user
        """
        let history = ": 1700000000:0;ssh workbox\n"

        let card = try #require(
            NewTerminalLauncherCandidateResolver()
                .remoteCards(sshConfigText: config, zshHistoryText: history, bashHistoryText: nil)
                .first
        )

        #expect(card.title == "workbox")
        #expect(card.subtitle == "ec2-user@10.0.0.2")
        #expect(card.destination == "workbox")
        #expect(card.useCount == 1)
    }

    @Test func skipsSSHOptionsWhenExtractingDestination() throws {
        let history = "ssh -J bastion -l deploy -p 2222 target.example.com\n"

        let card = try #require(
            NewTerminalLauncherCandidateResolver()
                .remoteCards(sshConfigText: "", zshHistoryText: history, bashHistoryText: nil)
                .first
        )

        #expect(card.title == "target.example.com")
        #expect(card.destination == "target.example.com")
    }
}
