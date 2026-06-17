import AppIntents
import Foundation

struct SummarizeRemoteSessionsIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource(
        "appIntents.summarizeRemoteSessions.title",
        defaultValue: "Summarize Remote Sessions"
    )
    static var description = IntentDescription(LocalizedStringResource(
        "appIntents.summarizeRemoteSessions.description",
        defaultValue: "Summarize cmux sessions currently flagged by local AI triage."
    ))
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard AIFeatureSettings.isEnabled() else {
            return .result(value: String(localized: "appIntents.aiDisabled", defaultValue: "cmux AI is disabled."))
        }
        guard AIFeatureSettings.appIntentsEnabled() else {
            return .result(value: String(localized: "appIntents.appIntentsDisabled", defaultValue: "cmux AI App Intents are disabled."))
        }

        let summary = await MainActor.run {
            TerminalNotificationStore.shared.currentAITriageSummary()
        }
        return .result(value: summary)
    }
}
