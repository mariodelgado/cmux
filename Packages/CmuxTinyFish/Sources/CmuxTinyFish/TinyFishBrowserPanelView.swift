public import SwiftUI

/// Right-sidebar panel for the TinyFish remote browser.
public struct TinyFishBrowserPanelView: View {
    private let apiKey: String
    private let enabled: Bool
    private let timeoutSeconds: Int

    @State private var model: TinyFishBrowserPanelModel

    /// Creates a TinyFish browser panel.
    ///
    /// - Parameters:
    ///   - apiKey: Resolved TinyFish API key.
    ///   - enabled: Whether the integration is enabled.
    ///   - timeoutSeconds: Session timeout in seconds.
    ///   - model: Panel model, injectable for tests/previews.
    public init(
        apiKey: String,
        enabled: Bool,
        timeoutSeconds: Int,
        model: TinyFishBrowserPanelModel = TinyFishBrowserPanelModel()
    ) {
        self.apiKey = apiKey
        self.enabled = enabled
        self.timeoutSeconds = min(max(timeoutSeconds, 5), 86_400)
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Self.hairline)
            screenshotArea
            Divider().overlay(Self.hairline)
            footer
        }
        .background(Self.panelBackground)
        .foregroundStyle(Self.text)
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField(
                    String(localized: "tinyfish.panel.url.placeholder", defaultValue: "https://example.com"),
                    text: $model.urlText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Self.controlBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Self.hairline, lineWidth: 1)
                )
                .onSubmit { model.submitURL(apiKey: apiKey, timeoutSeconds: timeoutSeconds) }
                .disabled(!canUse)

                iconButton("play", help: String(localized: "tinyfish.panel.navigate", defaultValue: "Navigate")) {
                    model.submitURL(apiKey: apiKey, timeoutSeconds: timeoutSeconds)
                }
                .disabled(!canUse || model.isLoading)
            }

            HStack(spacing: 6) {
                iconButton("plus", help: String(localized: "tinyfish.panel.newSession", defaultValue: "New session")) {
                    model.createNewSession(apiKey: apiKey, timeoutSeconds: timeoutSeconds)
                }
                .disabled(!canUse || model.isLoading)
                iconButton("xmark", help: String(localized: "tinyfish.panel.closeSession", defaultValue: "Close session")) {
                    model.closeSession()
                }
                .disabled(model.sessionID == nil)
                iconButton("arrow.clockwise", help: String(localized: "tinyfish.panel.refresh", defaultValue: "Refresh screenshot")) {
                    model.refresh()
                }
                .disabled(model.sessionID == nil || model.isLoading)
                iconButton(model.overlayVisible ? "rectangle.dashed" : "rectangle", help: String(localized: "tinyfish.panel.toggleOverlay", defaultValue: "Toggle element overlay")) {
                    model.overlayVisible.toggle()
                }
                iconButton("arrow.up", help: String(localized: "tinyfish.panel.scrollUp", defaultValue: "Scroll up")) {
                    model.scroll(deltaY: -420)
                }
                .disabled(model.sessionID == nil || model.isLoading)
                iconButton("arrow.down", help: String(localized: "tinyfish.panel.scrollDown", defaultValue: "Scroll down")) {
                    model.scroll(deltaY: 420)
                }
                .disabled(model.sessionID == nil || model.isLoading)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                TextField(
                    String(localized: "tinyfish.panel.type.placeholder", defaultValue: "Type into selected element"),
                    text: $model.typedText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Self.controlBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Self.hairline, lineWidth: 1)
                )
                .disabled(model.selectedElementID == nil || model.isLoading)
                .onSubmit { model.typeIntoSelectedElement() }

                iconButton("text.cursor", help: String(localized: "tinyfish.panel.type", defaultValue: "Type text")) {
                    model.typeIntoSelectedElement()
                }
                .disabled(model.selectedElementID == nil || model.typedText.isEmpty || model.isLoading)
            }
        }
        .padding(10)
    }

    private var screenshotArea: some View {
        ZStack {
            TinyFishScreenshotViewportView(
                image: model.image,
                frame: model.frame,
                overlayVisible: model.overlayVisible,
                selectedElementID: model.selectedElementID,
                onElementClick: { model.click(element: $0) },
                onViewportClick: { model.click(at: $0) }
            )
            .padding(8)

            if !canUse {
                unavailableOverlay
            } else if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if let error = model.errorMessage {
                errorBanner(error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(sessionFooterText)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(Self.subtext)
            Spacer(minLength: 0)
            if !model.usageText.isEmpty {
                Text(model.usageText)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(Self.subtext)
            }
            iconButton("chart.bar", help: String(localized: "tinyfish.panel.refreshUsage", defaultValue: "Refresh usage")) {
                model.refreshUsage(apiKey: apiKey)
            }
            .disabled(!canUse || model.isLoading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var unavailableOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: "key.slash")
                .font(.system(size: 18, weight: .semibold))
            Text(String(localized: "tinyfish.panel.disabled.title", defaultValue: "TinyFish Browser unavailable"))
                .font(.system(size: 12, weight: .semibold))
            Text(String(localized: "tinyfish.panel.disabled.subtitle", defaultValue: "Enable TinyFish and add an API key in Settings."))
                .font(.caption)
                .foregroundStyle(Self.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.hairline, lineWidth: 1))
        .padding(20)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text(message)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .padding(9)
            .background(Color(red: 0.36, green: 0.11, blue: 0.13).opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.35), lineWidth: 1))
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .background(Self.controlBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Self.hairline, lineWidth: 1))
        .help(help)
        .accessibilityLabel(help)
    }

    private var canUse: Bool {
        enabled && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sessionFooterText: String {
        if let sessionID = model.sessionID {
            return sessionID
        }
        return String(localized: "tinyfish.panel.noSession", defaultValue: "No session")
    }

    private static let panelBackground = Color(red: 0.08, green: 0.08, blue: 0.12)
    private static let controlBackground = Color(red: 0.12, green: 0.12, blue: 0.17).opacity(0.96)
    private static let hairline = Color(red: 0.33, green: 0.34, blue: 0.47).opacity(0.55)
    private static let text = Color(red: 0.80, green: 0.84, blue: 0.96)
    private static let subtext = Color(red: 0.65, green: 0.68, blue: 0.82)
}
