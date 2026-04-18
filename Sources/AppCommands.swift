import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Chat") {
                NotificationCenter.default.post(name: .newChatRequested, object: nil)
            }
            .keyboardShortcut("n")
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
}
