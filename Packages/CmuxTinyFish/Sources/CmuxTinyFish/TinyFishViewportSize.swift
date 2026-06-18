/// A browser viewport size in CSS pixels.
public struct TinyFishViewportSize: Sendable, Equatable, Codable {
    /// The viewport width.
    public let width: Double
    /// The viewport height.
    public let height: Double

    /// Creates a viewport size.
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}
