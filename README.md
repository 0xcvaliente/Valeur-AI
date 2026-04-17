# Valeuray AI

Valeuray AI is a native macOS desktop chat client for technical users who want a local-first interface for OpenAI, Anthropic, and Gemini without adding a backend of their own.

The app is built with SwiftUI, SwiftData, async/await, and Keychain-backed secret storage. It is designed for private use, direct provider access, and local conversation history on the Mac.

## Audience

This project is aimed at:

- developers
- technical operators
- power users who are comfortable supplying their own provider API keys
- teams evaluating a private desktop client before investing in a hosted backend

This is not a zero-setup consumer app. Users are expected to bring their own OpenAI, Anthropic, or Gemini API keys.

## Current Status

Valeuray AI is best described as a strong beta for private technical use.

What is already in place:

- native macOS split-view chat interface
- persistent local conversations
- streaming responses over SSE
- per-conversation provider and model selection
- provider abstraction for OpenAI, Anthropic, and Gemini
- attachment support for images and PDFs
- personalization settings and memory document support
- DMG and TestFlight-oriented packaging files

What still needs work before a broader public release:

- stronger automated test coverage
- more migration and corruption recovery coverage
- broader UX polish around failure handling and onboarding
- more operational validation for release packaging and upgrade flows

## Features

- Three-pane macOS layout with sidebar, chat detail, and dedicated settings scene
- Grouped conversation sidebar with search and provider badges
- Streaming assistant replies with retry and stop controls
- Markdown rendering with fenced code block copy support
- Per-conversation system prompt overrides
- Provider-specific model selection
- Keychain-backed API key storage
- Keychain-backed personalization and memory document storage
- Local conversation persistence in SwiftData
- Encrypted local storage for message text, conversation titles, per-conversation prompt overrides, and attachment blobs
- Provider-side web search disabled by default and exposed as an explicit setting

## Security Assessment

### Summary

For a private desktop client aimed at technical users, the security posture is good. For high-assurance, regulated, or adversarial environments, it is not complete enough to claim strong confidentiality guarantees end to end.

### Current strengths

- API keys are stored in the macOS Keychain, not in plaintext config files.
- Personalization fields and memory-document content are also stored through Keychain-backed paths.
- Local conversation data is encrypted before persistence, including:
  - message content
  - conversation titles
  - per-conversation system prompt overrides
  - stored attachment blobs
- The app runs with App Sandbox enabled.
- File access is limited to user-selected files.
- Network access is client-only.
- Provider-side web search is opt-in rather than always enabled.
- Sensitive malformed-provider payloads are no longer logged verbatim.

### Important limitations

- This is not end-to-end encryption.
  The app must decrypt data locally in order to display and send it.
- Provider requests still send message content, prompts, and attachments to the selected upstream model provider over HTTPS.
  OpenAI, Anthropic, or Google Gemini can only process data they receive in plaintext on their side.
- If the local macOS account is fully compromised and the attacker has access to the user session and Keychain, local encryption at rest is not enough to protect the data.
- The current automated test coverage is minimal, which means persistence migrations and provider parsing are not yet defended by a strong regression suite.

### Practical conclusion

This app is suitable for:

- private local usage on a trusted Mac
- direct provider access for technical users
- teams comfortable with bring-your-own-key workflows

This app is not yet positioned for:

- regulated workloads
- enterprise compliance claims
- strong local-forensics resistance against a fully compromised logged-in system
- consumer-facing privacy promises beyond local encryption at rest and standard HTTPS provider transport

## Privacy Model

Valeuray AI is local-first, but not local-only.

Stored locally:

- conversation history
- conversation metadata
- attachments added to chats
- personalization settings
- memory document content
- selected provider and model preferences

Sent to providers when you use them:

- chat messages in the current conversation
- per-conversation prompt overrides
- global personalization content if it applies to the composed system prompt
- attachments included in the request
- optional provider-side web search directives if enabled in Settings

Not included:

- there is no hosted Valeuray AI backend in this repo
- there is no built-in account system
- there is no telemetry or analytics pipeline in the app code today

## Architecture

Core implementation areas:

- [`Sources/LLMService.swift`](Sources/LLMService.swift): provider interface and service factory
- [`Sources/ProviderServices.swift`](Sources/ProviderServices.swift): OpenAI, Anthropic, and Gemini request/stream handling
- [`Sources/SSE.swift`](Sources/SSE.swift): SSE parsing and stream limits
- [`Sources/Persistence.swift`](Sources/Persistence.swift): SwiftData repository and migration-on-read behavior
- [`Sources/DatabaseEncryption.swift`](Sources/DatabaseEncryption.swift): local encryption helpers
- [`Sources/SettingsStore.swift`](Sources/SettingsStore.swift): Keychain-backed settings and personalization
- [`Sources/ChatWindowView.swift`](Sources/ChatWindowView.swift), [`Sources/ChatDetailView.swift`](Sources/ChatDetailView.swift), [`Sources/SidebarView.swift`](Sources/SidebarView.swift): main macOS UI surfaces

## Repository Layout

- [`Sources`](Sources): application source
- [`Assets.xcassets`](Assets.xcassets): icons and brand assets
- [`Distribution`](Distribution): export option templates and packaging assets
- [`script`](script): local build and release helpers
- [`valeuray.xcodeproj`](valeuray.xcodeproj): primary Xcode project
- [`Package.swift`](Package.swift): SwiftPM package definition for package-based builds

## Run Locally

### Recommended: Xcode

1. Open [`valeuray.xcodeproj`](valeuray.xcodeproj).
2. Select the `Valeuray AI` scheme.
3. Build and run the app on macOS.

### SwiftPM

`Package.swift` is still present for local package builds:

```bash
swift build
swift run
```

If the local Swift module cache was created under a different path, use a clean build path:

```bash
swift build --build-path /tmp/valeurayAI-swift-build
```

## Configuration

On first use, open Settings and add one or more provider API keys:

- OpenAI
- Anthropic
- Google Gemini

You can also configure:

- default provider
- model per provider
- global system prompt
- custom instructions
- user name
- optional memory document
- optional provider-side web search

## Attachments

The current client supports:

- images
- PDFs

Files are selected through the standard macOS file importer and then stored locally with the conversation history.

## Build a Downloadable DMG

The repo includes a DMG packaging script:

- [`script/release_dmg.sh`](script/release_dmg.sh)
- [`Distribution/ExportOptions-DeveloperID.plist.template`](Distribution/ExportOptions-DeveloperID.plist.template)

### Local packaging test

```bash
./script/release_dmg.sh --local
```

### Developer ID export

Requirements:

- Apple Developer account
- Xcode signed in with your team
- valid `Developer ID Application` certificate
- Apple Team ID

Run:

```bash
./script/release_dmg.sh --team-id ABCDE12345
```

### Notarize during packaging

```bash
./script/release_dmg.sh --team-id ABCDE12345 --notary-profile valeuray-ai-notary
```

## Upload to TestFlight

The project also includes App Store Connect export support:

- [`ValeurayAI.entitlements`](ValeurayAI.entitlements)
- [`Distribution/ExportOptions-AppStoreConnect.plist.template`](Distribution/ExportOptions-AppStoreConnect.plist.template)

Recommended flow:

1. Open [`valeuray.xcodeproj`](valeuray.xcodeproj).
2. Select `Any Mac`.
3. Run `Product > Archive`.
4. In Organizer, choose `Distribute App`.
5. Select `App Store Connect`, then `Upload`.

## Known Limitations

- The app depends on end-user provider keys.
- There is no Valeuray AI backend in this repo.
- Automated tests are currently light.
- Conversation history is encrypted at rest locally, but the app is not end-to-end encrypted.
- Upstream providers still receive the content needed to answer requests.

## Final Assessment

As it stands today, Valeuray AI is a credible private desktop client for technical users.

The core product direction is sound:

- native macOS UI
- no required backend
- direct provider access
- local persistence
- practical security improvements already in place

The remaining work is mainly about robustness, not product fit:

- better tests
- more defensive migration coverage
- more release validation
- clearer user-facing privacy messaging as the app matures
