import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Chat") {
                NotificationCenter.default.post(name: .newChatRequested, object: nil)
            }
            .keyboardShortcut("n")
        }

        CommandMenu("Export") {
            Button("Conversation as PDF") {
                NotificationCenter.default.post(name: .exportConversationPDFRequested, object: nil)
            }

            Button("Conversation as DOCX") {
                NotificationCenter.default.post(name: .exportConversationDOCXRequested, object: nil)
            }

            Button("Conversation as HTML") {
                NotificationCenter.default.post(name: .exportConversationHTMLRequested, object: nil)
            }

            Button("Latest Table as CSV") {
                NotificationCenter.default.post(name: .exportLatestTableCSVRequested, object: nil)
            }

            Button("Latest Table as XLSX") {
                NotificationCenter.default.post(name: .exportLatestTableXLSXRequested, object: nil)
            }

            Button("Latest Visual as PNG") {
                NotificationCenter.default.post(name: .exportLatestVisualPNGRequested, object: nil)
            }
        }

        CommandMenu("Workspace") {
            Button("Show Workspace") {
                NotificationCenter.default.post(name: .openWorkspaceRequested, object: nil)
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
            .keyboardShortcut(",")
        }
    }
}

extension Notification.Name {
    static let newChatRequested = Notification.Name("newChatRequested")
    static let deleteAllConversationsRequested = Notification.Name("deleteAllConversationsRequested")
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    static let exportConversationPDFRequested = Notification.Name("exportConversationPDFRequested")
    static let exportConversationDOCXRequested = Notification.Name("exportConversationDOCXRequested")
    static let exportConversationHTMLRequested = Notification.Name("exportConversationHTMLRequested")
    static let exportLatestTableCSVRequested = Notification.Name("exportLatestTableCSVRequested")
    static let exportLatestTableXLSXRequested = Notification.Name("exportLatestTableXLSXRequested")
    static let exportLatestVisualPNGRequested = Notification.Name("exportLatestVisualPNGRequested")
    static let openWorkspaceRequested = Notification.Name("openWorkspaceRequested")
}
