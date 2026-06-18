public import Foundation

/// URLSession-backed implementation of ``TinyFishBrowserAPIClient``.
public struct URLSessionTinyFishBrowserAPIClient: TinyFishBrowserAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Creates a TinyFish REST API client.
    ///
    /// - Parameters:
    ///   - baseURL: TinyFish Browser API root. Defaults to `https://api.browser.tinyfish.ai/`.
    ///   - session: URLSession used for requests.
    public init(
        baseURL: URL = URL(string: "https://api.browser.tinyfish.ai/")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    public func createSession(
        apiKey: String,
        startURL: String?,
        timeoutSeconds: Int?
    ) async throws -> TinyFishBrowserSessionDescriptor {
        let requestBody = CreateSessionRequest(url: startURL, timeoutSeconds: timeoutSeconds)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, expectedStatus: 201)
        return try decoder.decode(TinyFishBrowserSessionDescriptor.self, from: data)
    }

    public func usage(apiKey: String) async throws -> TinyFishUsageSnapshot {
        let usageURL = baseURL.appendingPathComponent("usage", isDirectory: false)
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, expectedStatus: 200)
        return TinyFishUsageSnapshot(raw: try decoder.decode(TinyFishJSONValue.self, from: data))
    }

    private func validate(response: URLResponse, data: Data, expectedStatus: Int) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TinyFishBrowserError.malformedResponse(
                String(localized: "tinyfish.error.nonHTTPResponse", defaultValue: "TinyFish returned a non-HTTP response.")
            )
        }
        guard http.statusCode == expectedStatus else {
            if let payload = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw TinyFishBrowserError.api(
                    code: payload.error.code,
                    message: payload.error.message,
                    details: payload.error.details
                )
            }
            throw TinyFishBrowserError.unexpectedStatus(http.statusCode)
        }
    }

    private struct CreateSessionRequest: Encodable {
        let url: String?
        let timeoutSeconds: Int?

        private enum CodingKeys: String, CodingKey {
            case url
            case timeoutSeconds = "timeout_seconds"
        }
    }

    private struct APIErrorEnvelope: Decodable {
        let error: APIErrorPayload
    }

    private struct APIErrorPayload: Decodable {
        let code: String
        let message: String
        let details: TinyFishJSONValue?
    }
}
