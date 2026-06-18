/// Current TinyFish remote browser state returned to the panel model.
public struct TinyFishBrowserSnapshot: Sendable, Equatable {
    /// The active TinyFish session descriptor.
    public let session: TinyFishBrowserSessionDescriptor
    /// The latest rendered frame.
    public let frame: TinyFishBrowserFrame
    /// Optional usage information for the current API key.
    public let usage: TinyFishUsageSnapshot?

    /// Creates a browser snapshot.
    public init(
        session: TinyFishBrowserSessionDescriptor,
        frame: TinyFishBrowserFrame,
        usage: TinyFishUsageSnapshot? = nil
    ) {
        self.session = session
        self.frame = frame
        self.usage = usage
    }
}
