import Foundation

struct SidebarRollingOutputPreview: Equatable {
    let text: String
    let lastChangedAt: Date
    let revision: UInt64
    let sourcePanelId: UUID
}
