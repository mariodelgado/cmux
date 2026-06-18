public import Foundation

/// URLSession WebSocket implementation of the TinyFish CDP client.
public actor URLSessionTinyFishCDPClient: TinyFishCDPClientProtocol {
    private let urlSession: URLSession
    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var nextID: Int = 1
    private var pageSessionID: String?
    private var pending: [Int: CheckedContinuation<TinyFishJSONValue, any Error>] = [:]
    private var loadGeneration: Int = 0
    private var loadWaiters: [UUID: LoadWaiter] = [:]

    /// Creates a CDP client.
    ///
    /// - Parameter urlSession: URLSession used to create the WebSocket task.
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func connect(to cdpURL: URL) async throws {
        await close()
        let socket = urlSession.webSocketTask(with: cdpURL)
        webSocket = socket
        socket.resume()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop()
        }

        let targets = try await send(method: "Target.getTargets", params: EmptyParams(), sessionID: nil)
        guard let targetID = Self.pageTargetID(in: targets) else {
            throw TinyFishBrowserError.pageTargetUnavailable
        }
        let attach = try await send(
            method: "Target.attachToTarget",
            params: AttachToTargetParams(targetID: targetID, flatten: true),
            sessionID: nil
        )
        guard let sessionID = attach["sessionId"]?.stringValue else {
            throw TinyFishBrowserError.malformedResponse(
                String(localized: "tinyfish.error.missingSessionID", defaultValue: "CDP attach response did not include a session id.")
            )
        }
        pageSessionID = sessionID
        _ = try await pageCommand("Page.enable", EmptyParams())
        _ = try await pageCommand("Runtime.enable", EmptyParams())
        _ = try await pageCommand("DOM.enable", EmptyParams())
    }

    public func close() async {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        pageSessionID = nil
        for continuation in pending.values {
            continuation.resume(throwing: CancellationError())
        }
        pending.removeAll()
        for waiter in loadWaiters.values {
            waiter.continuation.resume()
        }
        loadWaiters.removeAll()
    }

    public func navigate(to url: String) async throws {
        let generation = loadGeneration
        _ = try await pageCommand("Page.navigate", NavigateParams(url: url))
        try await waitForLoad(after: generation, timeoutNanoseconds: 15_000_000_000)
    }

    public func captureFrame() async throws -> TinyFishBrowserFrame {
        let screenshot = try await pageCommand("Page.captureScreenshot", CaptureScreenshotParams(format: "png"))
        guard let base64 = screenshot["data"]?.stringValue,
              let data = Data(base64Encoded: base64) else {
            throw TinyFishBrowserError.malformedResponse(
                String(localized: "tinyfish.error.missingScreenshot", defaultValue: "CDP screenshot response did not include PNG data.")
            )
        }

        let overlay = try await evaluateOverlay()
        return TinyFishBrowserFrame(
            pngData: data,
            viewportSize: overlay.viewportSize,
            elements: overlay.elements
        )
    }

    public func click(at point: TinyFishViewportPoint) async throws {
        _ = try await pageCommand(
            "Input.dispatchMouseEvent",
            MouseEventParams(type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1, deltaY: nil)
        )
        _ = try await pageCommand(
            "Input.dispatchMouseEvent",
            MouseEventParams(type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1, deltaY: nil)
        )
    }

    public func insertText(_ text: String) async throws {
        _ = try await pageCommand("Input.insertText", InsertTextParams(text: text))
    }

    public func scroll(deltaY: Double) async throws {
        _ = try await pageCommand(
            "Input.dispatchMouseEvent",
            MouseEventParams(type: "mouseWheel", x: 0, y: 0, button: nil, clickCount: nil, deltaY: deltaY)
        )
    }

    private func pageCommand<Params: Encodable>(_ method: String, _ params: Params) async throws -> TinyFishJSONValue {
        guard let pageSessionID else {
            throw TinyFishBrowserError.pageTargetUnavailable
        }
        return try await send(method: method, params: params, sessionID: pageSessionID)
    }

    private func send<Params: Encodable>(
        method: String,
        params: Params,
        sessionID: String?
    ) async throws -> TinyFishJSONValue {
        guard let webSocket else {
            throw TinyFishBrowserError.malformedResponse(
                String(localized: "tinyfish.error.cdpNotConnected", defaultValue: "CDP client is not connected.")
            )
        }
        let id = nextID
        nextID += 1
        let command = CDPCommand(id: id, method: method, params: params, sessionID: sessionID)
        let data = try JSONEncoder().encode(command)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw TinyFishBrowserError.malformedResponse(
                String(localized: "tinyfish.error.commandEncoding", defaultValue: "Could not encode a CDP command.")
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task { [weak self] in
                do {
                    try await webSocket.send(.string(payload))
                } catch {
                    await self?.resumePending(id: id, result: .failure(error))
                }
            }
        }
    }

    private func resumePending(id: Int, result: Result<TinyFishJSONValue, any Error>) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let webSocket else { return }
            do {
                let message = try await webSocket.receive()
                try await handle(message: message)
            } catch {
                for id in pending.keys {
                    resumePending(id: id, result: .failure(error))
                }
                return
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) async throws {
        let data: Data
        switch message {
        case .data(let messageData):
            data = messageData
        case .string(let string):
            data = Data(string.utf8)
        @unknown default:
            return
        }

        let response = try JSONDecoder().decode(CDPMessage.self, from: data)
        if let method = response.method {
            handleEvent(method: method, sessionID: response.sessionID)
            return
        }
        guard let id = response.id else { return }
        if let error = response.error {
            resumePending(id: id, result: .failure(TinyFishBrowserError.cdp(code: error.code, message: error.message)))
            return
        }
        resumePending(id: id, result: .success(response.result ?? .object([:])))
    }

    private func handleEvent(method: String, sessionID: String?) {
        guard sessionID == pageSessionID || sessionID == nil else { return }
        if method == "Page.loadEventFired" {
            loadGeneration += 1
            let generation = loadGeneration
            let ready = loadWaiters.filter { _, waiter in generation > waiter.minimumGeneration }
            for (id, waiter) in ready {
                loadWaiters.removeValue(forKey: id)
                waiter.continuation.resume()
            }
        }
    }

    private func waitForLoad(after generation: Int, timeoutNanoseconds: UInt64) async throws {
        if loadGeneration > generation { return }
        let id = UUID()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { await self.waitForLoadEvent(id: id, after: generation) }
                group.addTask {
                    // Genuine deadline for a provider operation; not polling.
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    throw TinyFishBrowserError.loadTimeout
                }
                _ = try await group.next()
                group.cancelAll()
                cancelLoadWaiter(id: id)
            }
        } catch {
            cancelLoadWaiter(id: id)
            throw error
        }
    }

    private func waitForLoadEvent(id: UUID, after generation: Int) async {
        if loadGeneration > generation { return }
        await withCheckedContinuation { continuation in
            loadWaiters[id] = LoadWaiter(minimumGeneration: generation, continuation: continuation)
        }
    }

    private func cancelLoadWaiter(id: UUID) {
        guard let waiter = loadWaiters.removeValue(forKey: id) else { return }
        waiter.continuation.resume()
    }

    private func evaluateOverlay() async throws -> OverlayPayload {
        let result = try await pageCommand(
            "Runtime.evaluate",
            RuntimeEvaluateParams(
                expression: Self.overlayExpression,
                returnByValue: true,
                awaitPromise: true
            )
        )
        guard let value = result["result"]?["value"] else {
            throw TinyFishBrowserError.malformedResponse(
                String(localized: "tinyfish.error.missingOverlay", defaultValue: "CDP overlay evaluation did not return a value.")
            )
        }
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(OverlayPayload.self, from: data)
    }

    private static func pageTargetID(in value: TinyFishJSONValue) -> String? {
        guard let infos = value["targetInfos"]?.arrayValue else { return nil }
        let page = infos.first { info in
            info["type"]?.stringValue == "page"
        }
        return page?["targetId"]?.stringValue
    }

    private static let overlayExpression = """
    (() => {
      const selector = 'a,button,input,textarea,select,[role="button"],[role="link"],[role="textbox"],[contenteditable="true"],[tabindex]';
      const nodes = Array.from(document.querySelectorAll(selector));
      const width = Math.max(1, window.innerWidth || document.documentElement.clientWidth || 1);
      const height = Math.max(1, window.innerHeight || document.documentElement.clientHeight || 1);
      const elements = [];
      for (let index = 0; index < nodes.length; index++) {
        const el = nodes[index];
        const rect = el.getBoundingClientRect();
        if (!rect || rect.width < 3 || rect.height < 3) continue;
        if (rect.right < 0 || rect.bottom < 0 || rect.left > width || rect.top > height) continue;
        const style = window.getComputedStyle(el);
        if (style.visibility === 'hidden' || style.display === 'none' || Number(style.opacity || '1') === 0) continue;
        const tag = (el.tagName || '').toLowerCase();
        const role = (el.getAttribute('role') || '').toLowerCase();
        const editable = el.getAttribute('contenteditable') === 'true';
        const type = (el.getAttribute('type') || '').toLowerCase();
        const isTextInput = editable || tag === 'textarea' || tag === 'select' || role === 'textbox' || (tag === 'input' && !['button','submit','checkbox','radio','range','color','file','image','reset'].includes(type));
        const label = (el.getAttribute('aria-label') || el.getAttribute('title') || el.getAttribute('placeholder') || el.innerText || el.value || tag || '').trim().replace(/\\s+/g, ' ').slice(0, 80);
        elements.push({
          id: String(elements.length + 1),
          rect: { x: rect.left, y: rect.top, w: rect.width, h: rect.height },
          tag,
          label,
          isTextInput
        });
      }
      return { viewportSize: { width, height }, elements };
    })()
    """

    private struct LoadWaiter {
        let minimumGeneration: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct EmptyParams: Encodable {}

    private struct CDPCommand<Params: Encodable>: Encodable {
        let id: Int
        let method: String
        let params: Params
        let sessionID: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case method
            case params
            case sessionID = "sessionId"
        }
    }

    private struct CDPMessage: Decodable {
        let id: Int?
        let sessionID: String?
        let method: String?
        let result: TinyFishJSONValue?
        let error: CDPErrorPayload?

        private enum CodingKeys: String, CodingKey {
            case id
            case sessionID = "sessionId"
            case method
            case result
            case error
        }
    }

    private struct CDPErrorPayload: Decodable {
        let code: Int
        let message: String
    }

    private struct AttachToTargetParams: Encodable {
        let targetID: String
        let flatten: Bool

        private enum CodingKeys: String, CodingKey {
            case targetID = "targetId"
            case flatten
        }
    }

    private struct NavigateParams: Encodable {
        let url: String
    }

    private struct CaptureScreenshotParams: Encodable {
        let format: String
    }

    private struct RuntimeEvaluateParams: Encodable {
        let expression: String
        let returnByValue: Bool
        let awaitPromise: Bool
    }

    private struct InsertTextParams: Encodable {
        let text: String
    }

    private struct MouseEventParams: Encodable {
        let type: String
        let x: Double
        let y: Double
        let button: String?
        let clickCount: Int?
        let deltaY: Double?
    }

    private struct OverlayPayload: Decodable {
        let viewportSize: TinyFishViewportSize
        let elements: [TinyFishRemoteElement]
    }
}
