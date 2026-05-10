import SwiftUI
import AppKit

struct AppCommands: Commands {
    var body: some Commands {
        TextEditingCommands()
        SidebarCommands()

        CommandGroup(replacing: .appInfo) {
            Button("About Valeur AI") {
                AppCommands.showAboutPanel()
            }
        }

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

extension AppCommands {
    static func showAboutPanel() {
        let description = "Valeur AI is a private, encrypted AI workspace for chat, documents, and exports. Local-first storage keeps your data on-device, with API keys secured in the macOS Keychain.\n\n© \(Calendar.current.component(.year, from: Date())) Valeur AI. All Rights Reserved."

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2

        let credits = NSAttributedString(
            string: description,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
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
