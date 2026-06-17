protocol AIBackend: Sendable {
    func complete(system: String, user: String) async throws -> String
}
