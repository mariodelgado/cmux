import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

struct ParsedViewDetectorTests {
    @Test func detectsUnifiedDiffs() {
        let text = """
        diff --git a/Sources/App.swift b/Sources/App.swift
        index 1111111..2222222 100644
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -1,2 +1,3 @@
         import SwiftUI
        -let old = true
        +let new = true
        +let parsed = true
        """
        let snapshot = ParsedViewDetector().detect(ParsedPaneContent.make(rawText: text))

        #expect(snapshot.rendererID == "diff")
        guard case .diff(let diff) = snapshot.payload else {
            Issue.record("expected diff payload")
            return
        }
        #expect(diff.files.first?.path == "Sources/App.swift")
        #expect(diff.files.first?.additions == 2)
        #expect(diff.files.first?.deletions == 1)
    }

    @Test func detectsJSONTree() {
        let text = #"{"ok":true,"items":[{"name":"one"},{"name":"two"}]}"#
        let snapshot = ParsedViewDetector().detect(ParsedPaneContent.make(rawText: text))

        #expect(snapshot.rendererID == "json")
        guard case .json(let json) = snapshot.payload else {
            Issue.record("expected json payload")
            return
        }
        #expect(json.roots.count == 1)
        #expect(json.roots[0].children.contains { $0.key == "items" })
    }

    @Test func detectsClaudeTranscriptToolsAndQuestions() {
        let lines = [
            Self.assistantLine(uuid: "a-1", blocks: [
                ["type": "tool_use", "id": "toolu_b", "name": "Bash", "input": ["command": "swift test"]],
                ["type": "tool_use", "id": "toolu_q", "name": "AskUserQuestion", "input": [
                    "questions": [[
                        "question": "Proceed?",
                        "options": [
                            ["label": "Yes", "description": "Continue"],
                            ["label": "No", "description": "Stop"],
                        ],
                    ]],
                ]],
                ["type": "tool_use", "id": "toolu_x", "name": "WebSearch", "input": ["query": "cmux parsed view"]],
            ]),
            Self.toolResultLine(toolUseID: "toolu_b", content: "Test Suite 'All tests' passed"),
            Self.toolResultLine(toolUseID: "toolu_x", content: "Found relevant docs"),
        ]
        let snapshot = ParsedViewDetector().detect(ParsedPaneContent.make(rawText: lines.joined(separator: "\n")))

        #expect(snapshot.rendererID == "agent")
        guard case .agent(let transcript) = snapshot.payload else {
            Issue.record("expected agent payload")
            return
        }
        #expect(transcript.messages.contains {
            if case .terminal(let capture) = $0.kind { return capture.command == "swift test" && capture.output != nil }
            return false
        })
        #expect(transcript.messages.contains {
            if case .question(let question) = $0.kind { return question.prompt == "Proceed?" && question.options.count == 2 }
            return false
        })
        #expect(transcript.messages.contains {
            if case .toolUse(let tool) = $0.kind { return tool.toolName == "WebSearch" && tool.output == "Found relevant docs" }
            return false
        })
    }

    private static func assistantLine(uuid: String, blocks: [[String: Any]]) -> String {
        json([
            "parentUuid": "u-1",
            "isSidechain": false,
            "type": "assistant",
            "message": [
                "model": "claude-fable-5",
                "id": "msg_01X",
                "type": "message",
                "role": "assistant",
                "content": blocks,
                "stop_reason": "tool_use",
            ],
            "uuid": uuid,
            "timestamp": "2026-06-12T05:08:20.730Z",
            "sessionId": "s-1",
        ])
    }

    private static func toolResultLine(toolUseID: String, content: Any) -> String {
        json([
            "parentUuid": "a-1",
            "isSidechain": false,
            "type": "user",
            "message": [
                "role": "user",
                "content": [[
                    "tool_use_id": toolUseID,
                    "type": "tool_result",
                    "content": content,
                ]],
            ],
            "uuid": "r-\(toolUseID)",
            "timestamp": "2026-06-12T05:08:23.317Z",
            "sessionId": "s-1",
        ])
    }

    private static func json(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(decoding: data, as: UTF8.self)
    }
}
