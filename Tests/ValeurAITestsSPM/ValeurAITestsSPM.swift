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
}
