import Foundation

nonisolated struct OpenRouterInspectorProfile: Codable, Equatable, Identifiable, Sendable {
    static let characterProfileID = "claude-character"
    static let defaultNormalProfileID = "claude-openrouter"

    let id: String
    let label: String

    var isCharacterProfile: Bool {
        id == Self.characterProfileID
    }

    init(id: String, label: String? = nil) {
        self.id = id
        self.label = label?.nilIfBlank ?? id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = container.decodeLossyStringIfPresent(forKey: .id) ?? ""
        let label = container.decodeLossyStringIfPresent(forKey: .label)
        self.init(id: id, label: label)
    }
}

nonisolated struct OpenRouterInspectorSession: Codable, Equatable, Identifiable, Sendable {
    static let characterRuntimeProfile = "character"

    let session: String
    let window: Int?
    let profile: String?
    let model: String?
    let pid: Int?
    let running: Bool

    var id: String {
        "\(session):\(window.map(String.init) ?? "none"):\(pid.map(String.init) ?? "none")"
    }

    var displayName: String {
        if let window {
            return "\(session):\(window)"
        }
        return session
    }

    var tmuxIdentityKey: String {
        "\(session):\(window.map(String.init) ?? "none")"
    }

    var isCharacterProfile: Bool {
        profile == Self.characterRuntimeProfile
    }

    init(
        session: String,
        window: Int?,
        profile: String?,
        model: String?,
        pid: Int?,
        running: Bool
    ) {
        self.session = session.nilIfBlank ?? String(localized: "openRouterInspector.unknown", defaultValue: "Unknown")
        self.window = window
        self.profile = profile?.nilIfBlank
        self.model = model?.nilIfBlank
        self.pid = pid
        self.running = running
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            session: container.decodeLossyStringIfPresent(forKey: .session) ?? "",
            window: container.decodeLossyIntIfPresent(forKey: .window),
            profile: container.decodeLossyStringIfPresent(forKey: .profile),
            model: container.decodeLossyStringIfPresent(forKey: .model),
            pid: container.decodeLossyIntIfPresent(forKey: .pid),
            running: container.decodeLossyBoolIfPresent(forKey: .running) ?? false
        )
    }
}

nonisolated struct OpenRouterInspectorGeneration: Codable, Equatable, Identifiable, Sendable {
    let model: String
    let cost: Double?
    let tokens: Int?
    let timestamp: Date?

    var id: String {
        [
            model,
            cost.map { String(format: "%.8f", $0) } ?? "no-cost",
            tokens.map(String.init) ?? "no-tokens",
            timestamp.map { String(format: "%.3f", $0.timeIntervalSince1970) } ?? "no-ts",
        ].joined(separator: "|")
    }

    init(model: String, cost: Double?, tokens: Int?, timestamp: Date?) {
        self.model = model.nilIfBlank ?? String(localized: "openRouterInspector.unknown", defaultValue: "Unknown")
        self.cost = cost
        self.tokens = tokens
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case model
        case cost
        case tokens
        case timestamp
        case ts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            model: container.decodeLossyStringIfPresent(forKey: .model) ?? "",
            cost: container.decodeLossyDoubleIfPresent(forKey: .cost),
            tokens: container.decodeLossyIntIfPresent(forKey: .tokens),
            timestamp: Self.decodeTimestamp(from: container)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(cost, forKey: .cost)
        try container.encodeIfPresent(tokens, forKey: .tokens)
        try container.encodeIfPresent(timestamp?.timeIntervalSince1970, forKey: .ts)
    }

    private static func decodeTimestamp(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            return date
        }
        let raw = container.decodeLossyDoubleIfPresent(forKey: .ts)
            ?? container.decodeLossyDoubleIfPresent(forKey: .timestamp)
        guard var seconds = raw else { return nil }
        if seconds > 1_000_000_000_000 {
            seconds /= 1_000
        }
        return Date(timeIntervalSince1970: seconds)
    }
}

nonisolated struct OpenRouterInspectorUsage: Codable, Equatable, Sendable {
    let balance: Double?
    let usage: Double?
    let limit: Double?
    let recent: [OpenRouterInspectorGeneration]

    init(
        balance: Double? = nil,
        usage: Double? = nil,
        limit: Double? = nil,
        recent: [OpenRouterInspectorGeneration] = []
    ) {
        self.balance = balance
        self.usage = usage
        self.limit = limit
        self.recent = recent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            balance: container.decodeLossyDoubleIfPresent(forKey: .balance),
            usage: container.decodeLossyDoubleIfPresent(forKey: .usage),
            limit: container.decodeLossyDoubleIfPresent(forKey: .limit),
            recent: (try? container.decode([OpenRouterInspectorGeneration].self, forKey: .recent)) ?? []
        )
    }
}

nonisolated struct OpenRouterInspectorCharacterStatus: Codable, Equatable, Sendable {
    let facadeUp: Bool
    let port: Int?
    let mode: String?

    static let offline = OpenRouterInspectorCharacterStatus(
        facadeUp: false,
        port: nil,
        mode: nil
    )

    init(
        facadeUp: Bool = false,
        port: Int? = nil,
        mode: String? = nil
    ) {
        self.facadeUp = facadeUp
        self.port = port
        self.mode = mode?.nilIfBlank
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            facadeUp: container.decodeLossyBoolIfPresent(forKey: .facadeUp) ?? false,
            port: container.decodeLossyIntIfPresent(forKey: .port),
            mode: container.decodeLossyStringIfPresent(forKey: .mode)
        )
    }
}

nonisolated struct OpenRouterInspectorSnapshot: Codable, Equatable, Sendable {
    let sessions: [OpenRouterInspectorSession]
    let openrouter: OpenRouterInspectorUsage
    let profiles: [OpenRouterInspectorProfile]
    let models: [String]
    let character: OpenRouterInspectorCharacterStatus
    let receivedAt: Date

    static let empty = OpenRouterInspectorSnapshot(
        sessions: [],
        openrouter: OpenRouterInspectorUsage(),
        profiles: [],
        models: [],
        character: .offline,
        receivedAt: .distantPast
    )

    init(
        sessions: [OpenRouterInspectorSession],
        openrouter: OpenRouterInspectorUsage,
        profiles: [OpenRouterInspectorProfile],
        models: [String],
        character: OpenRouterInspectorCharacterStatus = .offline,
        receivedAt: Date
    ) {
        self.sessions = sessions
        self.openrouter = openrouter
        self.profiles = profiles
        self.models = models.compactMap(\.nilIfBlank)
        self.character = character
        self.receivedAt = receivedAt
    }

    enum CodingKeys: String, CodingKey {
        case sessions
        case openrouter
        case profiles
        case models
        case character
        case receivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sessions: (try? container.decode([OpenRouterInspectorSession].self, forKey: .sessions)) ?? [],
            openrouter: (try? container.decode(OpenRouterInspectorUsage.self, forKey: .openrouter)) ?? OpenRouterInspectorUsage(),
            profiles: (try? container.decode([OpenRouterInspectorProfile].self, forKey: .profiles)) ?? [],
            models: (try? container.decode([String].self, forKey: .models)) ?? [],
            character: (try? container.decode(OpenRouterInspectorCharacterStatus.self, forKey: .character)) ?? .offline,
            receivedAt: (try? container.decode(Date.self, forKey: .receivedAt)) ?? Date()
        )
    }

    static func decode(stdout: String, receivedAt: Date = Date()) throws -> OpenRouterInspectorSnapshot {
        let data = Data(stdout.utf8)
        let decoded = try JSONDecoder().decode(OpenRouterInspectorSnapshot.self, from: data)
        return OpenRouterInspectorSnapshot(
            sessions: decoded.sessions,
            openrouter: decoded.openrouter,
            profiles: decoded.profiles,
            models: decoded.models,
            character: decoded.character,
            receivedAt: receivedAt
        )
    }
}

nonisolated struct OpenRouterInspectorCommandOutcome: Equatable, Sendable {
    let exitStatus: Int32?
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let executionError: String?

    var isSuccess: Bool {
        executionError == nil && !timedOut && exitStatus == 0
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    func decodeLossyDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    func decodeLossyBoolIfPresent(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                return nil
            }
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        return nil
    }
}
