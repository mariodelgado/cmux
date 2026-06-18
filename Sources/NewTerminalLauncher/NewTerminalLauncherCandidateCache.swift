import Foundation

actor NewTerminalLauncherCandidateCache {
    private let sshConfigPath: String
    private let zshHistoryPath: String
    private let bashHistoryPath: String
    private var cachedSignature: InputSignature?
    private var cachedCards: [NewTerminalLauncherCardSnapshot] = []

    init(homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        sshConfigPath = (homeDirectory as NSString).appendingPathComponent(".ssh/config")
        zshHistoryPath = (homeDirectory as NSString).appendingPathComponent(".zsh_history")
        bashHistoryPath = (homeDirectory as NSString).appendingPathComponent(".bash_history")
    }

    func remoteCards() async -> [NewTerminalLauncherCardSnapshot] {
        let signature = InputSignature(
            sshConfig: FileSignature(path: sshConfigPath),
            zshHistory: FileSignature(path: zshHistoryPath),
            bashHistory: FileSignature(path: bashHistoryPath)
        )
        if signature == cachedSignature {
            return cachedCards
        }

        let resolver = NewTerminalLauncherCandidateResolver()
        let cards = resolver.remoteCards(
            sshConfigText: Self.readText(atPath: sshConfigPath) ?? "",
            zshHistoryText: Self.readText(atPath: zshHistoryPath),
            bashHistoryText: Self.readText(atPath: bashHistoryPath)
        )
        cachedSignature = signature
        cachedCards = cards
        return cards
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
