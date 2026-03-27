import Foundation
import SwiftUI

public struct FileBackedCodeEditorSheetView: View {
    let title: String
    let fileURL: URL
    let highlight: WebCodeEditorHighlight?
    let invalidAlertTitle: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let onValidate: (String) throws -> Void
    let onAfterSave: ((String) async -> Void)?

    public init(
        title: String,
        fileURL: URL,
        highlight: WebCodeEditorHighlight?,
        invalidAlertTitle: String = NSLocalizedString(
            "generic.error",
            value: "Error",
            comment: "Generic error title"
        ),
        minWidth: CGFloat = 760,
        minHeight: CGFloat = 560,
        onValidate: @escaping (String) throws -> Void,
        onAfterSave: ((String) async -> Void)? = nil
    ) {
        self.title = title
        self.fileURL = fileURL
        self.highlight = highlight
        self.invalidAlertTitle = invalidAlertTitle
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.onValidate = onValidate
        self.onAfterSave = onAfterSave
    }

    public var body: some View {
        CodeEditorSheetView(
            title: title,
            initialTextLoader: {
                (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            },
            highlight: highlight,
            invalidAlertTitle: invalidAlertTitle,
            minWidth: minWidth,
            minHeight: minHeight,
            onValidate: onValidate,
            onSave: { text in
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                await onAfterSave?(text)
            }
        )
    }
}
