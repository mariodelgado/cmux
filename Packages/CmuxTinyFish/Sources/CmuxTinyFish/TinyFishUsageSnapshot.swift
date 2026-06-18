/// Usage information returned by TinyFish for the current API key.
public struct TinyFishUsageSnapshot: Sendable, Equatable {
    /// Raw usage JSON.
    public let raw: TinyFishJSONValue

    /// Creates a usage snapshot.
    public init(raw: TinyFishJSONValue) {
        self.raw = raw
    }

    /// A compact text representation suitable for the panel footer.
    public var displayText: String {
        raw.compactDescription
    }
}
