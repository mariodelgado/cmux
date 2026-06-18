# macOS 27 Toolchain Build Summary

Date: 2026-06-16

Branch: `modernize/macos27`

Toolchain used:
- Xcode 26.1.1, build 17B100
- Swift 6.2.1
- macOS 26.1 SDK
- Zig 0.15.x for Ghostty builds via `/opt/homebrew/opt/zig@0.15/bin/zig`
- Bun 1.3.11

## What changed

- Built GhosttyKit from the `ghostty` submodule with:
  `zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast`
- Ran `bun install` at the repo root.
- Updated `scripts/build-ghostty-cli-helper.sh` so Xcode build phases prefer Homebrew's keg-only `zig@0.15` before a globally linked newer Zig.
- Removed macOS SDK deprecations from the app target:
  - Replaced SwiftUI one-argument `onChange(of:)` closures with the current two-argument form.
  - Replaced `NSWorkspace.fullPath(forApplication:)` lookup with bundle-identifier based `urlForApplication(withBundleIdentifier:)`.
  - Replaced `NSWorkspace.icon(forFileType:)` with `UTType` based icon lookup.
  - Removed deprecated `.activateIgnoringOtherApps` activation options.
  - Removed deprecated `CGWindowListCreateImage` screenshot fallback from the synchronous control path.
- Fixed Swift 6.2 forward-compatibility warnings that were local and low risk:
  - Added explicit `any Panel`.
  - Avoided the main-actor default argument reference in browser import plan realization.
  - Moved synchronous session JSONL filesystem enumeration out of the async context.
  - Marked the `WKWebView` marker conformance as retroactive.
  - Removed an unnecessary Ghostty callback `unsafeBitCast`.
  - Marked intentionally ignored `closePanel` return values.

No Swift package tools versions, macOS platform declarations, deployment targets, or submodule platform values were downgraded.

## Build results

GhosttyKit build: succeeded after selecting Zig 0.15 and installing the Xcode Metal toolchain component.

Requested Debug app build:

```bash
xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/cmux-codex build
```

Result: `BUILD SUCCEEDED`

Log: `/tmp/cmux-macos27-exact.log`

The exact build log contains no SDK deprecation warnings and no `will be an error in the Swift 6 language mode` warnings. It only reports the existing script-phase warning for a run script with no output files.

Tagged local dev build:

```bash
./scripts/reload.sh --tag macos27-codex
```

Result: succeeded in 153s.

App path:

`/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`

## Remaining issues

- On the first cold package graph resolution, plain `xcodebuild` stalled in Xcode's keychain package authorization path. `-packageAuthorizationProvider netrc` got the graph resolved, and the exact requested command succeeded afterward from the warm package/artifact cache.
- The clean build log still includes pre-existing nonblocking warnings in large actor/sendability areas such as `AppDelegate.swift` and `TerminalNotificationStore.swift`, plus an async WebKit suggestion in `ReactGrab.swift`, AppIcon unassigned-child warnings, AppIntents metadata skipped, and the existing run-script output warning. These are not SDK deprecation warnings and did not block the Debug app build.

## UI changes

- Left panel Liquid Glass: the vertical-tabs sidebar now uses the existing `SidebarVisualEffectBackground` wrapper with `preferLiquidGlass: true`, selecting `NSGlassEffectView` on macOS 26+ and retaining the wrapper fallback path on older systems.
- Default font: cmux now injects `font-family = SFMono Nerd Font` into the built-in Ghostty config only when the user has not set `font-family`, and monospaced sidebar/panel UI font choices use `SFMono Nerd Font` with a system mono fallback.
- Right panel Catppuccin Mocha: the right-hand sidebar keeps its existing structure while applying Catppuccin Mocha base/mantle backgrounds, surface dividers/cards, text/subtext labels, and mauve/blue accents.

Touched files:
- `SUMMARY-macos27.md`
- `Sources/AppDelegate+CmuxSSHURL.swift`
- `Sources/BonsplitTabBarDebug.swift`
- `Sources/ContentView.swift`
- `Sources/DockEmptyView.swift`
- `Sources/DockPanelView.swift`
- `Sources/Feed/FeedPanelView.swift`
- `Sources/FileExplorerStore.swift`
- `Sources/FileExplorerView.swift`
- `Sources/GhosttyTerminalView.swift`
- `Sources/Mobile/Pairing/MobilePairingView.swift`
- `Sources/Panels/FilePreviewPanel.swift`
- `Sources/Panels/FilePreviewTextEditor.swift`
- `Sources/Panels/MarkdownPanelView.swift`
- `Sources/Panels/PDFPreviewChromeDebugWindowController.swift`
- `Sources/Panels/PanelContentView.swift`
- `Sources/Panels/ProjectBuildSettingsTabView.swift`
- `Sources/Panels/ProjectFilesTabView.swift`
- `Sources/Panels/ProjectSchemesTabView.swift`
- `Sources/Panels/ProjectTargetsTabView.swift`
- `Sources/Panels/TerminalPanelView.swift`
- `Sources/RightSidebarChromeStyle.swift`
- `Sources/RightSidebarPanelView.swift`
- `Sources/Search/MenubarSearchPopover.swift`
- `Sources/SessionIndexView.swift`
- `Sources/SessionTranscriptTypes.swift`
- `Sources/Settings/ConfigSettingsView.swift`
- `Sources/Sidebar/SidebarDirectoryText.swift`
- `Sources/TaskManagerView.swift`
- `Sources/TextBoxInput.swift`
- `Sources/TitlebarLayoutDebugWindow.swift`
- `Sources/cmuxApp.swift`

Final build result:
- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED` (log: `/tmp/cmux-ui-build.log`).
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 23s (log: `/tmp/cmux-reload-macos27-codex.log`; app: `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).

## Liquid Glass fix

The earlier left panel note was wrong: `SidebarVisualEffectBackground` was
creating a bare `NSGlassEffectView` with no content view or public SwiftUI
Liquid Glass configuration, then only poking a private tint selector. That path
could render as a flat surface instead of genuine Liquid Glass.

The left vertical-tabs sidebar now uses the native SwiftUI Liquid Glass API on
macOS 26+: `.glassEffect(.regular.tint(...), in: RoundedRectangle(...))`, with
the tint capped to a faint alpha and no opaque fill behind or over the glass.
The window root backdrop also leaves the left sidebar strip clear and uses
transparent window hosting when native glass is available, so the sidebar has
real backing content to refract instead of sampling an opaque app fill. Older
macOS versions fall back to `NSVisualEffectView` using sidebar material.

Latest verification after this fix:
- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED`.
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 66s (log: `/tmp/cmux-reload-macos27-codex.log`; app: `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).
- Computer Use screenshot of the tagged app showed the left sidebar strip on the transparent backing rather than the previous opaque dark root fill.

## Right panel macOS 27 styling

The right sidebar remains fully opaque Catppuccin Mocha rather than Liquid Glass. Its backdrop now uses an opaque mantle/base fill with no window backdrop layer underneath, and the right-panel content adopts a Tahoe-style inset grouped treatment: rounded surface0 cards, low-opacity surface1 hairlines, more comfortable row metrics, uppercase secondary section headers, and rounded mauve/blue hover and selection highlights. The file explorer, Vault/session sections, Feed rows, Dock controls, titlebar pills, and right-panel hairline dividers now share the same continuous-corner Catppuccin chrome while leaving the left sidebar Liquid Glass path and the SFMono Nerd Font default unchanged.

## Rolling tab preview

Background workspace rows in the left vertical-tabs sidebar now show a one-line rolling terminal output preview directly under the workspace title. The active workspace intentionally shows no preview line. The preview uses `SFMono Nerd Font`, Catppuccin Mocha `subtext0`/`overlay0` colors, a short system `.smooth` content transition for updates, and an idle dim state after 9 seconds. Reduce Motion disables scale pulse motion, while Differentiate Without Color and Reduce Transparency add weight/opacity contrast instead of relying only on color.

Touched files:
- `Packages/CmuxTerminal/Sources/CmuxTerminal/Surface/TerminalSurface+Input.swift`
- `Sources/ContentView.swift`
- `Sources/Sidebar/SidebarRollingOutputPreview.swift`
- `Sources/Sidebar/SidebarRollingOutputPreviewFormatter.swift`
- `Sources/Sidebar/SidebarRollingOutputPreviewLine.swift`
- `Sources/Sidebar/SidebarRollingOutputPreviewSampler.swift`
- `Sources/Sidebar/SidebarWorkspaceSnapshotRefreshPolicy.swift`
- `Sources/Workspace+SidebarRollingOutputPreview.swift`
- `Sources/Workspace.swift`
- `Sources/WorkspaceSidebarObservation.swift`
- `cmux.xcodeproj/project.pbxproj`

Sampling approach:
- The sampler reuses the existing Ghostty tick notification demand path via `GhosttyApp.retainTickNotifications()` and coalesces samples to roughly 3.5 Hz with a 280 ms deadline.
- Sampling is outside terminal render hot paths: `TerminalSurface.forceRefresh()` is untouched, and the sampler only reads from background workspaces. The focused workspace is skipped entirely.
- The terminal package exposes `TerminalSurface.screenText()` for the screen tail, with `visibleText()` as a fallback. The formatter strips ANSI/OSC/control noise, normalizes whitespace, picks the last non-empty row, trims trailing whitespace, and caps stored text length.
- Preview state lives on `Workspace.sidebarRollingOutputPreview`; the existing sidebar observation/snapshot refresh path carries it into `TabItemView`, and the context-menu snapshot freeze policy preserves the existing preview while a menu is open.

Final verification:
- `scripts/normalize-pbxproj.py`: succeeded.
- `scripts/check-pbxproj.sh`: succeeded.
- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED`.
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 62s (log: `/tmp/cmux-reload-macos27-codex.log`; app: `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).

## AI features (local MLX hub)

cmux now has an opt-in-by-default local AI foundation for the MLX-compatible
hub at `http://127.0.0.1:8765/v1`. Configuration is exposed through the
settings catalog, `cmux.json`, Settings search, the config template, the web
schema, and docs as:

- `ai.enabled` defaulting to `true`
- `ai.endpoint` defaulting to `http://127.0.0.1:8765/v1`

Files added or materially touched:
- `Sources/AI/MLXHubClient.swift`
- `Sources/Sidebar/SidebarAIInsightCoordinator.swift`
- `Sources/Sidebar/SidebarRollingOutputPreviewFormatter.swift`
- `Sources/Sidebar/SidebarRollingOutputPreviewSampler.swift`
- `Sources/TerminalNotificationStore.swift`
- `Packages/CmuxSettings/Sources/CmuxSettings/Keys/AICatalogSection.swift`
- `Packages/CmuxSettings/Sources/CmuxSettings/Keys/SettingCatalog.swift`
- `Sources/CmuxSettingsJSONPathSupport.swift`
- `Sources/KeyboardShortcutSettingsFileStore.swift`
- `Sources/KeyboardShortcutSettingsFileStore+Template.swift`
- `Packages/CmuxSettingsUI/Sources/CmuxSettingsUI/Sections/AutomationSection.swift`
- `Sources/SettingsNavigation.swift`
- `Sources/SettingsSearchAliases.swift`
- `Resources/Localizable.xcstrings`
- `docs/configuration.md`
- `web/data/cmux.schema.json`
- `web/messages/en.json`
- `web/messages/ja.json`
- `cmux.xcodeproj/project.pbxproj`

Client and queue design:
- `MLXHubClient` uses `URLSession` with async/await, a roughly 10 second
  timeout, and a configurable OpenAI-compatible base URL.
- The client exposes `summarize(text:) async -> String?` and
  `classify(text:) async -> AIPaneStatus?`.
- All client instances share one process-wide actor-backed request queue, so
  rolling previews and triage do not overlap hub calls.
- Endpoint failures mark a short cooldown and return `nil`, so all AI features
  silently fall back when the hub is disabled, unreachable, slow, or returning
  invalid output.

Rolling preview throttling:
- The sampler still skips the focused workspace and only reads background
  terminal panels.
- Recent pane text is sampled outside render and typing hot paths, with
  `TerminalSurface.forceRefresh()`, `TabItemView` body, and
  `WindowTerminalHostView.hitTest()` left untouched.
- `SidebarAIInsightCoordinator` fingerprints recent output, caches summaries
  per workspace/panel, avoids duplicate pending requests, and enforces a
  roughly 9 second minimum request interval per pane.
- The coordinator prioritizes the most recently active background workspace and
  drops stale completions when newer pane output arrives. It falls back to the
  existing raw rolling-preview line while a summary is pending, while the hub is
  cooling down, or when AI is disabled.

Agent triage:
- The same coordinator classifies sampled background pane output into
  `working`, `needs_attention`, `done`, or `errored`.
- `needs_attention` and `errored` are routed through the existing
  `TerminalNotificationStore` unread/flash path so the sidebar's current
  attention indicators light up without a parallel notification UI.
- `done` records a read, non-flashing notification as a subtle completed state;
  `working` clears the AI-owned notification for that pane.

Final verification:
- `scripts/check-pbxproj.sh`: succeeded.
- `jq empty web/data/cmux.schema.json web/messages/en.json web/messages/ja.json Resources/Localizable.xcstrings`: succeeded.
- Bare-English scan over the touched Swift UI/runtime files found no new
  unlocalized `Text`, `Button`, `SettingsCardNote`, or inline `SettingsCardRow`
  strings.
- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED`.
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 40s (log:
  `/tmp/cmux-reload-macos27-codex.log`; app:
  `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).

## Deep macOS integrations (Foundation Models, App Intents, Services, menu-bar)

cmux now has an in-binary Apple Foundation Models backend for macOS 26+ plus a
tiered local AI router:

- `Sources/AI/FoundationModelsBackend.swift` imports `FoundationModels`, checks
  `SystemLanguageModel.default.availability`, creates `LanguageModelSession`
  only when the model is available, and degrades to `nil`/fallback behavior
  when Foundation Models cannot serve the request.
- `Sources/AI/AIRouter.swift` routes light frequent work such as rolling preview
  summaries, triage classification, and quick command explanations to
  Foundation Models first, then falls back to MLX hub. Heavy work routes to the
  existing MLX-compatible hub at `http://127.0.0.1:8765/v1`, then falls back to
  Foundation Models.
- Rolling previews and agent triage now call the shared router on the light
  tier while preserving the existing request queue, throttling, output
  fingerprinting, cooldowns, and background-pane-only sampling. Terminal typing
  hot paths remain untouched.

Native macOS entrypoints added:

- App Intents in `Sources/Intents/` expose "Ask Local Model", "Summarize Remote
  Sessions", and "Explain Command" to Shortcuts, Siri, and Spotlight, using the
  same tiered AI router and async request path.
- macOS Services are registered in `Resources/Info.plist` for "Explain with
  cmux AI" and "Rewrite with cmux AI". The AppDelegate services provider reads
  selected text from the pasteboard, sends it through the light AI tier, and
  writes the result back to the service pasteboard and general pasteboard.
- The menu-bar extra now shows AI triage status for flagged background panes,
  provides a quick local-model prompt field, copies answers to the pasteboard,
  and can focus the latest flagged pane through the existing notification
  action path.

Configuration and localization:

- Settings and `cmux.json` now include `ai.enabled`, `ai.endpoint`,
  `ai.appIntents`, `ai.services`, and `ai.menuBar`. The menu-bar setting
  defaults on, matching the macOS integration behavior.
- User-facing strings were added to `Resources/Localizable.xcstrings` with
  English and Japanese values. Services titles were added to
  `Resources/InfoPlist.xcstrings`. Schema descriptions were added to
  `web/messages/en.json` and `web/messages/ja.json`.
- No new cmux-owned keyboard shortcuts were added, so `KeyboardShortcutSettings`
  did not need shortcut entries.

Feature commits:

- `7d4c50948 Add native Foundation Models backend`
- `45c94257c Route local AI across Foundation Models and MLX`
- `2e711067a Add local AI App Intents`
- `bb5660e35 Add local AI macOS Services`
- `76fbd4996 Add local AI menu bar status`

## Parsed view toggle

Terminal panes now have a per-pane top-center `Terminal | Parsed` segmented
control in pane chrome. The raw Ghostty surface remains mounted and unchanged;
Parsed mode overlays a native SwiftUI renderer and switches back instantly.

Detector and renderer registry:

- `ParsedRenderer` defines confidence scoring, snapshot generation, and native
  SwiftUI view construction. `ParsedRendererRegistry` registers agent transcript,
  diff, test output, JSON/JSONL, structured logs, file listings, tabular text,
  and rich reader fallback renderers.
- `ParsedViewDetector` picks the highest-confidence renderer above threshold and
  falls back to the rich reader. Agent panes use the existing
  `ClaudeTranscriptParser` from `Packages/CmuxAgentChat` and render assistant
  markdown, reasoning blocks, tool cards, TodoWrite checklists, permission
  prompts, questions, and generic unknown-tool cards.

Data path and throttling:

- Parsed mode samples each visible pane through `TerminalSurface.surfaceText()`
  with `activeText()` and screen fallbacks, matching the terminal surface
  snapshot path instead of polling from SwiftUI rendering.
- Sampling is active only while the pane is visible, Parsed mode is selected,
  and `parsedView.enabled` is true. Ghostty ticks schedule a debounced parse at
  roughly 0.28 seconds minimum spacing, capped to recent scrollback text.
- ANSI/OSC/Kitty control data is sanitized before parsing; OSC8 links and Kitty
  graphics chunks are preserved for reader rendering. Heavy detection runs off
  the main actor and publishes immutable render snapshots back to the per-pane
  view model.

Configuration and safety:

- `parsedView.enabled` defaults to true and is exposed in Settings, the cmux.json
  parser/template path, web schema docs, and English/Japanese message catalogs.
- The toggle and parsed overlay are wired through `TerminalPanelView` and
  `TerminalPanel` state. The typing-latency hot paths called out in `CLAUDE.md`
  (`TerminalSurface.forceRefresh`, `TabItemView`, and
  `WindowTerminalHostView.hitTest`) were not changed.
- Parsed lists render from value snapshots plus closures, preserving the
  snapshot-boundary rule and avoiding state mutation from view-body projection.

Final verification:

- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED`.
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 165s (log:
  `/tmp/cmux-reload-macos27-codex.log`; app:
  `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).
- `scripts/check-pbxproj.sh`: succeeded.
- `scripts/lint-pbxproj-test-wiring.sh`: succeeded.
- `jq empty web/data/cmux.schema.json web/messages/en.json web/messages/ja.json Resources/Localizable.xcstrings`: succeeded.
- Localization audit: localized Swift keys used by the Parsed pane and Settings
  row exist in `Resources/Localizable.xcstrings` with English and Japanese
  values; web schema descriptions exist in `web/messages/en.json` and
  `web/messages/ja.json`; the touched Swift UI files were scanned for new bare
  `Text`, `Button`, `Label`, `Picker`, `Toggle`, `SettingsCardRow`, help, and
  accessibility strings.
- Targeted detector tests are wired into `cmuxTests`, but `xcodebuild test`
  through `cmux-unit` currently stops on an existing
  `SidebarWorkspaceSnapshotRefreshPolicyTests` compile error for a missing
  `rollingOutputPreview` argument before `ParsedViewDetectorTests` can run.

## Parsed pane titlebar fix

The earlier pane-chrome `Terminal | Parsed` control has been removed from
`TerminalPanelView`. The parsed-pane mode control now lives in the window title
bar as a centered `NSTitlebarAccessoryViewController`, managed by
`WindowToolbarController`, using the same small textured segmented-control
style as the titlebar layout-mode control.

Visibility is now scoped to the active terminal pane. The titlebar control is
hidden unless Parsed View is enabled and the focused terminal pane is backed by
a real session signal: a detected running process, an agent-hook binding, or an
agent-session snapshot. Empty/plain shells and non-terminal panes keep the
control hidden and force the pane back to terminal mode.

The broken Parsed mode swap was fixed by replacing the SwiftUI overlay with an
actual `TerminalPanelView` content swap. Parsed mode now unmounts the raw
`GhosttyTerminalView` and shows `ParsedPaneView`, while Terminal mode restores
the raw Ghostty surface. Sampling remains active only while the pane is visible,
Parsed mode is selected, and Parsed View is enabled. Empty sampled scrollback
now clears stale snapshots and shows a localized empty state instead of leaving
the parsed view blank or indefinitely loading.

Touched files:
- `Sources/AppDelegate.swift`
- `Sources/WindowToolbarController.swift`
- `Sources/Panels/TerminalPanelView.swift`
- `Sources/ParsedPane/ParsedPaneView.swift`
- `Sources/ParsedPane/ParsedPaneViewModel.swift`
- `Resources/Localizable.xcstrings`
- `SUMMARY-macos27.md`

Verification:
- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED`.
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 81s (log:
  `/tmp/cmux-reload-macos27-codex.log`; app:
  `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).
- `scripts/check-pbxproj.sh`: succeeded.
- `scripts/lint-pbxproj-test-wiring.sh`: succeeded.
- `jq empty Resources/Localizable.xcstrings`: succeeded.
- `git diff --check`: succeeded.
- Localization audit: new `parsedView.empty` copy and reused
  `parsedView.toggle.*` titlebar strings have English and Japanese entries in
  `Resources/Localizable.xcstrings`; touched Swift files were scanned for new
  bare user-facing `Text`, `Button`, `Label`, `Picker`, `Toggle`, segmented
  label, tooltip, and accessibility-label strings.

## OpenRouter inspector

Added a right-sidebar Inspector mode for remote Claude Code sessions running
through OpenRouter. The inspector polls the configured SSH host only while the
right panel is visible, runs the existing `~/.tmux/cc-inspector.sh` helper, and
decodes the JSON payload into tolerant Codable snapshots. Model switching uses
the existing `~/.tmux/cc-switch.sh` remote helper for both restart-and-resume
session switches and default model/profile updates.

The UI uses the existing Catppuccin Mocha right-panel chrome and shows an
OpenRouter balance/usage/limit meter, recent spend rate, detected
`session:window` rows with running state/profile/model, recent generations, and
per-session model/profile menus. SSH execution and JSON parsing live behind a
single actor-backed service with queueing and throttle behavior; the SwiftUI
store receives results from explicit reload/action completions, and row views
receive value snapshots plus closure actions only.

Configuration and safety:

- `inspector.enabled` defaults to true and controls right-sidebar Inspector
  availability.
- `inspector.host` defaults to `mario.servarica` and is used as the SSH
  destination for both inspection and switch actions.
- Both settings are wired through `cmux.json` template/path support, the web
  schema, and the Automation settings section.
- The typing-latency hot paths called out in `CLAUDE.md`
  (`TerminalSurface.forceRefresh`, `TabItemView`, and
  `WindowTerminalHostView.hitTest`) were not changed.

Touched files:
- `Sources/OpenRouterInspectorModels.swift`
- `Sources/OpenRouterInspectorSSHService.swift`
- `Sources/OpenRouterInspectorStore.swift`
- `Sources/OpenRouterInspectorView.swift`
- `Sources/RightSidebarPanelView.swift`
- `Sources/RightSidebarMode+Availability.swift`
- `Sources/RightSidebarRemoteCommand.swift`
- `Sources/ContentView+RightSidebarCommandPalette.swift`
- `Sources/KeyboardShortcutSettingsFileStore+Template.swift`
- `Sources/CmuxSettingsJSONPathSupport.swift`
- `Sources/MainWindowFocusController.swift`
- `Sources/RightSidebarToolPanel.swift`
- `Packages/CmuxSettings/Sources/CmuxSettings/Keys/InspectorCatalogSection.swift`
- `Packages/CmuxSettings/Sources/CmuxSettings/Keys/SettingCatalog.swift`
- `Packages/CmuxSettingsUI/Sources/CmuxSettingsUI/Sections/AutomationSection.swift`
- `Resources/Localizable.xcstrings`
- `web/data/cmux.schema.json`
- `cmuxTests/OpenRouterInspectorTests.swift`
- `cmuxTests/FileExplorerStateModePersistenceTests.swift`
- `cmuxTests/RightSidebarCommandPaletteTests.swift`
- `cmuxTests/RightSidebarRemoteCommandTests.swift`
- `cmuxTests/ParsedViewDetectorTests.swift`
- `cmuxTests/SidebarWorkspaceSnapshotRefreshPolicyTests.swift`
- `cmux.xcodeproj/project.pbxproj`
- `SUMMARY-macos27.md`

Verification:
- `xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination platform=macOS -derivedDataPath /tmp/cmux-codex build`: `BUILD SUCCEEDED`.
- `./scripts/reload.sh --tag macos27-codex`: succeeded in 219s (log:
  `/tmp/cmux-reload-macos27-codex.log`; app:
  `/Users/marioelysian/Library/Developer/Xcode/DerivedData/cmux-macos27-codex/Build/Products/Debug/cmux DEV macos27-codex.app`).
- `scripts/check-pbxproj.sh`: succeeded.
- `scripts/lint-pbxproj-test-wiring.sh`: succeeded.
- `python3 -m json.tool Resources/Localizable.xcstrings`: succeeded.
- `python3 -m json.tool web/data/cmux.schema.json`: succeeded.
- Localization audit: new OpenRouter inspector right-sidebar strings, Settings
  rows, command usage text, action/error messages, and accessibility/help text
  have English and Japanese entries in `Resources/Localizable.xcstrings`; the
  touched Swift UI files were scanned for newly introduced bare user-facing
  `Text`, `Button`, `Label`, `Toggle`, `SettingsCardRow`, help, and
  accessibility strings.
- `xcodebuild test -project cmux.xcodeproj -scheme cmux-unit -destination platform=macOS -derivedDataPath /tmp/cmux-codex -only-testing:cmuxTests/OpenRouterInspectorTests`:
  the new inspector tests compiled, but the test run was interrupted after the
  host app hit an existing AppKit `NSTitlebarViewController` assertion in
  `WindowToolbarController.installParsedPaneAccessory`. Two stale test-target
  compile blockers were repaired first:
  `SidebarWorkspaceSnapshotRefreshPolicyTests` now passes
  `rollingOutputPreview: nil`, and `ParsedViewDetectorTests` now qualifies
  static helper calls with `Self`.
