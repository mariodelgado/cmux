import CmuxAgentChat
import Foundation
import SwiftUI

struct ParsedPaneActions {
    let sendInput: (String) -> Void
    let sendReturnTerminatedInput: (String) -> Void
}

protocol ParsedRenderer: Sendable {
    var id: String { get }
    var displayTitle: String { get }
    func canRender(_ content: ParsedPaneContent) -> Double
    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot
    @MainActor func view(snapshot: ParsedPaneRenderSnapshot, actions: ParsedPaneActions) -> AnyView
}

extension ParsedRenderer {
    @MainActor
    func view(snapshot: ParsedPaneRenderSnapshot, actions: ParsedPaneActions) -> AnyView {
        AnyView(ParsedPaneSnapshotView(snapshot: snapshot, actions: actions))
    }

    func makeSnapshot(payload: ParsedPanePayload, content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        ParsedPaneRenderSnapshot(
            rendererID: id,
            title: displayTitle,
            confidence: confidence,
            generatedAt: Date(),
            sourceLineCount: content.lines.count,
            payload: payload
        )
    }
}

struct ParsedRendererRegistry: Sendable {
    let renderers: [any ParsedRenderer]
    let fallback: any ParsedRenderer

    static let `default` = ParsedRendererRegistry(
        renderers: [
            ParsedAgentTranscriptRenderer(),
            ParsedDiffRenderer(),
            ParsedTestOutputRenderer(),
            ParsedJSONRenderer(),
            ParsedLogRenderer(),
            ParsedFileListingRenderer(),
            ParsedTableRenderer(),
        ],
        fallback: ParsedReaderRenderer()
    )
}

struct ParsedViewDetector: Sendable {
    static let defaultConfidenceThreshold = 0.55

    let registry: ParsedRendererRegistry
    let threshold: Double

    init(
        registry: ParsedRendererRegistry = .default,
        threshold: Double = ParsedViewDetector.defaultConfidenceThreshold
    ) {
        self.registry = registry
        self.threshold = threshold
    }

    func detect(_ content: ParsedPaneContent) -> ParsedPaneRenderSnapshot {
        let candidate = registry.renderers
            .map { renderer in (renderer: renderer, confidence: renderer.canRender(content)) }
            .max { lhs, rhs in lhs.confidence < rhs.confidence }

        guard let candidate, candidate.confidence >= threshold else {
            return registry.fallback.snapshot(for: content, confidence: 0)
        }
        return candidate.renderer.snapshot(for: content, confidence: candidate.confidence)
    }
}

struct ParsedAgentTranscriptRenderer: ParsedRenderer {
    let id = "agent"
    let displayTitle = "Agent"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let lines = transcriptLines(from: content)
        guard !lines.isEmpty else { return 0 }
        return lines.count >= 2 ? 0.96 : 0.72
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        let lines = transcriptLines(from: content)
        let result = ClaudeTranscriptParser().parse(lines: lines, startingSeq: 0)
        let messages = result.messages.suffix(500)
        return makeSnapshot(
            payload: .agent(ParsedAgentTranscript(messages: Array(messages))),
            content: content,
            confidence: confidence
        )
    }

    private func transcriptLines(from content: ParsedPaneContent) -> [String] {
        content.lines.compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("{"), line.hasSuffix("}") else { return nil }
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String,
                  (type == "user" || type == "assistant"),
                  object["message"] != nil else {
                return nil
            }
            return line
        }
    }
}

struct ParsedDiffRenderer: ParsedRenderer {
    let id = "diff"
    let displayTitle = "Diff"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let text = content.plainText
        if text.contains("diff --git ") { return 0.95 }
        if text.contains("\n@@ ") && text.contains("\n--- ") && text.contains("\n+++ ") {
            return 0.9
        }
        return 0
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(
            payload: .diff(ParsedDiffSnapshot(files: parseFiles(content.lines))),
            content: content,
            confidence: confidence
        )
    }

    private func parseFiles(_ lines: [String]) -> [ParsedDiffFile] {
        var files: [ParsedDiffFile] = []
        var currentPath = "diff"
        var hunks: [ParsedDiffHunk] = []
        var hunkLines: [ParsedDiffLine] = []
        var hunkHeader = String(localized: "parsedView.diff.fileHeader", defaultValue: "File header")
        var additions = 0
        var deletions = 0
        var fileIndex = 0
        var hunkIndex = 0
        var lineIndex = 0

        func flushHunk() {
            guard !hunkLines.isEmpty else { return }
            hunks.append(ParsedDiffHunk(
                id: "\(fileIndex)-h\(hunkIndex)",
                header: hunkHeader,
                lines: hunkLines
            ))
            hunkIndex += 1
            hunkLines.removeAll(keepingCapacity: true)
        }

        func flushFile() {
            flushHunk()
            guard !hunks.isEmpty else { return }
            files.append(ParsedDiffFile(
                id: "file-\(fileIndex)-\(currentPath)",
                path: currentPath,
                additions: additions,
                deletions: deletions,
                hunks: hunks
            ))
            fileIndex += 1
            hunkIndex = 0
            additions = 0
            deletions = 0
            hunks.removeAll(keepingCapacity: true)
        }

        for line in lines {
            if line.hasPrefix("diff --git ") {
                flushFile()
                currentPath = parseGitDiffPath(line) ?? "diff-\(fileIndex + 1)"
                hunkHeader = String(localized: "parsedView.diff.fileHeader", defaultValue: "File header")
                continue
            }
            if line.hasPrefix("+++ ") {
                currentPath = normalizedDiffPath(line.dropFirst(4)).flatMap { $0.isEmpty ? nil : $0 } ?? currentPath
            }
            if line.hasPrefix("@@ ") {
                flushHunk()
                hunkHeader = line
                continue
            }

            let kind: ParsedDiffLine.Kind
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                kind = .addition
                additions += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                kind = .deletion
                deletions += 1
            } else if line.hasPrefix(" ") {
                kind = .context
            } else {
                kind = .metadata
            }
            hunkLines.append(ParsedDiffLine(
                id: "\(fileIndex)-\(hunkIndex)-\(lineIndex)",
                kind: kind,
                text: line
            ))
            lineIndex += 1
        }
        flushFile()
        return files
    }

    private func parseGitDiffPath(_ line: String) -> String? {
        let pieces = line.split(separator: " ")
        guard pieces.count >= 4 else { return nil }
        return normalizedDiffPath(pieces[3])
    }

    private func normalizedDiffPath(_ raw: Substring) -> String? {
        var value = String(raw)
        if value.hasPrefix("b/") || value.hasPrefix("a/") {
            value.removeFirst(2)
        }
        return value == "/dev/null" ? nil : value
    }
}

struct ParsedTestOutputRenderer: ParsedRenderer {
    let id = "tests"
    let displayTitle = "Tests"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let lower = content.plainText.lowercased()
        let markers = ["pytest", "jest", "cargo test", "go test", "test result:", "failures:", "failed"]
        return markers.contains(where: { lower.contains($0) }) ? 0.82 : 0
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(payload: .tests(parse(content)), content: content, confidence: confidence)
    }

    private func parse(_ content: ParsedPaneContent) -> ParsedTestSnapshot {
        let lines = content.lines
        let summaryLine = lines.reversed().first { line in
            let lower = line.lowercased()
            return lower.contains(" passed") || lower.contains(" failed") || lower.contains("test result:")
        } ?? lines.last ?? ""
        let passed = firstCount(in: summaryLine, before: ["passed", "pass"])
        let failed = firstCount(in: summaryLine, before: ["failed", "failures", "failed."])
        let skipped = firstCount(in: summaryLine, before: ["skipped", "ignored"])
        var failures: [ParsedTestFailure] = []
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            let isFailure = trimmed.hasPrefix("FAILED ")
                || trimmed.hasPrefix("--- FAIL:")
                || trimmed.hasPrefix("FAIL ")
                || trimmed.hasPrefix("● ")
                || lower.hasPrefix("failures:")
            guard isFailure else { continue }
            let message = lines.dropFirst(index + 1).prefix(5).joined(separator: "\n")
            failures.append(ParsedTestFailure(
                id: "failure-\(index)",
                name: trimmed,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        return ParsedTestSnapshot(
            passedCount: passed,
            failedCount: failed ?? (failures.isEmpty ? nil : failures.count),
            skippedCount: skipped,
            failures: Array(failures.prefix(100)),
            rawSummary: summaryLine.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func firstCount(in line: String, before words: [String]) -> Int? {
        let tokens = line
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "=", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        for pair in zip(tokens, tokens.dropFirst()) {
            if let value = Int(pair.0), words.contains(pair.1.lowercased()) {
                return value
            }
        }
        return nil
    }
}

struct ParsedJSONRenderer: ParsedRenderer {
    let id = "json"
    let displayTitle = "JSON"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let trimmed = content.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isJSONObjectOrArray(trimmed) { return 0.86 }
        let jsonLines = content.lines.filter { isJSONObjectOrArray($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return jsonLines.count >= 2 ? 0.8 : 0
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(payload: .json(parse(content)), content: content, confidence: confidence)
    }

    private func parse(_ content: ParsedPaneContent) -> ParsedJSONSnapshot {
        let trimmed = content.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let node = node(forJSONText: trimmed, key: String(localized: "parsedView.json.root", defaultValue: "root"), path: "root") {
            return ParsedJSONSnapshot(roots: [node], isJSONLines: false)
        }
        let roots = content.lines.enumerated().compactMap { index, line in
            node(
                forJSONText: line.trimmingCharacters(in: .whitespacesAndNewlines),
                key: String.localizedStringWithFormat(
                    String(localized: "parsedView.json.lineNumber", defaultValue: "line %d"),
                    index + 1
                ),
                path: "line-\(index)"
            )
        }
        return ParsedJSONSnapshot(roots: roots, isJSONLines: true)
    }

    private func isJSONObjectOrArray(_ text: String) -> Bool {
        guard let first = text.first, (first == "{" || first == "["),
              let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return false
        }
        return true
    }

    private func node(forJSONText text: String, key: String, path: String) -> ParsedJSONNode? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return node(from: object, key: key, path: path)
    }

    private func node(from object: Any, key: String, path: String) -> ParsedJSONNode {
        if let dictionary = object as? [String: Any] {
            let children = dictionary.keys.sorted().map { childKey in
                node(from: dictionary[childKey] as Any, key: childKey, path: "\(path).\(childKey)")
            }
            return ParsedJSONNode(id: path, key: key, summary: "{\(children.count)}", children: children)
        }
        if let array = object as? [Any] {
            let children = array.enumerated().map { index, value in
                node(from: value, key: "[\(index)]", path: "\(path)[\(index)]")
            }
            return ParsedJSONNode(id: path, key: key, summary: "[\(children.count)]", children: children)
        }
        if object is NSNull {
            return ParsedJSONNode(id: path, key: key, summary: "null", children: [])
        }
        if let string = object as? String {
            return ParsedJSONNode(id: path, key: key, summary: "\"\(string)\"", children: [])
        }
        return ParsedJSONNode(id: path, key: key, summary: String(describing: object), children: [])
    }
}

struct ParsedLogRenderer: ParsedRenderer {
    let id = "logs"
    let displayTitle = "Logs"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let entries = parseEntries(content.lines)
        guard entries.count >= 3 else { return 0 }
        let ratio = Double(entries.count) / Double(max(content.lines.count, 1))
        return ratio > 0.35 ? 0.78 : 0
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(payload: .logs(ParsedLogSnapshot(entries: parseEntries(content.lines))), content: content, confidence: confidence)
    }

    private func parseEntries(_ lines: [String]) -> [ParsedLogEntry] {
        lines.enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let lower = trimmed.lowercased()
            let level: ParsedLogLevel?
            if lower.contains(" error") || lower.hasPrefix("error") || lower.hasPrefix("[error]") {
                level = .error
            } else if lower.contains(" warn") || lower.hasPrefix("warn") || lower.hasPrefix("[warn]") {
                level = .warning
            } else if lower.contains(" debug") || lower.hasPrefix("debug") || lower.hasPrefix("[debug]") {
                level = .debug
            } else if lower.contains(" trace") || lower.hasPrefix("trace") || lower.hasPrefix("[trace]") {
                level = .trace
            } else if lower.contains(" fault") || lower.hasPrefix("fault") {
                level = .fault
            } else if lower.contains(" notice") || lower.hasPrefix("notice") {
                level = .notice
            } else if lower.contains(" info") || lower.hasPrefix("info") || lower.hasPrefix("[info]") {
                level = .info
            } else {
                level = journalctlLevel(trimmed)
            }
            guard let level else { return nil }
            return ParsedLogEntry(
                id: "log-\(index)",
                level: level,
                timestamp: leadingTimestamp(trimmed),
                message: trimmed
            )
        }
    }

    private func journalctlLevel(_ line: String) -> ParsedLogLevel? {
        let monthPrefixes = ["Jan ", "Feb ", "Mar ", "Apr ", "May ", "Jun ", "Jul ", "Aug ", "Sep ", "Oct ", "Nov ", "Dec "]
        return monthPrefixes.contains(where: { line.hasPrefix($0) }) ? .info : nil
    }

    private func leadingTimestamp(_ line: String) -> String? {
        if line.count >= 19 {
            let prefix = String(line.prefix(19))
            if prefix.contains(":") && prefix.contains("-") {
                return prefix
            }
        }
        return nil
    }
}

struct ParsedFileListingRenderer: ParsedRenderer {
    let id = "files"
    let displayTitle = "Files"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let entries = parseEntries(content.lines)
        guard entries.count >= 3 else { return 0 }
        return Double(entries.count) / Double(max(content.lines.count, 1)) > 0.5 ? 0.74 : 0
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(
            payload: .fileList(ParsedFileListSnapshot(entries: parseEntries(content.lines))),
            content: content,
            confidence: confidence
        )
    }

    private func parseEntries(_ lines: [String]) -> [ParsedFileEntry] {
        lines.enumerated().compactMap { index, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, line != "total" else { return nil }
            if let entry = parseLongListing(line, index: index) { return entry }
            if let entry = parseTreeLine(rawLine, index: index) { return entry }
            if line.hasPrefix("/") || line.hasPrefix("./") || line.hasPrefix("../") {
                return ParsedFileEntry(
                    id: "path-\(index)",
                    name: URL(fileURLWithPath: line).lastPathComponent.isEmpty ? line : URL(fileURLWithPath: line).lastPathComponent,
                    path: line,
                    kind: line.hasSuffix("/") ? .directory : .unknown,
                    size: nil,
                    permissions: nil,
                    modified: nil,
                    depth: max(0, line.filter { $0 == "/" }.count - 1)
                )
            }
            return nil
        }
    }

    private func parseLongListing(_ line: String, index: Int) -> ParsedFileEntry? {
        let pieces = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard pieces.count >= 9, let first = pieces.first, first.count >= 10 else { return nil }
        let kind: ParsedFileEntry.Kind
        if first.hasPrefix("d") {
            kind = .directory
        } else if first.hasPrefix("l") {
            kind = .symlink
        } else if first.hasPrefix("-") {
            kind = .file
        } else {
            kind = .unknown
        }
        let name = pieces.dropFirst(8).joined(separator: " ")
        return ParsedFileEntry(
            id: "ls-\(index)-\(name)",
            name: name,
            path: name,
            kind: kind,
            size: pieces.count > 4 ? pieces[4] : nil,
            permissions: first,
            modified: pieces.count > 7 ? pieces[5...7].joined(separator: " ") : nil,
            depth: 0
        )
    }

    private func parseTreeLine(_ rawLine: String, index: Int) -> ParsedFileEntry? {
        guard rawLine.contains("├──") || rawLine.contains("└──") || rawLine.contains("|--") || rawLine.contains("`--") else {
            return nil
        }
        let depth = rawLine.prefix { $0 == " " || $0 == "│" || $0 == "|" }.count / 4
        let name = rawLine
            .replacingOccurrences(of: "├──", with: "")
            .replacingOccurrences(of: "└──", with: "")
            .replacingOccurrences(of: "|--", with: "")
            .replacingOccurrences(of: "`--", with: "")
            .trimmingCharacters(in: .whitespaces)
        return ParsedFileEntry(
            id: "tree-\(index)-\(name)",
            name: name,
            path: name,
            kind: name.hasSuffix("/") ? .directory : .unknown,
            size: nil,
            permissions: nil,
            modified: nil,
            depth: depth
        )
    }
}

struct ParsedTableRenderer: ParsedRenderer {
    let id = "table"
    let displayTitle = "Table"

    func canRender(_ content: ParsedPaneContent) -> Double {
        let table = parse(content.lines)
        return table.rows.count >= 2 && table.columns.count >= 2 ? 0.68 : 0
    }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(payload: .table(parse(content.lines)), content: content, confidence: confidence)
    }

    private func parse(_ lines: [String]) -> ParsedTableSnapshot {
        let nonEmpty = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if nonEmpty.count >= 2, nonEmpty.prefix(6).allSatisfy({ $0.contains(",") }) {
            let rows = nonEmpty.map { splitCSVLine($0) }
            return ParsedTableSnapshot(columns: rows.first ?? [], rows: Array(rows.dropFirst().prefix(500)))
        }

        let tokenized = nonEmpty.map { $0.split(whereSeparator: { $0.isWhitespace }).map(String.init) }
        guard let width = tokenized.first?.count, width >= 2 else {
            return ParsedTableSnapshot(columns: [], rows: [])
        }
        let rows = tokenized.filter { abs($0.count - width) <= 1 }
        guard rows.count >= 3 else { return ParsedTableSnapshot(columns: [], rows: []) }
        let header = rows.first ?? []
        return ParsedTableSnapshot(columns: header, rows: Array(rows.dropFirst().prefix(500)))
    }

    private func splitCSVLine(_ line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }
}

struct ParsedReaderRenderer: ParsedRenderer {
    let id = "reader"
    let displayTitle = "Reader"

    func canRender(_ content: ParsedPaneContent) -> Double { 0 }

    func snapshot(for content: ParsedPaneContent, confidence: Double) -> ParsedPaneRenderSnapshot {
        makeSnapshot(
            payload: .reader(ParsedReaderSnapshot(
                markdownText: content.plainText,
                links: content.osc8Links,
                inlineImages: content.inlineImages
            )),
            content: content,
            confidence: confidence
        )
    }
}
