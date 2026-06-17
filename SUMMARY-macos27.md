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
