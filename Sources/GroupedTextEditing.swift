import AppKit

final class GroupedTextUndoManager: UndoManager {
    var closeGroupHandler: (() -> Void)?

    override func undo() {
        closeGroupHandler?()
        super.undo()
    }

    override func redo() {
        closeGroupHandler?()
        super.redo()
    }
}

func shouldCloseGroupedTextUndo(for selector: Selector) -> Bool {
    switch selector {
    case #selector(NSTextView.deleteBackward(_:)),
         #selector(NSTextView.deleteForward(_:)),
         #selector(NSTextView.deleteWordBackward(_:)),
         #selector(NSTextView.deleteWordForward(_:)),
         #selector(NSTextView.deleteToBeginningOfLine(_:)),
         #selector(NSTextView.deleteToEndOfLine(_:)),
         #selector(NSTextView.insertNewline(_:)),
         #selector(NSTextView.insertTab(_:)):
        return true
    default:
        return false
    }
}

func macTextDeletionSelector(for event: NSEvent, allowsMarkedText: Bool) -> Selector? {
    guard allowsMarkedText, event.type == .keyDown else { return nil }

    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    switch (modifiers, event.keyCode) {
    case ([.command], 51):
        return #selector(NSTextView.deleteToBeginningOfLine(_:))
    case ([.command], 117):
        return #selector(NSTextView.deleteToEndOfLine(_:))
    case ([.option], 51):
        return #selector(NSTextView.deleteWordBackward(_:))
    case ([.option], 117):
        return #selector(NSTextView.deleteWordForward(_:))
    default:
        return nil
    }
}
