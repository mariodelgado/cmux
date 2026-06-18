import Foundation
import Testing
@testable import CmuxTinyFish

@Suite("TinyFish browser service")
struct TinyFishBrowserServiceTests {
    @Test("creates a session with a clamped timeout and captures a frame")
    func createSessionConnectsAndCapturesFrame() async throws {
        let api = RecordingTinyFishAPIClient()
        let cdp = RecordingTinyFishCDPClient()
        let service = TinyFishBrowserService(apiClient: api) { cdp }

        let snapshot = try await service.createSession(
            apiKey: "  test-key  ",
            startURL: "https://example.com",
            timeoutSeconds: 1
        )

        let createCall = try #require(await api.createCalls.first)
        #expect(createCall.apiKey == "test-key")
        #expect(createCall.startURL == "https://example.com")
        #expect(createCall.timeoutSeconds == 5)
        #expect(await cdp.connectedURL == RecordingTinyFishAPIClient.session.cdpURL)
        #expect(await cdp.captureCount == 1)
        #expect(snapshot.session.sessionID == "br-test")
        #expect(snapshot.frame.elements.map(\.id) == ["field"])
        #expect(snapshot.usage?.displayText == "{\"credits\":42}")
    }

    @Test("dispatches navigation, click, typing, and scroll through CDP")
    func dispatchesInteractiveOperations() async throws {
        let api = RecordingTinyFishAPIClient()
        let cdp = RecordingTinyFishCDPClient()
        let service = TinyFishBrowserService(apiClient: api) { cdp }
        _ = try await service.createSession(apiKey: "key", startURL: nil, timeoutSeconds: 120)

        _ = try await service.navigate(to: "https://openai.com")
        _ = try await service.click(at: TinyFishViewportPoint(x: 10, y: 20))
        _ = try await service.typeText("hello", into: RecordingTinyFishCDPClient.textElement)
        _ = try await service.scroll(deltaY: 240)

        #expect(await cdp.navigations == ["https://openai.com"])
        #expect(await cdp.clicks == [
            TinyFishViewportPoint(x: 10, y: 20),
            RecordingTinyFishCDPClient.textElement.rect.center,
        ])
        #expect(await cdp.insertedText == ["hello"])
        #expect(await cdp.scrollDeltas == [240])
        #expect(await cdp.captureCount == 5)
    }

    @Test("rejects an empty API key before creating a session")
    func rejectsMissingAPIKey() async {
        let api = RecordingTinyFishAPIClient()
        let cdp = RecordingTinyFishCDPClient()
        let service = TinyFishBrowserService(apiClient: api) { cdp }

        await #expect(throws: TinyFishBrowserError.missingAPIKey) {
            _ = try await service.createSession(apiKey: "  ", startURL: nil, timeoutSeconds: 120)
        }
        #expect(await api.createCalls.isEmpty)
        #expect(await cdp.connectedURL == nil)
    }
}

private actor RecordingTinyFishAPIClient: TinyFishBrowserAPIClient {
    static let session = TinyFishBrowserSessionDescriptor(
        sessionID: "br-test",
        cdpURL: URL(string: "wss://example.test/session/cdp")!,
        baseURL: URL(string: "https://example.test/session")!
    )

    private(set) var createCalls: [CreateCall] = []
    private(set) var usageKeys: [String] = []

    func createSession(apiKey: String, startURL: String?, timeoutSeconds: Int?) async throws -> TinyFishBrowserSessionDescriptor {
        createCalls.append(CreateCall(apiKey: apiKey, startURL: startURL, timeoutSeconds: timeoutSeconds))
        return Self.session
    }

    func usage(apiKey: String) async throws -> TinyFishUsageSnapshot {
        usageKeys.append(apiKey)
        return TinyFishUsageSnapshot(raw: .object(["credits": .number(42)]))
    }

    struct CreateCall: Sendable, Equatable {
        let apiKey: String
        let startURL: String?
        let timeoutSeconds: Int?
    }
}

private actor RecordingTinyFishCDPClient: TinyFishCDPClientProtocol {
    static let textElement = TinyFishRemoteElement(
        id: "field",
        rect: TinyFishViewportRect(x: 4, y: 8, w: 120, h: 24),
        tag: "input",
        label: "Search",
        isTextInput: true
    )

    private(set) var connectedURL: URL?
    private(set) var closeCount = 0
    private(set) var navigations: [String] = []
    private(set) var captureCount = 0
    private(set) var clicks: [TinyFishViewportPoint] = []
    private(set) var insertedText: [String] = []
    private(set) var scrollDeltas: [Double] = []

    func connect(to cdpURL: URL) async throws {
        connectedURL = cdpURL
    }

    func close() async {
        closeCount += 1
    }

    func navigate(to url: String) async throws {
        navigations.append(url)
    }

    func captureFrame() async throws -> TinyFishBrowserFrame {
        captureCount += 1
        return TinyFishBrowserFrame(
            pngData: Data("png".utf8),
            viewportSize: TinyFishViewportSize(width: 800, height: 600),
            elements: [Self.textElement]
        )
    }

    func click(at point: TinyFishViewportPoint) async throws {
        clicks.append(point)
    }

    func insertText(_ text: String) async throws {
        insertedText.append(text)
    }

    func scroll(deltaY: Double) async throws {
        scrollDeltas.append(deltaY)
    }
}
