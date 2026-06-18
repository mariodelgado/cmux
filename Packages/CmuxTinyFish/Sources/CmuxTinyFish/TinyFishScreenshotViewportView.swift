public import AppKit
public import SwiftUI

/// Screenshot renderer with scaled TinyFish element hotspots.
public struct TinyFishScreenshotViewportView: View {
    private let image: NSImage?
    private let frame: TinyFishBrowserFrame?
    private let overlayVisible: Bool
    private let selectedElementID: String?
    private let onElementClick: (TinyFishRemoteElement) -> Void
    private let onViewportClick: (TinyFishViewportPoint) -> Void

    /// Creates a screenshot viewport view.
    public init(
        image: NSImage?,
        frame: TinyFishBrowserFrame?,
        overlayVisible: Bool,
        selectedElementID: String?,
        onElementClick: @escaping (TinyFishRemoteElement) -> Void,
        onViewportClick: @escaping (TinyFishViewportPoint) -> Void
    ) {
        self.image = image
        self.frame = frame
        self.overlayVisible = overlayVisible
        self.selectedElementID = selectedElementID
        self.onElementClick = onElementClick
        self.onViewportClick = onViewportClick
    }

    public var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let fit = aspectFitRect(in: bounds)
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: fit.width, height: fit.height)
                        .position(x: fit.midX, y: fit.midY)
                        .contentShape(Rectangle())
                        .gesture(rawClickGesture(fit: fit))
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.24))
                        .overlay {
                            Text(String(localized: "tinyfish.panel.empty", defaultValue: "No remote browser frame"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
                if overlayVisible, let frame {
                    ForEach(frame.elements) { element in
                        hotspot(element, fit: fit, viewportSize: frame.viewportSize)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func rawClickGesture(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard let frame, fit.contains(value.location) else { return }
                let scaleX = frame.viewportSize.width / Double(fit.width)
                let scaleY = frame.viewportSize.height / Double(fit.height)
                onViewportClick(
                    TinyFishViewportPoint(
                        x: Double(value.location.x - fit.minX) * scaleX,
                        y: Double(value.location.y - fit.minY) * scaleY
                    )
                )
            }
    }

    private func hotspot(
        _ element: TinyFishRemoteElement,
        fit: CGRect,
        viewportSize: TinyFishViewportSize
    ) -> some View {
        let rect = displayRect(for: element.rect, fit: fit, viewportSize: viewportSize)
        let selected = selectedElementID == element.id
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(selected ? Color.cyan : Color.orange, lineWidth: selected ? 2 : 1.4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill((selected ? Color.cyan : Color.orange).opacity(0.12))
                )
            Text(element.id)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background((selected ? Color.cyan : Color.orange).opacity(0.9), in: Capsule())
                .padding(2)
        }
        .frame(width: max(10, rect.width), height: max(10, rect.height))
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture {
            onElementClick(element)
        }
        .help(element.label.isEmpty ? element.tag : element.label)
    }

    private func aspectFitRect(in bounds: CGRect) -> CGRect {
        guard let frame else { return bounds }
        let viewport = frame.viewportSize
        guard viewport.width > 0, viewport.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let viewportWidth = CGFloat(viewport.width)
        let viewportHeight = CGFloat(viewport.height)
        let scale = min(bounds.width / viewportWidth, bounds.height / viewportHeight)
        let size = CGSize(width: viewportWidth * scale, height: viewportHeight * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func displayRect(
        for rect: TinyFishViewportRect,
        fit: CGRect,
        viewportSize: TinyFishViewportSize
    ) -> CGRect {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return .zero }
        let scaleX = fit.width / CGFloat(viewportSize.width)
        let scaleY = fit.height / CGFloat(viewportSize.height)
        return CGRect(
            x: fit.minX + rect.x * scaleX,
            y: fit.minY + rect.y * scaleY,
            width: rect.w * scaleX,
            height: rect.h * scaleY
        )
    }
}
