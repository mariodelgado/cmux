public import Foundation

/// A rendered TinyFish browser frame: PNG screenshot plus interactive overlay data.
public struct TinyFishBrowserFrame: Sendable, Equatable {
    /// PNG screenshot bytes returned by CDP.
    public let pngData: Data
    /// Viewport size in CSS pixels.
    public let viewportSize: TinyFishViewportSize
    /// Interactive elements discovered for overlay hotspots.
    public let elements: [TinyFishRemoteElement]

    /// Creates a browser frame snapshot.
    public init(
        pngData: Data,
        viewportSize: TinyFishViewportSize,
        elements: [TinyFishRemoteElement]
    ) {
        self.pngData = pngData
        self.viewportSize = viewportSize
        self.elements = elements
    }
}
