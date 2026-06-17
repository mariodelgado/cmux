import Foundation
import FoundationModels

struct FoundationModelsBackend {
    private let maximumResponseTokens: Int?

    init(maximumResponseTokens: Int? = nil) {
        self.maximumResponseTokens = maximumResponseTokens
    }

    func complete(system: String, user: String) async -> String? {
        if #available(macOS 26.0, *) {
            return try? await completeWithSystemLanguageModel(system: system, user: user)
        }
        return nil
    }

    @available(macOS 26.0, *)
    private func completeWithSystemLanguageModel(system: String, user: String) async throws -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let session = LanguageModelSession(model: model, instructions: system)
        let options = GenerationOptions(
            sampling: .greedy,
            temperature: 0,
            maximumResponseTokens: maximumResponseTokens
        )
        let response = try await session.respond(to: user, options: options)
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
