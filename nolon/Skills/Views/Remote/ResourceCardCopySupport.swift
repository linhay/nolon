import Foundation
import AppKit

enum ResourceCardCopySupport {
    static func normalizedTitle(_ rawTitle: String) -> String? {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func copyTitle(
        _ rawTitle: String,
        writeText: ((String) -> Void)? = nil
    ) {
        guard let title = normalizedTitle(rawTitle) else { return }
        if let writeText {
            writeText(title)
        } else {
            writeToPasteboard(title)
        }
    }

    private static func writeToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
