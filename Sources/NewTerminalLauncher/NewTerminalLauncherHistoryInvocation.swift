import Foundation

struct NewTerminalLauncherHistoryInvocation: Equatable, Sendable {
    let destination: String
    let lastUsedAt: Date?
    let sequence: Int
}
