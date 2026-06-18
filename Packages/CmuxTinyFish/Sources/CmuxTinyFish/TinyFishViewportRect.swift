/// A rectangle in browser viewport CSS pixels.
public struct TinyFishViewportRect: Sendable, Equatable, Codable {
    /// The x coordinate.
    public let x: Double
    /// The y coordinate.
    public let y: Double
    /// The width.
    public let w: Double
    /// The height.
    public let h: Double

    /// Creates a viewport rectangle.
    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    /// The center point of the rectangle in viewport CSS pixels.
    public var center: TinyFishViewportPoint {
        TinyFishViewportPoint(x: x + w / 2, y: y + h / 2)
    }
}
