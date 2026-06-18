import Foundation

struct NewTerminalLauncherShellHistoryParser: Sendable {
    func parse(_ text: String, startingSequence: Int = 0) -> [NewTerminalLauncherHistoryInvocation] {
        var invocations: [NewTerminalLauncherHistoryInvocation] = []
        var sequence = startingSequence

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            sequence += 1
            let entry = historyEntry(from: String(rawLine), sequence: sequence)
            guard let entry else { continue }
            invocations.append(entry)
        }

        return invocations
    }

    private func historyEntry(from line: String, sequence: Int) -> NewTerminalLauncherHistoryInvocation? {
        let parsed = zshExtendedHistoryCommand(from: line) ?? (command: line, timestamp: nil)
        let command = parsed.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return nil }

        let tokens = NewTerminalLauncherShellCommandTokenizer().tokens(in: command)
        guard let destination = sshDestination(in: tokens) else { return nil }
        return NewTerminalLauncherHistoryInvocation(
            destination: destination,
            lastUsedAt: parsed.timestamp,
            sequence: sequence
        )
    }

    private func zshExtendedHistoryCommand(from line: String) -> (command: String, timestamp: Date?)? {
        guard line.hasPrefix(": ") else { return nil }
        let body = line.dropFirst(2)
        guard let firstColon = body.firstIndex(of: ":"),
              let semicolon = body[firstColon...].firstIndex(of: ";") else {
            return nil
        }
        let timestampText = body[..<firstColon].trimmingCharacters(in: .whitespacesAndNewlines)
        let commandStart = body.index(after: semicolon)
        let command = String(body[commandStart...])
        let timestamp = Double(timestampText).map { Date(timeIntervalSince1970: $0) }
        return (command, timestamp)
    }

    private func sshDestination(in tokens: [String]) -> String? {
        guard let commandIndex = tokens.firstIndex(where: { token in
            let commandName = (token as NSString).lastPathComponent
            return commandName == "ssh" || commandName == "mosh"
        }) else {
            return nil
        }

        let commandName = (tokens[commandIndex] as NSString).lastPathComponent
        var index = commandIndex + 1
        while index < tokens.count {
            let token = tokens[index]
            if token == "--" {
                index += 1
                break
            }
            guard token.hasPrefix("-") else {
                break
            }

            let skipValue = commandName == "mosh"
                ? moshOptionConsumesFollowingValue(token)
                : sshOptionConsumesFollowingValue(token)
            index += skipValue ? 2 : 1
        }

        guard index < tokens.count else { return nil }
        let destination = tokens[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty, !destination.hasPrefix("-") else { return nil }
        return destination
    }

    private func sshOptionConsumesFollowingValue(_ option: String) -> Bool {
        let singleValueOptions: Set<Character> = [
            "b", "c", "D", "E", "F", "I", "J", "L", "l", "m",
            "O", "o", "p", "Q", "R", "S", "W", "w"
        ]
        guard option.hasPrefix("-"), !option.hasPrefix("--") else { return false }
        guard option.count == 2, let optionName = option.last else { return false }
        return singleValueOptions.contains(optionName)
    }

    private func moshOptionConsumesFollowingValue(_ option: String) -> Bool {
        let longValueOptions: Set<String> = [
            "--port",
            "--server",
            "--ssh",
            "--predict",
            "--bind-server",
            "--experimental-remote-ip"
        ]
        if longValueOptions.contains(option) {
            return true
        }
        if option.hasPrefix("--"), option.contains("=") {
            return false
        }
        return option == "-p" || option == "-s"
    }
}
