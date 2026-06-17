import CmuxSettings
import Foundation

enum AIPaneStatus: String, Codable, Equatable, Sendable {
    case working
    case needsAttention = "needs_attention"
    case done
    case errored
}

struct MLXHubClientConfiguration: Equatable, Sendable {
    let baseURL: URL
}

enum MLXHubSettings {
    static let modelID = "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit"

    static func configuration(defaults: UserDefaults = .standard) -> MLXHubClientConfiguration? {
        let catalog = SettingCatalog().ai
        let settings = UserDefaultsSettingsClient(defaults: defaults)
        guard settings.value(for: catalog.enabled) else { return nil }
        let rawEndpoint = settings.value(for: catalog.endpoint).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: rawEndpoint),
              let scheme = baseURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              baseURL.host != nil else { return nil }
        return MLXHubClientConfiguration(baseURL: baseURL)
    }
}

actor MLXHubClient {
    private static let requestQueue = MLXHubRequestQueue()
    private static let endpointState = MLXHubEndpointState()
    private static let timeout: TimeInterval = 10
    private static let endpointFailureCooldown: TimeInterval = 30

    func summarize(text: String) async -> String? {
        let input = Self.clippedTerminalText(text)
        guard !input.isEmpty else { return nil }
        return await Self.requestQueue.run {
            await self.performSummarize(text: input)
        }
    }

    func classify(text: String) async -> AIPaneStatus? {
        let input = Self.clippedTerminalText(text)
        guard !input.isEmpty else { return nil }
        return await Self.requestQueue.run {
            await self.performClassify(text: input)
        }
    }

    private func performSummarize(text: String) async -> String? {
        let systemPrompt = """
        Summarize terminal output into a sidebar status. Return only a status of six words or fewer. Prefer concrete state like tests passed, build failed, waiting for input, deploying, or percent progress. No quotes or explanations.
        """
        guard let raw = await chat(systemPrompt: systemPrompt, userText: text, maxTokens: 32) else { return nil }
        return Self.cleanedSummary(raw)
    }

    private func performClassify(text: String) async -> AIPaneStatus? {
        let systemPrompt = """
        Classify recent terminal output. Return exactly one token: working, needs_attention, done, or errored. Use needs_attention when the pane asks for input, approval, login, or a decision. Use errored for failures, exceptions, missing imports, failed builds, or failed tests. Use done for completed work or all tests passing. Use working for active progress.
        """
        guard let raw = await chat(systemPrompt: systemPrompt, userText: text, maxTokens: 8) else { return nil }
        return Self.parseStatus(raw)
    }

    private func chat(systemPrompt: String, userText: String, maxTokens: Int) async -> String? {
        guard let configuration = MLXHubSettings.configuration() else { return nil }
        let now = Date()
        guard await !Self.endpointState.isUnavailable(now: now) else { return nil }

        var request = URLRequest(url: Self.chatCompletionsURL(baseURL: configuration.baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ChatCompletionRequest(
            model: MLXHubSettings.modelID,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userText),
            ],
            temperature: 0,
            maxTokens: maxTokens,
            stream: false
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return nil }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                await Self.endpointState.markFailure(now: now, cooldown: Self.endpointFailureCooldown)
                return nil
            }
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            await Self.endpointState.clearFailure()
            return decoded.choices.first?.message.content
        } catch {
            guard !Self.isCancellation(error) else { return nil }
            await Self.endpointState.markFailure(now: now, cooldown: Self.endpointFailureCooldown)
            return nil
        }
    }

    private static func chatCompletionsURL(baseURL: URL) -> URL {
        baseURL.appendingPathComponent("chat/completions")
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

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private actor MLXHubRequestQueue {
    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run<T: Sendable>(_ operation: @escaping @Sendable () async -> T?) async -> T? {
        await waitForTurn()
        defer { finishTurn() }
        guard !Task.isCancelled else { return nil }
        return await operation()
    }

    private func waitForTurn() async {
        if !isRunning {
            isRunning = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func finishTurn() {
        guard !waiters.isEmpty else {
            isRunning = false
            return
        }
        let continuation = waiters.removeFirst()
        continuation.resume()
    }
}

private actor MLXHubEndpointState {
    private var unavailableUntil: Date?

    func isUnavailable(now: Date) -> Bool {
        guard let unavailableUntil else { return false }
        if now < unavailableUntil { return true }
        self.unavailableUntil = nil
        return false
    }

    func markFailure(now: Date, cooldown: TimeInterval) {
        unavailableUntil = now.addingTimeInterval(cooldown)
    }

    func clearFailure() {
        unavailableUntil = nil
    }
}

private struct ChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable, Sendable {
    let choices: [Choice]

    struct Choice: Decodable, Sendable {
        let message: ChatMessage
    }
}
