import SwiftUI
import NolonUI
import STFilePath

struct RuleMarkdownEditorView: View {
    let ruleURL: URL
    let onSave: (String) async -> Void

    @State private var initialText: String = ""

    var body: some View {
        NolonUI.CodeEditorSheetView(
            title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules"),
            initialText: initialText,
            highlight: nil,
            onValidate: { _ in },
            onSave: { text in
                try STFile(ruleURL).overlay(with: text)
                await onSave(text)
            }
        )
        .task {
            if initialText.isEmpty {
                initialText = (try? STFile(ruleURL).read()) ?? ""
            }
        }
    }
}
