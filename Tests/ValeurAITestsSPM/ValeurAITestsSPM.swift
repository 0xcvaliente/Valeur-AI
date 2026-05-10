import Foundation
import Testing
@testable import ValeurAI

@MainActor
struct ConversationListMetadataSPMTests {

    @Test func metadataCreatesSearchableConversationSnapshot() throws {
        let conversation = ConversationRecord(
            storedTitle: try MessageEncryption.shared.encryptString("Roadmap")
        )
        let message = MessageRecord(
            role: .user,
            storedContent: try MessageEncryption.shared.encryptString("Plan alpha launch"),
            conversation: conversation
        )
        conversation.messages = [message]

        let metadata = ConversationListMetadata.make(for: conversation)

        #expect(metadata.title == "Roadmap")
        #expect(metadata.summary == "Plan alpha launch")
        #expect(metadata.searchableText.contains("alpha launch"))
    }
}

struct SecureFileAccessSPMTests {

    @Test func readsTemporaryTextFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("sample.txt")
        try Data("Hello from SwiftPM".utf8).write(to: url, options: .atomic)

        let text = try await SecureFileAccess.text(from: url)

        #expect(text == "Hello from SwiftPM")
    }

    @Test func rejectsOversizedFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("large.bin")
        try Data(count: SecureFileAccess.maximumImportBytes + 1).write(to: url, options: .atomic)

        do {
            _ = try await SecureFileAccess.data(from: url, maxBytes: SecureFileAccess.maximumImportBytes)
            Issue.record("Expected oversized file read to fail")
        } catch let error as SecureFileAccessError {
            switch error {
            case .fileTooLarge:
                break
            }
        }
    }
}

struct RemoteImageSupportSPMTests {

    @Test func normalizedHTTPURLRejectsNonWebSchemes() {
        #expect(RemoteImageSupport.normalizedHTTPURL(from: "https://example.com/image.png")?.absoluteString == "https://example.com/image.png")
        #expect(RemoteImageSupport.normalizedHTTPURL(from: "file:///tmp/image.png") == nil)
        #expect(RemoteImageSupport.normalizedHTTPURL(from: "smb://server/image.png") == nil)
        #expect(RemoteImageSupport.normalizedHTTPURL(from: "javascript:alert(1)") == nil)
    }

    @Test func workspaceImagePayloadOnlyResolvesHTTPURLs() {
        let safePayload = WorkspaceImagePayload(caption: "", remoteURLString: "https://example.com/image.png")
        let unsafePayload = WorkspaceImagePayload(caption: "", remoteURLString: "file:///tmp/image.png")

        #expect(safePayload.remoteURL?.absoluteString == "https://example.com/image.png")
        #expect(unsafePayload.remoteURL == nil)
    }
}

struct TokenFormattingAttachmentSPMTests {

    @Test func attachmentTokenEstimateScalesWithByteCount() {
        #expect(TokenFormatting.estimatedAttachmentTokenCount(forByteCount: 0) == 0)
        #expect(TokenFormatting.estimatedAttachmentTokenCount(forByteCount: 3) == 1)
        #expect(TokenFormatting.estimatedAttachmentTokenCount(forByteCount: 12) > TokenFormatting.estimatedAttachmentTokenCount(forByteCount: 3))
    }
}
