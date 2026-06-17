import AppIntents
import Foundation

struct ExplainCommandIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource(
        "appIntents.explainCommand.title",
        defaultValue: "Explain Command"
    )
    static var description = IntentDescription(LocalizedStringResource(
        "appIntents.explainCommand.description",
        defaultValue: "Explain a shell command with cmux local AI."
    ))
    static var openAppWhenRun = false

    @Parameter(title: LocalizedStringResource("appIntents.command", defaultValue: "Command"))
    var command: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard AIFeatureSettings.isEnabled() else {
            return .result(value: String(localized: "appIntents.aiDisabled", defaultValue: "cmux AI is disabled."))
        }
        guard AIFeatureSettings.appIntentsEnabled() else {
            return .result(value: String(localized: "appIntents.appIntentsDisabled", defaultValue: "cmux AI App Intents are disabled."))
        }

        let explanation = await AIRouter.shared.explain(command: command)
        return .result(value: explanation ?? String(localized: "appIntents.noAnswer", defaultValue: "No local AI answer is available."))
    }
}
