import AppIntents
import Foundation

struct AskLocalModelIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource(
        "appIntents.askLocalModel.title",
        defaultValue: "Ask Local Model"
    )
    static var description = IntentDescription(LocalizedStringResource(
        "appIntents.askLocalModel.description",
        defaultValue: "Ask cmux local AI a question."
    ))
    static var openAppWhenRun = false

    @Parameter(title: LocalizedStringResource("appIntents.prompt", defaultValue: "Prompt"))
    var prompt: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard AIFeatureSettings.isEnabled() else {
            return .result(value: String(localized: "appIntents.aiDisabled", defaultValue: "cmux AI is disabled."))
        }
        guard AIFeatureSettings.appIntentsEnabled() else {
            return .result(value: String(localized: "appIntents.appIntentsDisabled", defaultValue: "cmux AI App Intents are disabled."))
        }

        let system = """
        Answer the user's question clearly and concisely. Prefer local, developer-focused explanations. If the request needs current external information, say that local context is insufficient.
        """
        let answer = await AIRouter.shared.complete(
            task: .heavy(maximumResponseTokens: 700),
            system: system,
            user: prompt
        )
        return .result(value: answer ?? String(localized: "appIntents.noAnswer", defaultValue: "No local AI answer is available."))
    }
}
