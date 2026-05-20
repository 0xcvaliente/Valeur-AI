# Valeur AI App Documentation

_Last updated: May 10, 2026_

## Overview

Valeur AI is a native macOS desktop app for using multiple AI providers from one local-first interface. It is built for technical users who want direct provider access without running their own backend. Users bring their own API keys for OpenAI, Anthropic, Google Gemini, or OpenRouter.

The app combines an encrypted chat client with a block-based workspace editor. Chat is used for day-to-day AI conversations, while Workspace is used to turn answers, documents, tables, charts, and images into editable structured artifacts that can be revised with AI and exported.

## What the App Is About

Valeur AI is about giving users a private, Mac-native workspace for working with AI without depending on a separate Valeur-hosted backend. The app lets a user connect directly to their preferred AI providers, keep their conversations and workspaces stored locally, and move from a normal chat conversation into structured document work.

The main idea is simple: chat with AI, capture useful output, refine it in a workspace, and export it into practical formats. Instead of treating AI responses as disposable chat messages, Valeur AI turns them into material the user can edit, revise, save, and reuse.

The app is especially focused on technical and professional workflows where users care about control, local storage, provider choice, and exportable results. It is not only a chatbot; it is a desktop AI work environment for producing notes, documents, tables, charts, images, and structured deliverables.

## Target Users

- Developers and technical operators
- Power users who manage their own API keys
- Users who want local conversation storage on macOS
- Teams evaluating a private desktop AI client before building a hosted service

Valeur AI is not a zero-setup consumer product. It expects the user to configure at least one AI provider API key.

## Core Features

### Chat

- Native macOS SwiftUI chat interface
- Conversation sidebar with search, grouping, rename, and delete actions
- Per-conversation provider and model selection
- Streaming AI responses with stop and retry controls
- Markdown message rendering with support for code blocks
- Attachment support for images and PDFs when the selected model supports them
- Optional provider-side web search
- Context window/token usage tracking
- Chat tone selector for balanced, professional, creative, concise, and friendly behavior
- Conversation export to PDF, DOCX, and HTML
- Latest table export to CSV or XLSX
- Latest visual export to PNG

### Image Generation

- Image mode is available when the selected provider/model supports image generation.
- The current implementation routes image generation through OpenAI using `gpt-image-1`.
- Supported sizes are square `1024x1024`, portrait `1024x1536`, and landscape `1536x1024`.
- Generated images are stored as message attachments.

### Workspace

- Separate block-based editor opened from the chat window
- Multiple saved workspaces
- Workspace creation from assistant messages
- Block types: text, table, chart, and image
- Rich text editing for text blocks
- Table editing and CSV import/export
- Chart JSON import and PNG export
- Image import and caption editing
- AI revision for text, table, and chart blocks
- Revision modes: replace the current block or duplicate the revised result as a new block
- Revision history with restore support
- Workspace export to PDF, DOCX, and HTML

### Settings

Settings are organized into Defaults, Appearance, Personalization, API Keys, and Data.

- Default provider selection
- Per-provider model selection
- Custom model ID storage
- Context window display based on selected model
- Global system prompt
- Optional provider-side web search
- Appearance mode: Light, Dark, or System
- Font family selection, including Nexa and installed system fonts
- Font size scaling: Extra Small, Small, Normal, and Big
- User name, custom instructions, and memory document support
- Provider API key management

## Supported Providers

Valeur AI supports four provider families:

- OpenAI
- Anthropic
- Google Gemini
- OpenRouter

Each provider has model presets and a normalized model identifier system. The app stores selected models per provider, so switching providers preserves each provider's preferred model.

## Architecture

The app is a single-module macOS project with a mostly flat `Sources/` directory.

Important files:

- `Sources/ValeurAIApp.swift` initializes the app, SwiftData container, settings store, LLM service factory, shared app state, commands, and window sizing.
- `Sources/RootView.swift` handles first-run Terms gating, UI-test launch routing, and lazy creation of chat/workspace view models.
- `Sources/AppState.swift` contains shared app state and the main `ChatViewModel`.
- `Sources/Models.swift` defines providers, model presets, capabilities, chat request payloads, conversations, messages, attachments, composer modes, and image generation types.
- `Sources/Persistence.swift` implements `ConversationRepository` for SwiftData CRUD, encrypted persistence, streaming updates, metadata refresh, and legacy migration.
- `Sources/WorkspaceModels.swift` defines workspace records, block records, block kinds, and revision records.
- `Sources/WorkspaceRepository.swift` implements workspace CRUD, import, export, AI revision, revision history, and workspace view model behavior.
- `Sources/LLMService.swift` defines the provider service protocol and service factory.
- `Sources/ProviderServices.swift` implements OpenAI, Anthropic, Gemini, and OpenRouter request/streaming behavior.
- `Sources/SSE.swift` parses server-sent event streams.
- `Sources/SettingsStore.swift` owns app settings, model selection, personalization, memory documents, web search, appearance, and API-key access.
- `Sources/DatabaseEncryption.swift` provides AES-256-GCM encryption for local persisted data.
- `Sources/KeychainService.swift` wraps macOS Keychain storage and legacy service migration.
- `Sources/ExportService.swift` renders chat and workspace exports.
- `Sources/WorkspaceTextStorage.swift` converts rich text, Markdown, and HTML for workspace text blocks.
- `Sources/SpreadsheetSupport.swift` supports XLSX import/export.
- `Sources/AppCommands.swift` defines app menus, shortcuts, and export/workspace commands.
- `Sources/UITestLaunchConfiguration.swift` contains guarded UI-test launch configuration.

## Data Storage

Conversation and workspace data are persisted with SwiftData. Sensitive stored content is encrypted before being written to the local database.

Encrypted local data includes:

- Conversation titles
- Message content
- Per-conversation system prompt overrides
- Message attachments
- Workspace titles
- Workspace block content
- Workspace block attachments
- Workspace revision instructions and content

The encryption key is generated locally and stored in macOS Keychain. Encryption uses AES-256-GCM through CryptoKit.

## Keychain Usage

The app uses Keychain for:

- Provider API keys
- Database encryption key
- Global system prompt
- Custom instructions
- User name
- Memory document content

Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The app also migrates selected legacy Keychain services into the current app service when values are found.

## Privacy Model

Valeur AI is local-first, not local-only.

Stored locally:

- Conversation history
- Workspace documents
- Attachments
- Settings and personalization
- Memory document content

Sent to providers when used:

- Active chat messages
- Relevant conversation history
- System prompts and personalization text included in the request
- Attachments included in the request
- Web search permission when enabled

Not present in this repo:

- No Valeur AI backend
- No account system
- No telemetry pipeline
- No analytics service

## Security Boundaries

Strengths:

- API keys are stored in Keychain, not plaintext files.
- Local conversation and workspace content is encrypted at rest.
- The app sandbox is enabled.
- Entitlements are limited to network client access and user-selected read-only files.
- File imports use user-selected file access.
- Provider-side web search is off by default.
- UI-test destructive behavior is gated by both the `--ui-testing` launch argument and XCTest runner environment variables.

Limitations:

- This is not end-to-end encryption. The app decrypts data locally to display it and to send requests.
- Provider requests are sent in plaintext to the selected provider over HTTPS.
- A fully compromised macOS user session may also compromise Keychain-backed local access.
- If the persistent store cannot be opened, the app falls back to temporary in-memory mode and shows a storage warning.

## User Flow

1. On first launch, the user accepts the Terms & Conditions.
2. The user opens Settings and enters at least one provider API key.
3. The user selects a default provider and model.
4. The user creates or opens a chat.
5. The user sends messages, optionally with supported attachments.
6. The app streams assistant responses and saves the encrypted conversation locally.
7. The user can export conversations or open assistant output in Workspace.
8. In Workspace, the user edits blocks, imports files, revises blocks with AI, restores revisions, and exports final documents.

## Current Status

Valeur AI is a private technical macOS app with the core chat, provider, workspace, encryption, settings, and export systems implemented. The main remaining areas for broader distribution are deeper integration testing, additional recovery tooling around local storage failures, and more polish around provider-specific edge cases.
