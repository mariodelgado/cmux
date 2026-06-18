import CmuxProcess
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("OpenRouter inspector")
struct OpenRouterInspectorTests {
    @Test func snapshotDecodeToleratesMissingFields() throws {
        let snapshot = try OpenRouterInspectorSnapshot.decode(stdout: "{}", receivedAt: Date(timeIntervalSince1970: 10))

        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.openrouter.recent.isEmpty)
        #expect(snapshot.profiles.isEmpty)
        #expect(snapshot.models.isEmpty)
        #expect(snapshot.receivedAt == Date(timeIntervalSince1970: 10))
    }

    @Test func snapshotDecodeMapsRemotePayload() throws {
        let payload = """
        {
          "sessions": [
            {
              "session": "mario-ops",
              "window": "2",
              "profile": "glm-openrouter",
              "model": "z-ai/glm-5.2",
              "pid": 1234,
              "running": "true"
            }
          ],
          "openrouter": {
            "balance": "12.34",
            "usage": 7.66,
            "limit": 20,
            "recent": [
              {"model": "z-ai/glm-5.2", "cost": "0.012", "tokens": "3456", "ts": 1718000000000}
            ]
          },
          "profiles": [
            {"id": "claude-glm-openrouter", "label": "OpenRouter GLM 5.2 Only"}
          ],
          "models": ["anthropic/claude-sonnet-4.6", "z-ai/glm-5.2"]
        }
        """

        let snapshot = try OpenRouterInspectorSnapshot.decode(
            stdout: payload,
            receivedAt: Date(timeIntervalSince1970: 20)
        )

        #expect(snapshot.sessions.count == 1)
        #expect(snapshot.sessions[0].session == "mario-ops")
        #expect(snapshot.sessions[0].window == 2)
        #expect(snapshot.sessions[0].running)
        #expect(snapshot.openrouter.balance == 12.34)
        #expect(snapshot.openrouter.usage == 7.66)
        #expect(snapshot.openrouter.limit == 20)
        #expect(snapshot.openrouter.recent[0].tokens == 3456)
        #expect(snapshot.openrouter.recent[0].timestamp == Date(timeIntervalSince1970: 1_718_000_000))
        #expect(snapshot.profiles[0].label == "OpenRouter GLM 5.2 Only")
        #expect(snapshot.models == ["anthropic/claude-sonnet-4.6", "z-ai/glm-5.2"])
    }

    @Test func sshArgumentsMatchRemoteHelpersAndQuoteValues() {
        #expect(OpenRouterInspectorSSHService.inspectArguments(host: " mario.servarica ") == [
            "mario.servarica",
            "~/.tmux/cc-inspector.sh",
        ])

        #expect(OpenRouterInspectorSSHService.switchNowArguments(
            host: "mario.servarica",
            session: "mario's ops",
            window: 2,
            target: "z-ai/glm-5.2"
        ) == [
            "mario.servarica",
            "~/.tmux/cc-switch.sh 'mario'\"'\"'s ops' 2 restart 'z-ai/glm-5.2'",
        ])

        #expect(OpenRouterInspectorSSHService.defaultArguments(
            host: "mario.servarica",
            target: "claude-glm-openrouter"
        ) == [
            "mario.servarica",
            "~/.tmux/cc-switch.sh default 'claude-glm-openrouter'",
        ])
    }

    @Test func serviceInspectConsumesCommandRunnerOutput() async throws {
        let payload = #"{"sessions":[{"session":"mario-ops","window":2,"running":true}],"models":["z-ai/glm-5.2"]}"#
        let runner = FakeOpenRouterInspectorCommandRunner(result: CommandResult(
            stdout: payload,
            stderr: "",
            exitStatus: 0,
            timedOut: false,
            executionError: nil
        ))
        let service = OpenRouterInspectorSSHService(
            commandRunner: runner,
            minimumRefreshInterval: 0,
            inspectTimeout: 1,
            actionTimeout: 1
        )

        let snapshot = try await service.inspect(host: "mario.servarica", force: true)
        let calls = await runner.calls

        #expect(snapshot.sessions.map(\.displayName) == ["mario-ops:2"])
        #expect(snapshot.models == ["z-ai/glm-5.2"])
        #expect(calls.count == 1)
        #expect(calls[0].executable == "ssh")
        #expect(calls[0].arguments == ["mario.servarica", "~/.tmux/cc-inspector.sh"])
    }
}

private actor FakeOpenRouterInspectorCommandRunner: CommandRunning {
    struct Call: Equatable {
        let directory: String
        let executable: String
        let arguments: [String]
        let timeout: TimeInterval?
    }

    private let result: CommandResult
    private(set) var calls: [Call] = []

    init(result: CommandResult) {
        self.result = result
    }

    func run(
        directory: String,
        executable: String,
        arguments: [String],
        timeout: TimeInterval?
    ) async -> CommandResult {
        calls.append(Call(
            directory: directory,
            executable: executable,
            arguments: arguments,
            timeout: timeout
        ))
        return result
    }
}
