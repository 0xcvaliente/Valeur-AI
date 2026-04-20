# Valeur AI

Valeur AI is a native macOS desktop chat client for technical users who want a local-first interface for OpenAI, Anthropic, and Gemini without adding a backend of their own.

Built with SwiftUI, SwiftData, async/await, and Keychain-backed secret storage. Designed for private use, direct provider access, encrypted local conversation history, and an integrated block-based workspace editor on the Mac.

## Audience

- Developers and technical operators
- Power users comfortable supplying their own provider API keys
- Teams evaluating a private desktop client before investing in a hosted backend

This is not a zero-setup consumer app. Users are expected to bring their own OpenAI, Anthropic, or Google Gemini API keys.

## Current Status

Valeur AI is release-ready for private technical use.

What is in place:

- Native macOS split-view chat interface
- Persistent encrypted local conversations (AES-256-GCM)
- Streaming responses over SSE with retry and stop controls
- Per-conversation provider and model selection
- Provider abstraction for OpenAI, Anthropic, and Gemini
- Attachment support for images and PDFs
- Personalization settings and memory document support
- Terms & Conditions acceptance on first launch
- Keychain-backed API key and settings storage with one-time legacy migration
- Block-based Workspace editor with AI revision and multi-format export
- Five appearance themes (Light, Dark, System, Orange, Blue) with dynamic accent colors
- 64 passing Xcode unit tests plus XCUI tests for first-run, settings, and delete flows
- DMG and TestFlight packaging scripts

What still needs work before a broader public release:

- Integration test coverage for the persistence and provider layers
- In-app repair tooling beyond the current storage warning and temporary in-memory fallback
- Broader UX polish around failure handling edge cases

## Features

### Chat
- Three-pane macOS layout: sidebar, chat detail, settings scene
- Grouped conversation sidebar with search and provider badges
- Transparent title bar and full-screen support
- Streaming assistant replies with token-efficient in-memory accumulation
- Markdown rendering with fenced code block copy support
- Per-conversation system prompt overrides
- Provider-specific model selection with preset menu
- Context window token usage indicator
- Inline LLM and model selector in the composer
- Provider-side web search opt-in

### Workspace
- Block-based document editor launched from any chat session
- Block types: text, table, chart, image
- AI revision on any block with streaming output and instruction field
- Revision history per block — revert to any prior version
- Multi-format export: PDF, DOCX, HTML, CSV, XLSX, PNG
- Import from file into any block type
- Multiple workspaces with sidebar navigation

### Storage and Security
- Keychain-backed API key storage (no plaintext config files)
- Keychain-backed personalization and memory document storage
- Local conversation and workspace persistence via SwiftData
- AES-256-GCM encryption for message content, titles, system prompt overrides, and attachment blobs
- One-time legacy keychain migration (prompts once, never again)
- File access scoped to user-selected files via `NSOpenPanel`

### Appearance
- Five themes: Light, Dark, System, Orange (light + orange accent), Blue (dark + blue accent)
- Dynamic accent colors propagate across all UI surfaces on theme switch
- Font family picker with Nexa support and full system font access
- Font size scaling (small / normal / large)

### First Run
- Terms & Conditions gate on first launch

## Architecture

28 source files in a flat `Sources/` directory. Clean community structure with no cross-module coupling warnings.

| File | Role |
|---|---|
| `ValeurAIApp.swift` | App entry, SwiftData container, crash recovery |
| `AppState.swift` | `AppState` (global state) + `ChatViewModel` (per-session logic) |
| `Models.swift` | `LLMProvider`, `ConversationRecord`, `MessageRecord`, payloads |
| `Persistence.swift` | `ConversationRepository` — SwiftData CRUD, stream update, migration-on-read |
| `DatabaseEncryption.swift` | AES-256-GCM encryption singleton backed by Keychain |
| `KeychainService.swift` | macOS Keychain read/write/delete with legacy service migration |
| `SecureFileAccess.swift` | Scoped security-bookmark file access (NSOpenPanel-selected files) |
| `UITestLaunchConfiguration.swift` | Test-environment detection — requires both launch arg and XCTest runner env vars |
| `LLMService.swift` | `LLMService` protocol + cached `LLMServiceFactory` |
| `ProviderServices.swift` | OpenAI, Anthropic, Gemini streaming implementations |
| `SSE.swift` | Server-Sent Events parser |
| `SettingsStore.swift` | `@MainActor` settings — Keychain + UserDefaults, all provider preferences, theme |
| `AppTheme.swift` | Design tokens, fonts, dynamic accent colors, button styles |
| `ChatWindowView.swift` | Root window chrome, sidebar toggle, title bar |
| `ChatDetailView.swift` | Message list, LLM selector menu, toolbar |
| `ComposerView.swift` | Text input, attachment picker, inline model selector |
| `MessageBubbleView.swift` | Markdown renderer, code blocks, attachment images |
| `SidebarView.swift` | Conversation list, search, brand header |
| `SettingsView.swift` | Full settings panel (API keys, appearance, personalization) |
| `RootView.swift` | Terms gate + ViewModel initialization |
| `TermsView.swift` | First-run Terms & Conditions screen |
| `TokenFormatting.swift` | Token count estimation and display formatting |
| `AppCommands.swift` | macOS menu commands |
| `WorkspaceModels.swift` | `WorkspaceRecord`, `WorkspaceBlock`, block kind enums, revision history |
| `WorkspaceRepository.swift` | `WorkspaceViewModel` — CRUD, AI revision, import, export (PDF/DOCX/HTML/CSV/XLSX/PNG) |
| `WorkspaceView.swift` | Block-based editor UI — sidebar, block cards, AI revision sheet, history sheet |
| `ExportService.swift` | Export rendering pipeline for all workspace output formats |
| `SpreadsheetSupport.swift` | XLSX read/write support for table block import and export |

## Security

### Strengths

- API keys stored exclusively in macOS Keychain — no plaintext config files
- Personalization fields and memory document content stored via Keychain-backed paths
- All conversation data encrypted at rest with AES-256-GCM before SwiftData persistence:
  - message content
  - conversation titles
  - per-conversation system prompt overrides
  - attachment blobs
- Encryption key itself stored in Keychain; lazy retry if Keychain unavailable at launch
- App Sandbox enabled with minimal entitlements (no `keychain-access-groups` needed)
- File access limited to user-selected files via security-scoped bookmarks
- Network access is outbound client-only
- Provider-side web search is opt-in, disabled by default
- One-time legacy keychain migration — prompts once, migrates to current service, never prompts again
- UI test environment detection requires both a launch argument and XCTest runner environment variables — prevents spoofing via manual app launch

### Limitations

- Not end-to-end encryption. The app decrypts locally to display and send messages.
- Provider requests send message content, prompts, and attachments to the selected AI provider over HTTPS. OpenAI, Anthropic, and Google process plaintext on their end.
- If the local macOS account and user session are fully compromised, local encryption at rest does not prevent access — Keychain access follows the user session.
- SwiftData migration failure triggers a store wipe and in-memory fallback without a user-visible alert.

### Practical scope

**Suitable for:** private use on a trusted Mac, direct provider access for technical users, bring-your-own-key workflows.

**Not positioned for:** regulated workloads, enterprise compliance claims, consumer-facing privacy promises beyond local encryption at rest and standard HTTPS transport.

## Privacy Model

Valeur AI is local-first, not local-only.

**Stored locally (encrypted at rest):**
- Conversation history and metadata
- Attachments added to chats
- Personalization settings
- Memory document content

**Sent to providers when you use them:**
- Chat messages in the active conversation
- Per-conversation system prompt overrides
- Global personalization content (if composited into system prompt)
- Attachments included in the request
- Web search directives (if enabled in Settings)

**Not present:**
- No Valeur AI backend in this repo
- No built-in account system
- No telemetry or analytics pipeline

## Repository Layout

```
Sources/                  Application source (28 files)
Assets.xcassets/          Icons and brand assets
Distribution/             Export option templates and packaging assets
script/                   Local build and release shell scripts
Tests/                    SwiftPM test targets
Valeur AITests/           64 Xcode unit tests (Swift Testing)
Valeur AIUITests/         XCUI tests for first-run, settings, and delete flows
valeuray.xcodeproj/       Primary Xcode project
Package.swift             SwiftPM package definition
ValeurAI.entitlements     App sandbox entitlements
```

## Run Locally

### Xcode (recommended)

1. Open `valeuray.xcodeproj`
2. Select the `Valeur AI` scheme
3. Build and run (`Cmd+R`)

Run tests with `Cmd+U`.

### SwiftPM

```bash
swift build
swift test
swift run
```

Clean build path if needed:

```bash
swift build --build-path /tmp/valeurayAI-swift-build
```

## Configuration

On first launch, accept the Terms & Conditions, then open Settings and add at least one provider API key:

- OpenAI
- Anthropic
- Google Gemini

Additional settings:

- Default provider and model per provider
- Global system prompt
- Custom instructions
- User name for personalization
- Optional memory document (PDF or plain text)
- Context window size per provider
- Provider-side web search (opt-in)
- App appearance (Light / Dark / System / Orange / Blue)
- Font family and size

## Attachments

- Images (JPEG, PNG, WebP, and other formats supported by the provider)
- PDFs

Selected via standard macOS file importer. Stored encrypted with the conversation. 20 MB per-file limit enforced before upload.

## Build a Release DMG

```bash
# Local test (ad-hoc signed)
./script/release_dmg.sh --local

# Developer ID signed
./script/release_dmg.sh --team-id ABCDE12345

# Developer ID + notarize
./script/release_dmg.sh --team-id ABCDE12345 --notary-profile valeuray-ai-notary
```

Requirements for Developer ID export: Apple Developer account, Xcode signed in with your team, valid `Developer ID Application` certificate.

## Upload to TestFlight

1. Open `valeuray.xcodeproj`
2. Select `Any Mac`
3. `Product > Archive`
4. In Organizer: `Distribute App > App Store Connect > Upload`

Export options template: `Distribution/ExportOptions-AppStoreConnect.plist.template`

## Known Limitations

- Requires user-supplied provider API keys — no built-in free tier
- No Valeur AI backend or account system
- SwiftData recovery warns the user and falls back to in-memory mode, but repair remains manual
- Conversation history is encrypted at rest but not end-to-end encrypted
- Test coverage is strongest in utilities and view-model helpers; persistence and provider layers still need deeper integration coverage
