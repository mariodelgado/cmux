enum AITaskKind: Sendable {
    case light(maximumResponseTokens: Int)
    case heavy(maximumResponseTokens: Int)

    var maximumResponseTokens: Int {
        switch self {
        case let .light(maximumResponseTokens), let .heavy(maximumResponseTokens):
            return maximumResponseTokens
        }
    }

    var prefersFoundationModels: Bool {
        switch self {
        case .light:
            return true
        case .heavy:
            return false
        }
    }
}
