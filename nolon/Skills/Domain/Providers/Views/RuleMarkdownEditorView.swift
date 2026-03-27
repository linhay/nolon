import SwiftUI
import NolonUI
import STFilePath

struct RuleMarkdownEditorView: View {
    let ruleURL: URL
    let onSave: (String) async -> Void

    var body: some View {
        NolonUI.CodeEditorSheetView(
            title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules"),
            initialTextLoader: {
                (try? STFile(ruleURL).read()) ?? ""
            },
            highlight: nil,
            onValidate: { _ in },
            onSave: { text in
                try STFile(ruleURL).overlay(with: text)
                await onSave(text)
            }
        )
    }
}
