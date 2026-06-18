import CmuxAgentChat
import Foundation

enum ParsedPaneMode: String, CaseIterable, Identifiable {
    case terminal
    case parsed

    var id: String { rawValue }
}

struct ParsedPaneContent: Sendable, Equatable {
    let rawText: String
    let plainText: String
    let lines: [String]
    let osc8Links: [ParsedPaneLink]
    let inlineImages: [ParsedInlineImage]
    let hasANSISequences: Bool
    let hasKittyGraphics: Bool

    static func make(rawText: String) -> ParsedPaneContent {
        let sanitized = ParsedPaneTextSanitizer.sanitize(rawText)
        return ParsedPaneContent(
            rawText: rawText,
            plainText: sanitized.text,
            lines: sanitized.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
            osc8Links: sanitized.links,
            inlineImages: sanitized.inlineImages,
            hasANSISequences: sanitized.hasANSISequences,
            hasKittyGraphics: sanitized.hasKittyGraphics
        )
    }
}

struct ParsedPaneLink: Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let url: URL
}

struct ParsedInlineImage: Identifiable, Sendable, Equatable {
    let id: String
    let data: Data
    let format: String?
}

struct ParsedPaneRenderSnapshot: Sendable, Equatable {
    let rendererID: String
    let title: String
    let confidence: Double
    let generatedAt: Date
    let sourceLineCount: Int
    let payload: ParsedPanePayload
}

enum ParsedPanePayload: Sendable, Equatable {
    case agent(ParsedAgentTranscript)
    case diff(ParsedDiffSnapshot)
    case tests(ParsedTestSnapshot)
    case json(ParsedJSONSnapshot)
    case logs(ParsedLogSnapshot)
    case fileList(ParsedFileListSnapshot)
    case table(ParsedTableSnapshot)
    case reader(ParsedReaderSnapshot)
}

struct ParsedAgentTranscript: Sendable, Equatable {
    let messages: [ChatMessage]
}

struct ParsedDiffSnapshot: Sendable, Equatable {
    let files: [ParsedDiffFile]
}

struct ParsedDiffFile: Identifiable, Sendable, Equatable {
    let id: String
    let path: String
    let additions: Int
    let deletions: Int
    let hunks: [ParsedDiffHunk]
}

struct ParsedDiffHunk: Identifiable, Sendable, Equatable {
    let id: String
    let header: String
    let lines: [ParsedDiffLine]
}

struct ParsedDiffLine: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case context
        case addition
        case deletion
        case metadata
    }

    let id: String
    let kind: Kind
    let text: String
}

struct ParsedTestSnapshot: Sendable, Equatable {
    let passedCount: Int?
    let failedCount: Int?
    let skippedCount: Int?
    let failures: [ParsedTestFailure]
    let rawSummary: String
}

struct ParsedTestFailure: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let message: String
}

struct ParsedJSONSnapshot: Sendable, Equatable {
    let roots: [ParsedJSONNode]
    let isJSONLines: Bool
}

struct ParsedJSONNode: Identifiable, Sendable, Equatable {
    let id: String
    let key: String
    let summary: String
    let children: [ParsedJSONNode]
}

struct ParsedLogSnapshot: Sendable, Equatable {
    let entries: [ParsedLogEntry]
}

struct ParsedLogEntry: Identifiable, Sendable, Equatable {
    let id: String
    let level: ParsedLogLevel
    let timestamp: String?
    let message: String
}

enum ParsedLogLevel: String, CaseIterable, Identifiable, Sendable, Equatable {
    case trace
    case debug
    case info
    case notice
    case warning
    case error
    case fault

    var id: String { rawValue }
}

struct ParsedFileListSnapshot: Sendable, Equatable {
    let entries: [ParsedFileEntry]
}

struct ParsedFileEntry: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case file
        case directory
        case symlink
        case unknown
    }

    let id: String
    let name: String
    let path: String
    let kind: Kind
    let size: String?
    let permissions: String?
    let modified: String?
    let depth: Int
}

struct ParsedTableSnapshot: Sendable, Equatable {
    let columns: [String]
    let rows: [[String]]
}

struct ParsedReaderSnapshot: Sendable, Equatable {
    let markdownText: String
    let links: [ParsedPaneLink]
    let inlineImages: [ParsedInlineImage]
}
