import AppKit
import Carbon.HIToolbox
import CoreGraphics

final class TextInserter {
    private struct ClipboardItem {
        let types: [NSPasteboard.PasteboardType: Data]
    }

    /// Electron and browser-based apps may consume Cmd-V well after the event
    /// is posted. The old 150 ms delay could restore the previous clipboard too
    /// early, causing that previous value to be pasted instead.
    private let restoreDelay: TimeInterval = 1.25

    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let backup = backupClipboard(pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return }
        let transcriptionChangeCount = pasteboard.changeCount

        simulatePaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) { [weak self] in
            guard let self else { return }
            // If the user or another app copied something after transcription,
            // preserve that newer clipboard rather than restoring stale data.
            guard pasteboard.changeCount == transcriptionChangeCount else { return }
            self.restoreClipboard(pasteboard, from: backup)
        }
    }

    private func backupClipboard(_ pasteboard: NSPasteboard) -> [ClipboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.compactMap { item in
            var types: [NSPasteboard.PasteboardType: Data] = [:]
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
        guard !backup.isEmpty else { return }

        let items = backup.map { backupItem -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in backupItem.types {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
              ) else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
