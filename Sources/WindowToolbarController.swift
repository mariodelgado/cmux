import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowToolbarController: NSObject, NSToolbarDelegate {
    private let commandItemIdentifier = NSToolbarItem.Identifier("cmux.focusedCommand")
    private let layoutModeItemIdentifier = NSToolbarItem.Identifier("cmux.layoutMode")
    private let parsedPaneAccessoryIdentifier = NSUserInterfaceItemIdentifier("cmux.parsedPaneMode")

    private weak var tabManager: TabManager?

    private var commandLabels: [ObjectIdentifier: NSTextField] = [:]
    private var layoutModeControls: [ObjectIdentifier: NSSegmentedControl] = [:]
    private var parsedPaneAccessories: [ObjectIdentifier: NSTitlebarAccessoryViewController] = [:]
    private var parsedPaneControls: [ObjectIdentifier: NSSegmentedControl] = [:]
    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var didStart = false
    private let focusedCommandUpdateCoalescer = NotificationBurstCoalescer(delay: 1.0 / 30.0)
    private var lastKnownPresentationMode: WorkspacePresentationModeSettings.Mode = WorkspacePresentationModeSettings.mode()

    override init() {
        super.init()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start(tabManager: TabManager) {
        self.tabManager = tabManager
        guard !didStart else {
            refreshParsedPaneAccessories()
            scheduleFocusedCommandTextUpdate()
            updateLayoutModeSelection()
            return
        }
        didStart = true
        attachToExistingWindows()
        installObservers()
        SharedLiveAgentIndex.shared.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshParsedPaneAccessories()
                }
            }
            .store(in: &cancellables)
        scheduleFocusedCommandTextUpdate()
        updateLayoutModeSelection()
        refreshParsedPaneAccessories()
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .ghosttyDidSetTitle,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFocusedCommandTextUpdate()
            }
        })

        observers.append(center.addObserver(
            forName: .ghosttyDidFocusTab,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFocusedCommandTextUpdate()
                self?.updateLayoutModeSelection()
                self?.refreshParsedPaneAccessories()
            }
        })

        observers.append(center.addObserver(
            forName: .ghosttyDidFocusSurface,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFocusedCommandTextUpdate()
                self?.updateLayoutModeSelection()
                self?.refreshParsedPaneAccessories()
            }
        })

        observers.append(center.addObserver(
            forName: .workspaceLayoutModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLayoutModeSelection()
                self?.refreshParsedPaneAccessories()
            }
        })

        // A grouped anchor's command label name is derived from its group's
        // name, so a group rename must refresh the label text (#5404). Scope to
        // this controller's own `tabManager` (the notification's `object`) so a
        // rename in another window doesn't spuriously refresh this one.
        observers.append(center.addObserver(
            forName: .workspaceGroupNameDidChange,
            object: tabManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFocusedCommandTextUpdate()
            }
        })

        observers.append(center.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self?.attach(to: window)
                self?.refreshParsedPaneAccessories()
            }
        })

        observers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self?.attach(to: window)
                self?.refreshParsedPaneAccessories()
            }
        })

        observers.append(center.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateToolbarVisibilityIfNeeded()
                self?.refreshParsedPaneAccessories()
            }
        })
    }

    private func updateToolbarVisibilityIfNeeded() {
        let currentMode = WorkspacePresentationModeSettings.mode()
        guard currentMode != lastKnownPresentationMode else { return }
        lastKnownPresentationMode = currentMode
        let isMinimal = currentMode == .minimal
        for window in NSApp.windows {
            if isMinimal {
                window.toolbar = nil
            } else {
                attach(to: window)
            }
        }
        refreshParsedPaneAccessories()
        // After toolbar changes, force titlebar accessories to recalculate.
        // Toolbar removal/re-addition changes the titlebar geometry, and
        // accessories hidden via isHidden need a layout pass to reappear.
        if !isMinimal {
            DispatchQueue.main.async {
                for window in NSApp.windows {
                    for accessory in window.titlebarAccessoryViewControllers {
                        if !accessory.isHidden {
                            accessory.view.needsLayout = true
                            accessory.view.superview?.needsLayout = true
                        }
                    }
                    window.contentView?.needsLayout = true
                    window.contentView?.superview?.needsLayout = true
                    window.invalidateShadow()
                }
            }
        }
    }

    private func attachToExistingWindows() {
        for window in NSApp.windows {
            attach(to: window)
        }
    }

    func attach(to window: NSWindow) {
        guard AppDelegate.shared?.contextForMainWindow(window) != nil else { return }
        guard !WorkspacePresentationModeSettings.isMinimal() else { return }
        installParsedPaneAccessory(on: window)
        guard window.toolbar == nil else { return }
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("cmux.toolbar"))
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .small
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden
    }

    private func installParsedPaneAccessory(on window: NSWindow) {
        if window.titlebarAccessoryViewControllers.contains(where: { $0.view.identifier == parsedPaneAccessoryIdentifier }) {
            return
        }

        let segmented = NSSegmentedControl()
        segmented.segmentStyle = .texturedRounded
        segmented.trackingMode = .selectOne
        segmented.segmentCount = 2
        segmented.controlSize = .small
        segmented.setLabel(
            String(localized: "parsedView.toggle.terminal", defaultValue: "Terminal"),
            forSegment: ParsedPaneSegment.terminal.rawValue
        )
        segmented.setLabel(
            String(localized: "parsedView.toggle.parsed", defaultValue: "Parsed"),
            forSegment: ParsedPaneSegment.parsed.rawValue
        )
        segmented.setWidth(76, forSegment: ParsedPaneSegment.terminal.rawValue)
        segmented.setWidth(68, forSegment: ParsedPaneSegment.parsed.rawValue)
        segmented.setToolTip(
            String(localized: "parsedView.toggle.terminal", defaultValue: "Terminal"),
            forSegment: ParsedPaneSegment.terminal.rawValue
        )
        segmented.setToolTip(
            String(localized: "parsedView.toggle.parsed", defaultValue: "Parsed"),
            forSegment: ParsedPaneSegment.parsed.rawValue
        )
        segmented.target = self
        segmented.action = #selector(parsedPaneSegmentChanged(_:))
        segmented.setAccessibilityIdentifier("ParsedPaneModeTitlebarToggle")
        segmented.setAccessibilityLabel(String(localized: "parsedView.toggle.accessibility", defaultValue: "Pane view"))

        let container = NSStackView(views: [segmented])
        container.orientation = .horizontal
        container.alignment = .centerY
        container.distribution = .gravityAreas
        container.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        container.identifier = parsedPaneAccessoryIdentifier

        let accessory = NSTitlebarAccessoryViewController()
        // NSTitlebarAccessoryViewController.layoutAttribute only accepts
        // .leading/.trailing/.left/.right/.bottom. A .centerX value throws an
        // uncaught NSInternalInconsistencyException during titlebar layout
        // (-[NSTitlebarViewController insertChildViewController:atIndex:]).
        accessory.layoutAttribute = .trailing
        accessory.view = container
        accessory.isHidden = true
        window.addTitlebarAccessoryViewController(accessory)

        let key = ObjectIdentifier(window)
        parsedPaneAccessories[key] = accessory
        parsedPaneControls[key] = segmented
    }

    private func scheduleFocusedCommandTextUpdate() {
        focusedCommandUpdateCoalescer.signal { [weak self] in
            self?.updateFocusedCommandText()
        }
    }

    private func updateFocusedCommandText() {
        guard let tabManager else { return }
        let text: String
        if let selectedId = tabManager.selectedTabId,
           let tab = tabManager.tabs.first(where: { $0.id == selectedId }) {
            let title = tabManager.resolvedWorkspaceDisplayTitle(for: tab)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            text = title.isEmpty ? "Cmd: —" : "Cmd: \(title)"
        } else {
            text = "Cmd: —"
        }

        for label in commandLabels.values {
            if label.stringValue != text {
                label.stringValue = text
            }
        }
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [layoutModeItemIdentifier, commandItemIdentifier, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [layoutModeItemIdentifier, commandItemIdentifier, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == commandItemIdentifier {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let label = NSTextField(labelWithString: "Cmd: —")
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingMiddle
            label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            item.view = label
            commandLabels[ObjectIdentifier(toolbar)] = label
            scheduleFocusedCommandTextUpdate()
            return item
        }

        if itemIdentifier == layoutModeItemIdentifier {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let segmented = NSSegmentedControl()
            segmented.segmentStyle = .texturedRounded
            segmented.trackingMode = .selectOne
            segmented.segmentCount = 2
            segmented.controlSize = .small
            segmented.setImage(
                NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil),
                forSegment: LayoutModeSegment.splits.rawValue
            )
            segmented.setImage(
                NSImage(systemSymbolName: "square.on.square.dashed", accessibilityDescription: nil),
                forSegment: LayoutModeSegment.canvas.rawValue
            )
            segmented.setToolTip(
                String(localized: "toolbar.layout.splits", defaultValue: "Split panes"),
                forSegment: LayoutModeSegment.splits.rawValue
            )
            segmented.setToolTip(
                String(localized: "toolbar.layout.canvas", defaultValue: "Canvas"),
                forSegment: LayoutModeSegment.canvas.rawValue
            )
            segmented.target = self
            segmented.action = #selector(layoutModeSegmentChanged(_:))
            item.view = segmented
            item.label = String(localized: "toolbar.layout.label", defaultValue: "Layout")
            item.toolTip = String(localized: "shortcut.toggleCanvasLayout.label", defaultValue: "Toggle Canvas Layout")
            layoutModeControls[ObjectIdentifier(toolbar)] = segmented
            updateLayoutModeSelection()
            return item
        }

        return nil
    }

    // MARK: - Parsed pane toggle

    private enum ParsedPaneSegment: Int {
        case terminal = 0
        case parsed = 1
    }

    @objc private func parsedPaneSegmentChanged(_ sender: NSSegmentedControl) {
        guard let context = activeParsedPaneContext(for: sender.window) else {
            sender.selectedSegment = ParsedPaneSegment.terminal.rawValue
            refreshParsedPaneAccessories()
            return
        }
        let nextMode: ParsedPaneMode = sender.selectedSegment == ParsedPaneSegment.parsed.rawValue
            ? .parsed
            : .terminal
        context.panel.parsedPaneMode = nextMode
        refreshParsedPaneAccessories()
    }

    private func refreshParsedPaneAccessories() {
        for window in NSApp.windows {
            installParsedPaneAccessoryIfPossible(on: window)
        }

        for (key, accessory) in parsedPaneAccessories {
            guard let window = accessory.view.window else { continue }
            let parsedContext = activeParsedPaneContext(for: window)
            let shouldShow = parsedContext != nil
            accessory.isHidden = !shouldShow
            accessory.view.isHidden = !shouldShow
            accessory.view.alphaValue = shouldShow ? 1 : 0

            guard let control = parsedPaneControls[key] else { continue }
            let mode = parsedContext?.panel.parsedPaneMode ?? .terminal
            let selectedSegment = mode == .parsed
                ? ParsedPaneSegment.parsed.rawValue
                : ParsedPaneSegment.terminal.rawValue
            if control.selectedSegment != selectedSegment {
                control.selectedSegment = selectedSegment
            }
        }
    }

    private func installParsedPaneAccessoryIfPossible(on window: NSWindow) {
        guard AppDelegate.shared?.contextForMainWindow(window) != nil else { return }
        guard !WorkspacePresentationModeSettings.isMinimal() else { return }
        installParsedPaneAccessory(on: window)
    }

    private func activeParsedPaneContext(for window: NSWindow?) -> (workspace: Workspace, panel: TerminalPanel)? {
        guard !WorkspacePresentationModeSettings.isMinimal() else { return nil }
        let parsedViewEnabled = (UserDefaults.standard.object(forKey: ParsedViewSettings.enabledKey) as? Bool)
            ?? ParsedViewSettings.defaultEnabled
        guard parsedViewEnabled else {
            selectedTerminalPanel(for: window)?.parsedPaneMode = .terminal
            return nil
        }

        guard let workspace = resolvedTabManager(for: window)?.selectedWorkspace,
              let panelId = workspace.focusedPanelId,
              let terminalPanel = workspace.terminalPanel(for: panelId) else {
            return nil
        }

        guard isRealSession(workspace: workspace, panelId: panelId) else {
            terminalPanel.parsedPaneMode = .terminal
            return nil
        }

        return (workspace, terminalPanel)
    }

    private func selectedTerminalPanel(for window: NSWindow?) -> TerminalPanel? {
        resolvedTabManager(for: window)?.selectedTerminalPanel
    }

    private func resolvedTabManager(for window: NSWindow?) -> TabManager? {
        AppDelegate.shared?.activeTabManagerForCommands(preferredWindow: window) ?? tabManager
    }

    private func isRealSession(workspace: Workspace, panelId: UUID) -> Bool {
        if let binding = workspace.surfaceResumeBinding(panelId: panelId),
           binding.isProcessDetected || binding.isAgentHookBinding {
            return true
        }
        return workspace.forkableAgentSnapshot(forPanelId: panelId) != nil
    }

    // MARK: - Layout mode toggle

    private enum LayoutModeSegment: Int {
        case splits = 0
        case canvas = 1
    }

    @objc private func layoutModeSegmentChanged(_ sender: NSSegmentedControl) {
        guard let workspace = tabManager?.selectedWorkspace else { return }
        let target: WorkspaceLayoutMode = sender.selectedSegment == LayoutModeSegment.canvas.rawValue ? .canvas : .splits
        workspace.setLayoutMode(target)
    }

    private func updateLayoutModeSelection() {
        let mode = tabManager?.selectedWorkspace?.layoutMode ?? .splits
        let segment = mode == .canvas ? LayoutModeSegment.canvas.rawValue : LayoutModeSegment.splits.rawValue
        for control in layoutModeControls.values where control.selectedSegment != segment {
            control.selectedSegment = segment
        }
    }

}
