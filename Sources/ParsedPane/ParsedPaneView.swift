import AppKit
import CmuxAgentChat
import SwiftUI

struct ParsedPaneView: View {
    @ObservedObject var viewModel: ParsedPaneViewModel
    let actions: ParsedPaneActions

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .opacity(0.92)
            if let snapshot = viewModel.snapshot {
                ParsedPaneSnapshotView(snapshot: snapshot, actions: actions)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "parsedView.loading", defaultValue: "Parsing terminal output..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ParsedPaneSnapshotView: View {
    let snapshot: ParsedPaneRenderSnapshot
    let actions: ParsedPaneActions

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ParsedPaneHeader(snapshot: snapshot)
                switch snapshot.payload {
                case .agent(let transcript):
                    ForEach(transcript.messages) { message in
                        ParsedAgentMessageCard(message: message, actions: actions)
                    }
                case .diff(let diff):
                    ForEach(diff.files) { file in
                        ParsedDiffFileCard(file: file)
                    }
                case .tests(let tests):
                    ParsedTestOutputView(snapshot: tests)
                case .json(let json):
                    ParsedJSONTreeView(snapshot: json)
                case .logs(let logs):
                    ParsedLogListView(snapshot: logs)
                case .fileList(let files):
                    ParsedFileListView(snapshot: files)
                case .table(let table):
                    ParsedTableView(snapshot: table)
                case .reader(let reader):
                    ParsedReaderView(snapshot: reader)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 34)
            .padding(.bottom, 16)
        }
    }
}

private struct ParsedPaneHeader: View {
    let snapshot: ParsedPaneRenderSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Text(localizedTitle)
                .font(.headline)
            Text(String.localizedStringWithFormat(
                String(localized: "parsedView.header.lines", defaultValue: "%d lines"),
                snapshot.sourceLineCount
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var localizedTitle: String {
        switch snapshot.rendererID {
        case "agent": String(localized: "parsedView.renderer.agent", defaultValue: "Agent")
        case "diff": String(localized: "parsedView.renderer.diff", defaultValue: "Diff")
        case "tests": String(localized: "parsedView.renderer.tests", defaultValue: "Tests")
        case "json": String(localized: "parsedView.renderer.json", defaultValue: "JSON")
        case "logs": String(localized: "parsedView.renderer.logs", defaultValue: "Logs")
        case "files": String(localized: "parsedView.renderer.files", defaultValue: "Files")
        case "table": String(localized: "parsedView.renderer.table", defaultValue: "Table")
        default: String(localized: "parsedView.renderer.reader", defaultValue: "Reader")
        }
    }
}

private struct ParsedAgentMessageCard: View {
    let message: ChatMessage
    let actions: ParsedPaneActions

    var body: some View {
        switch message.kind {
        case .prose(let prose):
            ParsedCard {
                ParsedMarkdownText(text: prose.text)
                    .font(.body)
            }
        case .thought(let thought):
            ParsedThoughtCard(thought: thought)
        case .terminal(let capture):
            ParsedTerminalToolCard(capture: capture)
        case .fileEdit(let edit):
            ParsedFileEditCard(edit: edit)
        case .question(let question):
            ParsedQuestionCard(question: question, actions: actions)
        case .permissionRequest(let request):
            ParsedPermissionCard(request: request, actions: actions)
        case .toolUse(let tool):
            ParsedGenericToolCard(tool: tool)
        case .status(let status):
            Text(statusLabel(status))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        case .attachment(let attachment):
            ParsedCard {
                Label(attachment.displayName ?? String(localized: "parsedView.agent.attachment", defaultValue: "Attachment"), systemImage: "paperclip")
            }
        case .unsupported(let payload):
            ParsedCard {
                Text(payload.rawType)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusLabel(_ status: ChatStatusTransition) -> String {
        let base: String
        switch status.event {
        case .sessionStarted:
            base = String(localized: "parsedView.agent.status.sessionStarted", defaultValue: "Session started")
        case .sessionEnded:
            base = String(localized: "parsedView.agent.status.sessionEnded", defaultValue: "Session ended")
        case .interrupted:
            base = String(localized: "parsedView.agent.status.interrupted", defaultValue: "Interrupted")
        case .contextCompacted:
            base = String(localized: "parsedView.agent.status.contextCompacted", defaultValue: "Context compacted")
        }
        guard let detail = status.detail, !detail.isEmpty else { return base }
        return "\(base) \(detail)"
    }
}

private struct ParsedThoughtCard: View {
    let thought: ChatThought
    @State private var isExpanded = false

    var body: some View {
        ParsedCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                ParsedMarkdownText(text: thought.text)
                    .padding(.top, 6)
            } label: {
                Label(String(localized: "parsedView.agent.thinking", defaultValue: "Reasoning"), systemImage: "brain")
                    .font(.subheadline.weight(.medium))
            }
        }
    }
}

private struct ParsedTerminalToolCard: View {
    let capture: ChatTerminalCapture
    @State private var isExpanded = true

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(String(localized: "parsedView.agent.bash", defaultValue: "Bash"), systemImage: "terminal")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let exitCode = capture.exitCode {
                        Text(String.localizedStringWithFormat(
                            String(localized: "parsedView.agent.exitCode", defaultValue: "exit %d"),
                            exitCode
                        ))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(exitCode == 0 ? .green : .red)
                    } else if capture.isRunning {
                        Text(String(localized: "parsedView.agent.running", defaultValue: "running"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(capture.command)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                if let output = capture.output, !output.isEmpty {
                    DisclosureGroup(isExpanded: $isExpanded) {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } label: {
                        Text(String(localized: "parsedView.agent.output", defaultValue: "Output"))
                            .font(.caption.weight(.medium))
                    }
                }
            }
        }
    }
}

private struct ParsedFileEditCard: View {
    let edit: ChatFileEdit

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(edit.filePath, systemImage: "doc.text")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    ParsedChangeCount(additions: edit.additions, deletions: edit.deletions)
                }
                if let diff = edit.unifiedDiff, !diff.isEmpty {
                    ParsedUnifiedDiffBlock(diff: diff)
                } else {
                    Text(operationTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var operationTitle: String {
        switch edit.operation {
        case .edit: String(localized: "parsedView.agent.fileEdit.edit", defaultValue: "Edited")
        case .write: String(localized: "parsedView.agent.fileEdit.write", defaultValue: "Wrote")
        case .delete: String(localized: "parsedView.agent.fileEdit.delete", defaultValue: "Deleted")
        }
    }
}

private struct ParsedQuestionCard: View {
    let question: ChatQuestion
    let actions: ParsedPaneActions
    @State private var reply = ""

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "parsedView.agent.question", defaultValue: "Question"), systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                ParsedMarkdownText(text: question.prompt)
                if !question.options.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            Button {
                                actions.sendReturnTerminatedInput(option.label)
                            } label: {
                                Text(option.label)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(option.detail ?? option.label)
                            .accessibilityIdentifier("ParsedQuestionOption\(index)")
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField(String(localized: "parsedView.agent.replyPlaceholder", defaultValue: "Reply"), text: $reply)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        actions.sendReturnTerminatedInput(trimmed)
                        reply = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help(String(localized: "parsedView.agent.sendReply", defaultValue: "Send Reply"))
                }
            }
        }
    }
}

private struct ParsedPermissionCard: View {
    let request: ChatPermissionRequest
    let actions: ParsedPaneActions

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(request.title, systemImage: "lock.shield")
                    .font(.subheadline.weight(.semibold))
                Text(request.subject)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                if let resolution = request.resolution {
                    Text(resolutionTitle(resolution))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Button {
                            actions.sendReturnTerminatedInput("y")
                        } label: {
                            Label(String(localized: "parsedView.agent.approve", defaultValue: "Approve"), systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        Button {
                            actions.sendReturnTerminatedInput("n")
                        } label: {
                            Label(String(localized: "parsedView.agent.deny", defaultValue: "Deny"), systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func resolutionTitle(_ resolution: ChatPermissionRequest.Resolution) -> String {
        switch resolution {
        case .approved:
            String(localized: "parsedView.agent.permission.approved", defaultValue: "Approved")
        case .denied:
            String(localized: "parsedView.agent.permission.denied", defaultValue: "Denied")
        case .expired:
            String(localized: "parsedView.agent.permission.expired", defaultValue: "Expired")
        }
    }
}

private struct ParsedGenericToolCard: View {
    let tool: ChatToolUse
    @State private var isExpanded = false

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(toolTitle, systemImage: iconName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
                Text(tool.summary)
                    .font(.callout)
                    .textSelection(.enabled)
                if tool.toolName == "TodoWrite" {
                    ParsedTodoChecklist(inputDetail: tool.inputDetail)
                } else if isSearchLikeTool {
                    ParsedToolResultList(output: tool.output)
                } else if isNestedAgentTool {
                    ParsedNestedAgentBlock(input: tool.inputDetail, output: tool.output)
                } else if isWebTool {
                    ParsedWebToolBlock(input: tool.inputDetail, output: tool.output)
                }
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let input = tool.inputDetail {
                            ParsedCodeBlock(title: String(localized: "parsedView.agent.input", defaultValue: "Input"), text: input)
                        }
                        if let output = tool.output {
                            ParsedCodeBlock(title: String(localized: "parsedView.agent.output", defaultValue: "Output"), text: output)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text(String(localized: "parsedView.agent.details", defaultValue: "Details"))
                        .font(.caption.weight(.medium))
                }
            }
        }
    }

    private var toolTitle: String {
        String.localizedStringWithFormat(String(localized: "parsedView.agent.toolCall", defaultValue: "%@ tool call"), tool.toolName)
    }

    private var iconName: String {
        switch tool.toolName {
        case "Read": "doc.text.magnifyingglass"
        case "Grep", "Glob", "LS": "list.bullet"
        case "WebFetch", "WebSearch": "network"
        case "Task", "Agent": "person.2"
        case "TodoWrite": "checklist"
        default: "wrench.and.screwdriver"
        }
    }

    private var statusTitle: String {
        switch tool.status {
        case .running: String(localized: "parsedView.agent.running", defaultValue: "running")
        case .succeeded: String(localized: "parsedView.agent.succeeded", defaultValue: "succeeded")
        case .failed: String(localized: "parsedView.agent.failed", defaultValue: "failed")
        }
    }

    private var statusColor: Color {
        switch tool.status {
        case .running: .secondary
        case .succeeded: .green
        case .failed: .red
        }
    }

    private var isSearchLikeTool: Bool {
        ["Read", "Grep", "Glob", "LS"].contains(tool.toolName)
    }

    private var isNestedAgentTool: Bool {
        ["Task", "Agent"].contains(tool.toolName)
    }

    private var isWebTool: Bool {
        ["WebFetch", "WebSearch"].contains(tool.toolName)
    }
}

private struct ParsedTodoChecklist: View {
    let inputDetail: String?

    var body: some View {
        let todos = parsedTodos
        if !todos.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                    HStack(spacing: 6) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : todo.isInProgress ? "circle.dotted" : "circle")
                            .foregroundStyle(todo.isDone ? .green : .secondary)
                        Text(todo.title)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var parsedTodos: [TodoRow] {
        guard let inputDetail,
              let data = inputDetail.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let todos = object["todos"] as? [[String: Any]] else {
            return []
        }
        return todos.compactMap { item in
            guard let content = item["content"] as? String else { return nil }
            let status = item["status"] as? String
            return TodoRow(
                title: content,
                isDone: status == "completed" || status == "done",
                isInProgress: status == "in_progress" || status == "in-progress"
            )
        }
    }

    private struct TodoRow {
        let title: String
        let isDone: Bool
        let isInProgress: Bool
    }
}

private struct ParsedToolResultList: View {
    let output: String?

    var body: some View {
        if let output, !output.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(output.split(separator: "\n").prefix(12).enumerated()), id: \.offset) { _, line in
                    Text(String(line))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

private struct ParsedNestedAgentBlock: View {
    let input: String?
    let output: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let input {
                ParsedCodeBlock(title: String(localized: "parsedView.agent.subagentPrompt", defaultValue: "Subagent prompt"), text: input)
            }
            if let output {
                ParsedCodeBlock(title: String(localized: "parsedView.agent.subagentResult", defaultValue: "Subagent result"), text: output)
            }
        }
    }
}

private struct ParsedWebToolBlock: View {
    let input: String?
    let output: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let input {
                ParsedCodeBlock(title: String(localized: "parsedView.agent.webRequest", defaultValue: "Request"), text: input)
            }
            if let output {
                ParsedMarkdownText(text: output)
                    .font(.caption)
            }
        }
    }
}

private struct ParsedDiffFileCard: View {
    let file: ParsedDiffFile
    @State private var isExpanded = true

    var body: some View {
        ParsedCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(file.hunks) { hunk in
                        ParsedDiffHunkView(hunk: hunk)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Label(file.path, systemImage: "doc.text")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    ParsedChangeCount(additions: file.additions, deletions: file.deletions)
                }
            }
        }
    }
}

private struct ParsedDiffHunkView: View {
    let hunk: ParsedDiffHunk

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hunk.header)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            ForEach(hunk.lines) { line in
                Text(line.text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(foreground(for: line.kind))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 6)
                    .background(background(for: line.kind), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
    }

    private func foreground(for kind: ParsedDiffLine.Kind) -> Color {
        switch kind {
        case .addition: .green
        case .deletion: .red
        case .metadata: .secondary
        case .context: .primary
        }
    }

    private func background(for kind: ParsedDiffLine.Kind) -> Color {
        switch kind {
        case .addition: Color.green.opacity(0.10)
        case .deletion: Color.red.opacity(0.10)
        default: Color.clear
        }
    }
}

private struct ParsedUnifiedDiffBlock: View {
    let diff: String

    var body: some View {
        let lines = diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(line.hasPrefix("+") ? .green : line.hasPrefix("-") ? .red : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ParsedChangeCount: View {
    let additions: Int?
    let deletions: Int?

    var body: some View {
        HStack(spacing: 6) {
            if let additions {
                Text("+\(additions)")
                    .foregroundStyle(.green)
            }
            if let deletions {
                Text("-\(deletions)")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption.monospacedDigit())
    }
}

private struct ParsedTestOutputView: View {
    let snapshot: ParsedTestSnapshot

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    CountPill(title: String(localized: "parsedView.tests.passed", defaultValue: "Passed"), count: snapshot.passedCount, color: .green)
                    CountPill(title: String(localized: "parsedView.tests.failed", defaultValue: "Failed"), count: snapshot.failedCount, color: .red)
                    CountPill(title: String(localized: "parsedView.tests.skipped", defaultValue: "Skipped"), count: snapshot.skippedCount, color: .secondary)
                }
                if !snapshot.rawSummary.isEmpty {
                    Text(snapshot.rawSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(snapshot.failures) { failure in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(failure.name)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.red)
                        if !failure.message.isEmpty {
                            Text(failure.message)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    private struct CountPill: View {
        let title: String
        let count: Int?
        let color: Color

        var body: some View {
            HStack(spacing: 4) {
                Text("\(count ?? 0)")
                    .font(.caption.monospacedDigit().weight(.bold))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(color)
        }
    }
}

private struct ParsedJSONTreeView: View {
    let snapshot: ParsedJSONSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(snapshot.roots) { node in
                ParsedJSONNodeView(node: node, depth: 0)
            }
        }
    }
}

private struct ParsedJSONNodeView: View {
    let node: ParsedJSONNode
    let depth: Int
    @State private var isExpanded = true

    var body: some View {
        if node.children.isEmpty {
            HStack(spacing: 6) {
                Text(node.key)
                    .foregroundStyle(.secondary)
                Text(node.summary)
            }
            .font(.system(.caption, design: .monospaced))
            .padding(.leading, CGFloat(depth * 14))
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(node.children) { child in
                        ParsedJSONNodeView(node: child, depth: depth + 1)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(node.key)
                    Text(node.summary)
                        .foregroundStyle(.secondary)
                }
                .font(.system(.caption, design: .monospaced))
            }
            .padding(.leading, CGFloat(depth * 14))
        }
    }
}

private struct ParsedLogListView: View {
    let snapshot: ParsedLogSnapshot
    @State private var selectedLevel: ParsedLogLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button(String(localized: "parsedView.logs.all", defaultValue: "All")) {
                    selectedLevel = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                ForEach(ParsedLogLevel.allCases) { level in
                    Button(logLevelTitle(level)) {
                        selectedLevel = level
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            ForEach(filteredEntries) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.level.rawValue.uppercased())
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(color(for: entry.level))
                        .frame(width: 54, alignment: .leading)
                    if let timestamp = entry.timestamp {
                        Text(timestamp)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.message)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var filteredEntries: [ParsedLogEntry] {
        guard let selectedLevel else { return snapshot.entries }
        return snapshot.entries.filter { $0.level == selectedLevel }
    }

    private func color(for level: ParsedLogLevel) -> Color {
        switch level {
        case .error, .fault: .red
        case .warning: .orange
        case .notice: .blue
        case .debug, .trace: .secondary
        case .info: .green
        }
    }

    private func logLevelTitle(_ level: ParsedLogLevel) -> String {
        switch level {
        case .trace: String(localized: "parsedView.logs.trace", defaultValue: "Trace")
        case .debug: String(localized: "parsedView.logs.debug", defaultValue: "Debug")
        case .info: String(localized: "parsedView.logs.info", defaultValue: "Info")
        case .notice: String(localized: "parsedView.logs.notice", defaultValue: "Notice")
        case .warning: String(localized: "parsedView.logs.warning", defaultValue: "Warning")
        case .error: String(localized: "parsedView.logs.error", defaultValue: "Error")
        case .fault: String(localized: "parsedView.logs.fault", defaultValue: "Fault")
        }
    }
}

private struct ParsedFileListView: View {
    let snapshot: ParsedFileListSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text(String(localized: "parsedView.files.name", defaultValue: "Name")).font(.caption.weight(.semibold))
                Text(String(localized: "parsedView.files.size", defaultValue: "Size")).font(.caption.weight(.semibold))
                Text(String(localized: "parsedView.files.modified", defaultValue: "Modified")).font(.caption.weight(.semibold))
            }
            ForEach(snapshot.entries) { entry in
                GridRow {
                    HStack(spacing: 6) {
                        Image(systemName: iconName(for: entry.kind))
                            .foregroundStyle(.secondary)
                        Text(entry.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.leading, CGFloat(entry.depth * 14))
                    Text(entry.size ?? "")
                        .foregroundStyle(.secondary)
                    Text(entry.modified ?? "")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private func iconName(for kind: ParsedFileEntry.Kind) -> String {
        switch kind {
        case .directory: "folder"
        case .symlink: "arrow.triangle.branch"
        case .file: "doc"
        case .unknown: "questionmark.square.dashed"
        }
    }
}

private struct ParsedTableView: View {
    let snapshot: ParsedTableSnapshot

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                GridRow {
                    ForEach(Array(snapshot.columns.enumerated()), id: \.offset) { _, column in
                        Text(column)
                            .font(.caption.weight(.semibold))
                    }
                }
                ForEach(Array(snapshot.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }
}

private struct ParsedReaderView: View {
    let snapshot: ParsedReaderSnapshot

    var body: some View {
        ParsedCard {
            VStack(alignment: .leading, spacing: 10) {
                ParsedMarkdownText(text: snapshot.markdownText)
                ForEach(snapshot.links) { link in
                    Link(destination: link.url) {
                        Label(link.label, systemImage: "link")
                            .font(.caption)
                    }
                }
                ForEach(snapshot.inlineImages) { image in
                    ParsedInlineImageView(image: image)
                }
            }
        }
    }
}

private struct ParsedInlineImageView: View {
    let image: ParsedInlineImage

    var body: some View {
        if let nsImage = NSImage(data: image.data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private struct ParsedCodeBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private struct ParsedMarkdownText: View {
    let text: String

    var body: some View {
        Text(rendered)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rendered: AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        var attributed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        Self.linkifyBareURLs(in: &attributed)
        return attributed
    }

    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    private static func linkifyBareURLs(in text: inout AttributedString) {
        let plain = String(text.characters)
        guard let detector = linkDetector, !plain.isEmpty else { return }
        let nsRange = NSRange(plain.startIndex..<plain.endIndex, in: plain)
        for match in detector.matches(in: plain, range: nsRange) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: plain),
                  let attrRange = Range(stringRange, in: text) else { continue }
            if text[attrRange].link == nil {
                text[attrRange].link = url
            }
        }
    }
}

private struct ParsedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
    }
}

struct ParsedPaneChromeToggle: View {
    @Binding var selection: ParsedPaneMode

    var body: some View {
        Picker(String(localized: "parsedView.toggle.accessibility", defaultValue: "Pane view"), selection: $selection) {
            Text(String(localized: "parsedView.toggle.terminal", defaultValue: "Terminal"))
                .tag(ParsedPaneMode.terminal)
            Text(String(localized: "parsedView.toggle.parsed", defaultValue: "Parsed"))
                .tag(ParsedPaneMode.parsed)
        }
        .pickerStyle(.segmented)
        .controlSize(.mini)
        .labelsHidden()
        .frame(width: 148)
        .padding(3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 2)
        .accessibilityIdentifier("ParsedPaneModeToggle")
    }
}
