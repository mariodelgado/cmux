import AppKit
import Foundation

extension AppDelegate {
    @objc func explainWithCmuxAI(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        runAITextService(.explain, pasteboard: pasteboard, error: error)
    }

    @objc func rewriteWithCmuxAI(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        runAITextService(.rewrite, pasteboard: pasteboard, error: error)
    }

    private enum AITextServiceMode: Sendable {
        case explain
        case rewrite

        var maximumResponseTokens: Int {
            switch self {
            case .explain:
                return 260
            case .rewrite:
                return 360
            }
        }

        var systemPrompt: String {
            switch self {
            case .explain:
                return """
                Explain the selected text clearly and concisely for a developer. If it looks like a shell command, call out destructive behavior, filesystem writes, networking, credentials, and process effects when relevant.
                """
            case .rewrite:
                return """
                Rewrite the selected text to be clearer, concise, and natural. Preserve the original meaning, do not add unsupported facts, and return only the rewritten text.
                """
            }
        }
    }

    private func runAITextService(
        _ mode: AITextServiceMode,
        pasteboard: NSPasteboard,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard AIFeatureSettings.isEnabled() else {
            error.pointee = String(localized: "services.aiDisabled", defaultValue: "cmux AI is disabled.") as NSString
            return
        }
        guard AIFeatureSettings.servicesEnabled() else {
            error.pointee = String(
                localized: "services.servicesDisabled",
                defaultValue: "cmux AI Services are disabled."
            ) as NSString
            return
        }
        guard let selectedText = aiServiceText(from: pasteboard) else {
            error.pointee = String(
                localized: "services.noText",
                defaultValue: "Select text to send to cmux AI."
            ) as NSString
            return
        }

        Task(priority: .userInitiated) { [mode, pasteboard, selectedText] in
            let answer = await AIRouter.shared.complete(
                task: .light(maximumResponseTokens: mode.maximumResponseTokens),
                system: mode.systemPrompt,
                user: selectedText
            )
            guard let output = answer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return }
            writeAIServiceResult(output, to: pasteboard)
        }
    }

    private func aiServiceText(from pasteboard: NSPasteboard) -> String? {
        let pasteboardStringType = NSPasteboard.PasteboardType("NSStringPboardType")
        let raw = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: pasteboardStringType)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func writeAIServiceResult(_ output: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}
