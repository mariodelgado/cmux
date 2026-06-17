import AppIntents

struct CmuxAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskLocalModelIntent(),
            phrases: [
                "Ask \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("appIntents.askLocalModel.shortTitle", defaultValue: "Ask Local Model"),
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: SummarizeRemoteSessionsIntent(),
            phrases: [
                "Summarize \(.applicationName) sessions",
            ],
            shortTitle: LocalizedStringResource("appIntents.summarizeRemoteSessions.shortTitle", defaultValue: "Summarize Sessions"),
            systemImageName: "rectangle.stack.badge.person.crop"
        )
        AppShortcut(
            intent: ExplainCommandIntent(),
            phrases: [
                "Explain command with \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("appIntents.explainCommand.shortTitle", defaultValue: "Explain Command"),
            systemImageName: "terminal"
        )
    }
}
