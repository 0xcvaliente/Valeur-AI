# Valeuray AI

A native macOS chat client scaffold built with SwiftUI, SwiftData, async/await, and secure Keychain-backed API key storage.

## What is included

- Three-pane macOS layout with a grouped chat sidebar and dedicated settings scene
- MVVM structure with persistent local conversations in SwiftData
- Provider abstraction via `LLMService` plus modular OpenAI Responses API, Anthropic, and Gemini implementations
- SSE parsing for streaming assistant responses into the UI in real time
- Markdown-friendly assistant bubbles with fenced code block rendering and copy support
- Per-conversation provider, model, and system-prompt overrides
- Retry and stop controls for in-flight streamed responses
- Searchable sidebar rows with provider badges and chat previews
- Secure API key storage through the macOS Keychain

## Project structure

- [Package.swift](Package.swift)
- [valeuray.xcodeproj](valeuray.xcodeproj)
- [Sources](Sources)

## Notes

- The recommended path now is to open [valeuray.xcodeproj](valeuray.xcodeproj) in Xcode and run the `Valeuray AI` scheme.
- The Xcode app target uses bundle identifier `com.sehford.valeurayai.macosapp`, so you should no longer get the missing main bundle identifier warning from the package-based setup.
- `Package.swift` is still there if you want to keep using SwiftPM builds alongside the app project.

## Release a Mac Download

This repo now includes a DMG release script:

- [script/release_dmg.sh](script/release_dmg.sh)
- [Distribution/ExportOptions-DeveloperID.plist.template](Distribution/ExportOptions-DeveloperID.plist.template)

This path is for direct downloads outside the App Store. It is not the right flow for TestFlight.

### 1. Test the packaging flow locally

```bash
./script/release_dmg.sh --local
```

This builds a local Release app and wraps it in a DMG for testing only.

### 2. Build a real downloadable Developer ID DMG

Requirements:

- Apple Developer account
- Xcode signed in with your developer account
- A valid `Developer ID Application` certificate in Keychain Access
- Your Apple Team ID

Run:

```bash
./script/release_dmg.sh --team-id ABCDE12345
```

That archives the app, exports it with the `developer-id` method, and creates a DMG in `dist/release/<timestamp>/`.

### 3. Notarize the DMG

Store your notary credentials once:

```bash
xcrun notarytool store-credentials "valeuray-ai-notary"
```

Then build and notarize in one step:

```bash
./script/release_dmg.sh --team-id ABCDE12345 --notary-profile valeuray-ai-notary
```

### 4. Publish

Upload the notarized DMG from `dist/release/<timestamp>/` to your website or a GitHub release.

## Upload to TestFlight

TestFlight for macOS uses the App Store Connect distribution flow, not the Developer ID DMG flow above.

Requirements:

- App Sandbox enabled on the app target
- A valid App Store Connect-ready signing setup in Xcode for your team
- A fresh archive built after the sandbox entitlement change

This repo now includes:

- [ValeurayAI.entitlements](ValeurayAI.entitlements)
- [Distribution/ExportOptions-AppStoreConnect.plist.template](Distribution/ExportOptions-AppStoreConnect.plist.template)

Recommended path in Xcode:

1. Open [valeuray.xcodeproj](valeuray.xcodeproj).
2. Select `Any Mac` as the destination.
3. Run `Product > Archive`.
4. In Organizer, choose `Distribute App`.
5. Select `App Store Connect`, then `Upload`.

Command-line archive example:

```bash
  xcodebuild \
  -project valeuray.xcodeproj \
  -scheme "Valeuray AI" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath dist/testflight/ValeurayAI.xcarchive \
  -allowProvisioningUpdates \
  archive
```

If you export from the command line, use the App Store Connect template, not the Developer ID one.

## Ready-to-Use Note

The app package can be download-ready, but the current product still expects the user to add their own OpenAI, Anthropic, or Gemini API keys in Settings. If you want a true zero-setup consumer app, the next step is adding your own backend so the app does not depend on end-user API keys.
