import SwiftUI
import NolonUI

struct RuleMarkdownEditorView: View {
    let ruleURL: URL
    let onSave: (String) async -> Void

    var body: some View {
        NolonUI.FileBackedCodeEditorSheetView(
            title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules"),
            fileURL: ruleURL,
            highlight: nil,
            onValidate: { _ in },
            onAfterSave: { text in
                await onSave(text)
            }
        )
    }
}
