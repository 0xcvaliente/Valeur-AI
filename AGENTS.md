# valeurayAI Agent Notes

## Commands
- Full app work uses the Xcode project `valeuray.xcodeproj` and scheme `Valeur AI`. Quote target and scheme names in shell commands because they contain spaces.
- Fast local loop: `./script/build_and_run.sh` builds Debug into `.build/xcode-derived-data` and relaunches the app. Modes: `run` (default), `--debug`, `--logs`, `--telemetry`, `--verify`.
- Full verification: `xcodebuild -project "valeuray.xcodeproj" -scheme "Valeur AI" -destination "platform=macOS" test`
- Focused Xcode verification: add `-only-testing:"Valeur AITests"` or `-only-testing:"Valeur AIUITests"`.
- `swift test` only runs `Tests/ValeurAITestsSPM`; it does not run `Valeur AITests` or `Valeur AIUITests` from the Xcode project.

## Structure
- This is a single-module macOS app with a flat `Sources/` directory. Search by symbol, not by folder hierarchy.
- `Sources/ValeurAIApp.swift` is the real app entrypoint. It builds the SwiftData container, `SettingsStore`, `LLMServiceFactory`, and shared `AppState`.
- `Sources/RootView.swift` owns first-run Terms gating, UI-test launch routing, and lazy creation of both `ChatViewModel` and `WorkspaceViewModel`.
- `Sources/AppState.swift` contains both `AppState` and the large `ChatViewModel`.
- `Sources/WorkspaceRepository.swift` contains workspace persistence plus `WorkspaceViewModel` and the workspace AI revision/import-export helpers.

## Testing Quirks
- Do not weaken the UI-test gate in `Sources/UITestLaunchConfiguration.swift` and `Sources/ValeurAIApp.swift`. Destructive UI-test behavior only activates when `--ui-testing` is present and XCTest runner env vars exist; `UI_TESTING=1` alone is intentionally insufficient.
- UI tests steer startup via `UI_TEST_SCREEN`, `UI_TEST_SETTINGS_CATEGORY`, and launch args like `--ui-testing-reset-defaults`. Changes to launch flow, Terms, or Settings should be checked against `Valeur AIUITests`.
- Module names differ by harness: SwiftPM tests import `ValeurAI`, while Xcode tests import `Valeur_AI`.

## Release
- Local DMG: `./script/release_dmg.sh --local`
- Developer ID DMG: `./script/release_dmg.sh --team-id ABCDE12345 [--notary-profile PROFILE]`
- Release artifacts are written under `dist/release/<timestamp>/`. The script depends on `Distribution/ExportOptions-DeveloperID.plist.template`.

## Missing Repo Automation
- No repo-local CI workflow, lint config, formatter config, pre-commit config, or `opencode.json` is checked in. Do not invent `swiftlint`/`swiftformat`/CI steps that are not present.


<claude-mem-context>
# Memory Context

# [valeurayAI] recent context, 2026-05-08 5:18pm GMT+2

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (15,727t read) | 583,733t work | 97% savings

### Apr 21, 2026
26 12:30a 🔵 UI Tests Fail on Clean HEAD — Regression Pre-dates Current Branch
27 12:36a 🔴 SwiftUI "Publishing changes from within view updates" runtime warning
28 12:40a 🔵 WorkspaceTextFormatController — text formatting controller for NSTextView
29 " 🔴 Fixed formatting toolbar losing firstResponder after bold/italic/underline/fontSize actions
30 12:43a 🔵 Workspace Text Input: Font Size and Select-All Broken
31 12:44a 🔵 WorkspaceView.swift: Font Size Adjustment Logic Found
32 12:47a 🔵 Workspace Input Text Field Broken
33 12:48a 🔵 AppTheme Font Scaling via `scaled()` Static Function
34 " 🔵 `currentFontSize` Reads UserDefaults on Every Font Call
### Apr 23, 2026
39 10:27p 🔵 valeurayAI macOS App — ChatWindowView & Sidebar Architecture
40 " 🟣 WorkspaceView Gets Hover-Reveal Sidebar — Mirrors Chat Sidebar Pattern
41 10:28p 🟣 Workspace Sidebar Hover-Reveal — Full Implementation Complete
42 10:34p 🔄 Add onToggleSidebarPin callback to WorkspaceView initializer
43 10:35p 🔄 Workspace Sidebar Toggle Toolbar Moved Into WorkspaceView
44 10:40p 🔄 ChatWindowView Toolbar Attachment Moved to splitView Branch
### May 2, 2026
47 10:22p 🔵 ChatWindowView Toolbar Structure — Workspace Mode Has No Toolbar Items
48 10:23p 🔵 Title Bar Button Consistency Fix — Task Initiated
49 10:25p ✅ WorkspaceView toolbar style changed from unifiedCompact to unified
50 10:30p ⚖️ Workspace Sidebar Toggle Button — Move to Right Side
51 10:31p 🔵 WorkspaceView Toolbar Button Placements — Current State
52 10:32p 🟣 ToolbarFlexibleSpaceSynchronizer — NSToolbar Flexible Space Injector
53 " 🔴 WorkspaceView Toolbar — Sidebar Toggle Buttons Pushed to Right Side
54 10:35p 🔴 WorkspaceView Toolbar — Sidebar Toggle and New Workspace Moved to .primaryAction
55 " ✅ ToolbarFlexibleSpaceSynchronizer leadingItemCount Tuned from 2 to 0
56 10:37p ✅ WorkspaceView Sidebar Background Changed from sidebarGrey to backgroundPrimary
57 10:39p 🔴 WorkspaceView Sidebar List — Transparent Row Backgrounds and Custom List Background
58 10:42p 🟣 ValeurAIApp Window — Default Size and Minimum Size Constraints Added
59 " ✅ AppDelegate — NSWindow minSize/maxSize Constraints Added to Reinforce SwiftUI Frame
S44 macOS SwiftUI app refactoring: toolbar buttons to right side, sidebar background unification, window constraints, AppAppearance simplification (May 2 at 10:43 PM)
60 10:45p 🔵 AppAppearance Enum — Theme System Architecture
61 10:46p 🔵 SidebarAppearancePicker — Theme Picker UI Component Located in SidebarView.swift
62 " 🔄 AppAppearance Enum — Consolidated from 5 Cases to 3 with Legacy Migration Parser
S45 macOS SwiftUI toolbar icon size normalization — uniform 22×18 frame on all toolbar button images (May 2 at 10:47 PM)
S46 WorkspaceView Toolbar Buttons — Horizontal Padding Increased (May 2 at 10:52 PM)
63 11:04p 🔴 Workspace Titlebar Button — Horizontal Padding Fix
64 " 🔴 WorkspaceView Toolbar Buttons — Horizontal Padding Increased
S47 Workspace titlebar button horizontal padding fix — frame width 22→32pt (May 2 at 11:04 PM)
S48 Clear — session reset with no prior work (May 2 at 11:05 PM)
65 11:08p 🔴 WorkspaceView Toolbar Buttons — Additional .padding(.horizontal, 4) Applied
66 " ⚖️ WorkspaceView Toolbar Buttons — .padding(.horizontal, 4) Reverted
### May 8, 2026
S49 Inspect WorkspaceView title bar — enumerate toolbar items and button styles (May 8 at 1:57 PM)
67 1:58p 🔵 WorkspaceView Toolbar Items and Button Style Inventory
S50 Fix WorkspaceView toolbar button inconsistency — export menu icon missing .frame(width: 32, height: 18) (May 8 at 1:58 PM)
68 2:01p 🔵 AppChromeButtonStyle Internal Parameters and Layout Logic
69 2:02p 🔴 Export Menu Icon Missing Frame Modifier Fixed
S51 WorkspaceView toolbar inspection + Command+drag reordering implementation (May 8 at 2:02 PM)
70 2:07p 🔵 valeurayAI Minimum Deployment Target is macOS 14.0
71 " 🟣 Toolbar Given Stable ID to Enable NSToolbar Customization
72 " 🟣 Workspace Toolbar Items Now Support Command+Drag Reordering
S53 Chat composer input box: pill shape + animated orange gradient border, static idle, clockwise when loading (May 8 at 2:07 PM)
73 " 🟣 Chat input box animated gradient border — orange palette, clockwise on loading
74 2:12p 🔵 ComposerView.swift structure mapped for gradient border implementation
75 " 🔵 composerInputBox background uses AppTheme.radius — not pill shape
76 " 🟣 Orange gradient border state and colors added to ComposerView
77 " 🟣 Animated orange gradient border fully implemented on composerInputBox
78 2:13p 🔴 Removed .clipShape inset from composerInputBox — was incorrectly clipping shadow
79 " 🟣 ComposerView animated orange gradient border — build verified clean
S52 Chat input box: pill shape + animated orange gradient border (static idle, clockwise when loading) — fully implemented (May 8 at 2:13 PM)
80 3:00p 🔴 Crash on send fixed — replaced withAnimation(.repeatForever) with TimelineView for gradient rotation
81 5:17p 🔵 ChatWindowView Toolbar Layout — Web Button Placement

Access 584k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>