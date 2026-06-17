import Foundation
import FoundationModels

struct FoundationModelsBackend: AIBackend {
    private let maximumResponseTokens: Int?

    init(maximumResponseTokens: Int? = nil) {
        self.maximumResponseTokens = maximumResponseTokens
    }

    func complete(system: String, user: String) async throws -> String {
        if #available(macOS 26.0, *) {
            return try await completeWithSystemLanguageModel(system: system, user: user)
        }
        throw AIBackendError.unavailable
    }

    func completeIfAvailable(system: String, user: String) async -> String? {
        try? await complete(system: system, user: user)
    }

    @available(macOS 26.0, *)
    private func completeWithSystemLanguageModel(system: String, user: String) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIBackendError.unavailable
        }

        let session = LanguageModelSession(model: model, instructions: system)
        let options = GenerationOptions(
            sampling: .greedy,
            temperature: 0,
            maximumResponseTokens: maximumResponseTokens
        )
        let response = try await session.respond(to: user, options: options)
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIBackendError.emptyResponse
        }
        return trimmed
    }
}
