struct MLXHubBackend: AIBackend {
    private let client: MLXHubClient
    private let maxTokens: Int

    init(client: MLXHubClient = MLXHubClient(), maxTokens: Int) {
        self.client = client
        self.maxTokens = maxTokens
    }

    func complete(system: String, user: String) async throws -> String {
        guard let output = await client.complete(system: system, user: user, maxTokens: maxTokens) else {
            throw AIBackendError.unavailable
        }
        return output
    }
}
