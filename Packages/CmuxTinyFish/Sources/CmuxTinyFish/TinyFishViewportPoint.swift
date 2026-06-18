/// A point in browser viewport CSS pixels.
public struct TinyFishViewportPoint: Sendable, Equatable, Codable {
    /// The x coordinate.
    public let x: Double
    /// The y coordinate.
    public let y: Double

    /// Creates a viewport point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
