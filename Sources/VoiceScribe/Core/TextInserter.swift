import AppKit
import Carbon.HIToolbox

final class TextInserter {
    private struct ClipboardItem {
        let types: [NSPasteboard.PasteboardType: Data]
    }

    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        let backup = backupClipboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulatePaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.restoreClipboard(pasteboard, from: backup)
        }
    }

    private func backupClipboard(_ pasteboard: NSPasteboard) -> [ClipboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        return items.compactMap { item -> ClipboardItem? in
            var types = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    types[type] = data
                }
            }
            return types.isEmpty ? nil : ClipboardItem(types: types)
        }
    }

    private func restoreClipboard(_ pasteboard: NSPasteboard, from backup: [ClipboardItem]) {
        pasteboard.clearContents()

        if backup.isEmpty {
            return
        }

        var items = [NSPasteboardItem]()
        for backupItem in backup {
            let item = NSPasteboardItem()
            for (type, data) in backupItem.types {
                item.setData(data, forType: type)
            }
            items.append(item)
        }
        pasteboard.writeObjects(items)
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDownEvent?.flags = .maskCommand
        keyDownEvent?.post(tap: .cghidEventTap)

        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUpEvent?.flags = .maskCommand
        keyUpEvent?.post(tap: .cghidEventTap)
    }
}
