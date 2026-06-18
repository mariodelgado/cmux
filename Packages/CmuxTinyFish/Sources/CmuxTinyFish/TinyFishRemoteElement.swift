/// A clickable or typeable element discovered in the remote browser viewport.
public struct TinyFishRemoteElement: Identifiable, Sendable, Equatable, Codable {
    /// The element identifier used by the overlay.
    public let id: String
    /// The viewport rectangle.
    public let rect: TinyFishViewportRect
    /// The lowercase element tag name.
    public let tag: String
    /// A best-effort label from text, aria-label, title, placeholder, or value.
    public let label: String
    /// Whether the element is likely to accept typed text.
    public let isTextInput: Bool

    /// Creates a remote element snapshot.
    public init(
        id: String,
        rect: TinyFishViewportRect,
        tag: String,
        label: String,
        isTextInput: Bool
    ) {
        self.id = id
        self.rect = rect
        self.tag = tag
        self.label = label
        self.isTextInput = isTextInput
    }
}
