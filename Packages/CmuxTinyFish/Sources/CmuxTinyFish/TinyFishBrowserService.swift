import Foundation

/// Default TinyFish remote browser service.
public actor TinyFishBrowserService: TinyFishBrowserServiceProtocol {
    private let apiClient: any TinyFishBrowserAPIClient
    private let makeCDPClient: @Sendable () -> any TinyFishCDPClientProtocol
    private var session: TinyFishBrowserSessionDescriptor?
    private var cdpClient: (any TinyFishCDPClientProtocol)?
    private var latestUsage: TinyFishUsageSnapshot?

    /// Creates a TinyFish browser service.
    ///
    /// - Parameters:
    ///   - apiClient: REST client used for session creation and usage.
    ///   - makeCDPClient: Factory for a fresh CDP client per session.
    public init(
        apiClient: any TinyFishBrowserAPIClient = URLSessionTinyFishBrowserAPIClient(),
        makeCDPClient: @escaping @Sendable () -> any TinyFishCDPClientProtocol = { URLSessionTinyFishCDPClient() }
    ) {
        self.apiClient = apiClient
        self.makeCDPClient = makeCDPClient
    }

    public func createSession(
        apiKey: String,
        startURL: String?,
        timeoutSeconds: Int
    ) async throws -> TinyFishBrowserSnapshot {
        let key = try Self.validatedAPIKey(apiKey)
        await closeSession()
        let descriptor = try await apiClient.createSession(
            apiKey: key,
            startURL: startURL,
            timeoutSeconds: Self.clampedTimeout(timeoutSeconds)
        )
        let client = makeCDPClient()
        try await client.connect(to: descriptor.cdpURL)
        session = descriptor
        cdpClient = client
        latestUsage = try? await apiClient.usage(apiKey: key)
        return try await snapshot(usage: latestUsage)
    }

    public func closeSession() async {
        await cdpClient?.close()
        cdpClient = nil
        session = nil
        latestUsage = nil
    }

    public func navigate(to url: String) async throws -> TinyFishBrowserSnapshot {
        guard let cdpClient else { throw TinyFishBrowserError.pageTargetUnavailable }
        try await cdpClient.navigate(to: url)
        return try await snapshot(usage: latestUsage)
    }

    public func refresh() async throws -> TinyFishBrowserSnapshot {
        try await snapshot(usage: latestUsage)
    }

    public func click(at point: TinyFishViewportPoint) async throws -> TinyFishBrowserSnapshot {
        guard let cdpClient else { throw TinyFishBrowserError.pageTargetUnavailable }
        try await cdpClient.click(at: point)
        return try await snapshot(usage: latestUsage)
    }

    public func typeText(_ text: String, into element: TinyFishRemoteElement?) async throws -> TinyFishBrowserSnapshot {
        guard let cdpClient else { throw TinyFishBrowserError.pageTargetUnavailable }
        if let element {
            try await cdpClient.click(at: element.rect.center)
        }
        try await cdpClient.insertText(text)
        return try await snapshot(usage: latestUsage)
    }

    public func scroll(deltaY: Double) async throws -> TinyFishBrowserSnapshot {
        guard let cdpClient else { throw TinyFishBrowserError.pageTargetUnavailable }
        try await cdpClient.scroll(deltaY: deltaY)
        return try await snapshot(usage: latestUsage)
    }

    public func usage(apiKey: String) async throws -> TinyFishUsageSnapshot {
        let key = try Self.validatedAPIKey(apiKey)
        let snapshot = try await apiClient.usage(apiKey: key)
        latestUsage = snapshot
        return snapshot
    }

    private func snapshot(usage: TinyFishUsageSnapshot?) async throws -> TinyFishBrowserSnapshot {
        guard let session, let cdpClient else { throw TinyFishBrowserError.pageTargetUnavailable }
        return TinyFishBrowserSnapshot(
            session: session,
            frame: try await cdpClient.captureFrame(),
            usage: usage
        )
    }

    private static func validatedAPIKey(_ apiKey: String) throws -> String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TinyFishBrowserError.missingAPIKey }
        return trimmed
    }

    private static func clampedTimeout(_ timeoutSeconds: Int) -> Int {
        min(max(timeoutSeconds, 5), 86_400)
    }
}
