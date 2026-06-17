import Foundation

extension Workspace {
    func terminalPanelForSidebarRollingOutputPreview() -> TerminalPanel? {
        if let focusedPanelId,
           let terminalPanel = terminalPanel(for: focusedPanelId) {
            return terminalPanel
        }

        if let focusedPaneId = bonsplitController.focusedPaneId,
           let selectedSurfaceId = bonsplitController.selectedTab(inPane: focusedPaneId)?.id,
           let selectedPanelId = panelIdFromSurfaceId(selectedSurfaceId),
           let terminalPanel = terminalPanel(for: selectedPanelId) {
            return terminalPanel
        }

        for panelId in sidebarOrderedPanelIds() {
            if let terminalPanel = terminalPanel(for: panelId) {
                return terminalPanel
            }
        }

        return panels.values
            .compactMap { $0 as? TerminalPanel }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .first
    }

    func updateSidebarRollingOutputPreview(
        text: String?,
        sourcePanelId: UUID?,
        now: Date
    ) {
        guard let text, let sourcePanelId else {
            if sidebarRollingOutputPreview != nil {
                sidebarRollingOutputPreview = nil
            }
            return
        }

        let previous = sidebarRollingOutputPreview
        let textChanged = previous?.text != text
        let revision = textChanged ? (previous?.revision ?? 0) &+ 1 : (previous?.revision ?? 0)
        let lastChangedAt = textChanged ? now : (previous?.lastChangedAt ?? now)
        let next = SidebarRollingOutputPreview(
            text: text,
            lastChangedAt: lastChangedAt,
            revision: revision,
            sourcePanelId: sourcePanelId
        )
        if previous != next {
            sidebarRollingOutputPreview = next
        }
    }
}
