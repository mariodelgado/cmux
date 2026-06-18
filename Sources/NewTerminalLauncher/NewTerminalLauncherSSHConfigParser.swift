import Foundation

struct NewTerminalLauncherSSHConfigParser: Sendable {
    func parse(_ text: String) -> [NewTerminalLauncherSSHConfigEntry] {
        var entries: [NewTerminalLauncherSSHConfigEntry] = []
        var currentAliases: [String] = []
        var currentHostName: String?
        var currentUser: String?

        func flushCurrentBlock() {
            guard !currentAliases.isEmpty else { return }
            for alias in currentAliases {
                entries.append(
                    NewTerminalLauncherSSHConfigEntry(
                        alias: alias,
                        hostName: currentHostName,
                        user: currentUser
                    )
                )
            }
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = sanitizedLine(String(rawLine))
            guard !line.isEmpty else { continue }
            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let key = parts.first?.lowercased() else { continue }
            let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""

            switch key {
            case "host":
                flushCurrentBlock()
                currentAliases = hostPatterns(in: value).filter { !Self.isWildcardHostPattern($0) }
                currentHostName = nil
                currentUser = nil
            case "match":
                flushCurrentBlock()
                currentAliases = []
                currentHostName = nil
                currentUser = nil
            case "hostname":
                if !currentAliases.isEmpty {
                    currentHostName = unquoted(value)
                }
            case "user":
                if !currentAliases.isEmpty {
                    currentUser = unquoted(value)
                }
            default:
                continue
            }
        }

        flushCurrentBlock()
        return entries
    }

    private func sanitizedLine(_ rawLine: String) -> String {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("#") else { return "" }
        var result = ""
        var isEscaped = false
        var quote: Character?

        for character in trimmed {
            if isEscaped {
                result.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                result.append(character)
                continue
            }
            if character == "\"" || character == "'" {
                if quote == character {
                    quote = nil
                } else if quote == nil {
                    quote = character
                }
                result.append(character)
                continue
            }
            if character == "#", quote == nil {
                break
            }
            result.append(character)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hostPatterns(in value: String) -> [String] {
        NewTerminalLauncherShellCommandTokenizer()
            .tokens(in: value)
            .map(unquoted)
            .filter { !$0.isEmpty && !$0.hasPrefix("!") }
    }

    private func unquoted(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              let first = trimmed.first,
              let last = trimmed.last,
              (first == "\"" || first == "'"),
              first == last else {
            return trimmed
        }
        return String(trimmed.dropFirst().dropLast())
    }

    private static func isWildcardHostPattern(_ pattern: String) -> Bool {
        pattern.contains("*") || pattern.contains("?")
    }
}
