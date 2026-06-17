enum AIBackendError: Error, Equatable, Sendable {
    case disabled
    case unavailable
    case emptyInput
    case emptyResponse
}
