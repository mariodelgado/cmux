import Foundation

actor AIRouter {
    static let shared = AIRouter()

    private enum BackendTier {
        case foundationModels
        case mlxHub
    }

    private static let queue = AIRequestQueue()

    func complete(task: AITaskKind, system: String, user: String) async -> String? {
        guard AIFeatureSettings.isEnabled() else { return nil }
        let trimmedUser = Self.clippedTerminalText(user)
        guard !trimmedUser.isEmpty else { return nil }

        return await Self.queue.run { [task, system, trimmedUser] in
            await self.completeWithoutQueue(task: task, system: system, user: trimmedUser)
        }
    }

    func summarizeTerminalOutput(text: String) async -> String? {
        let systemPrompt = """
        Summarize terminal output into a sidebar status. Return only a status of six words or fewer. Prefer concrete state like tests passed, build failed, waiting for input, deploying, or percent progress. No quotes or explanations.
        """
        guard let raw = await complete(
            task: .light(maximumResponseTokens: 32),
            system: systemPrompt,
            user: text
        ) else { return nil }
        return Self.cleanedSummary(raw)
    }

    func classifyTerminalOutput(text: String) async -> AIPaneStatus? {
        let systemPrompt = """
        Classify recent terminal output. Return exactly one token: working, needs_attention, done, or errored. Use needs_attention when the pane asks for input, approval, login, or a decision. Use errored for failures, exceptions, missing imports, failed builds, or failed tests. Use done for completed work or all tests passing. Use working for active progress.
        """
        guard let raw = await complete(
            task: .light(maximumResponseTokens: 8),
            system: systemPrompt,
            user: text
        ) else { return nil }
        return Self.parseStatus(raw)
    }

    func explain(command: String) async -> String? {
        let systemPrompt = """
        Explain the shell command clearly and concisely for a developer. Call out destructive behavior, filesystem writes, networking, credentials, and process effects when relevant.
        """
        return await complete(
            task: .light(maximumResponseTokens: 240),
            system: systemPrompt,
            user: command
        )
    }

    private func completeWithoutQueue(task: AITaskKind, system: String, user: String) async -> String? {
        for tier in backendOrder(for: task) {
            guard !Task.isCancelled else { return nil }
            do {
                let output = try await backend(for: tier, maxTokens: task.maximumResponseTokens)
                    .complete(system: system, user: user)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !output.isEmpty {
                    return output
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func backendOrder(for task: AITaskKind) -> [BackendTier] {
        task.prefersFoundationModels ? [.foundationModels, .mlxHub] : [.mlxHub, .foundationModels]
    }

    private func backend(for tier: BackendTier, maxTokens: Int) -> any AIBackend {
        switch tier {
        case .foundationModels:
            return FoundationModelsBackend(maximumResponseTokens: maxTokens)
        case .mlxHub:
            return MLXHubBackend(maxTokens: maxTokens)
        }
    }

    private static func clippedTerminalText(_ text: String, maxCharacters: Int = 4_000) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return trimmed }
        return String(trimmed.suffix(maxCharacters))
    }

    private static func cleanedSummary(_ raw: String) -> String? {
        guard var line = raw
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        guard !line.isEmpty else { return nil }
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count > 6 {
            line = words.prefix(6).joined(separator: " ")
        }
        if line.count > 80 {
            line = String(line.prefix(80))
        }
        return line.isEmpty ? nil : line
    }

    private static func parseStatus(_ raw: String) -> AIPaneStatus? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        if normalized.contains(AIPaneStatus.errored.rawValue) { return .errored }
        if normalized.contains(AIPaneStatus.needsAttention.rawValue) { return .needsAttention }
        if normalized.contains(AIPaneStatus.done.rawValue) { return .done }
        if normalized.contains(AIPaneStatus.working.rawValue) { return .working }
        return nil
    }
}
