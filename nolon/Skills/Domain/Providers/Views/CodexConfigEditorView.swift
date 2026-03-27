import SwiftUI
import NolonUI
import STFilePath
import CodexProvider

struct CodexConfigEditorView: View {
    let configURL: URL
    let onSave: () -> Void

    @State private var initialText: String = ""

    var body: some View {
        NolonUI.CodeEditorSheetView(
            title: NSLocalizedString("codex.config.editor.title", value: "Edit config.toml", comment: "Codex config editor title"),
            initialText: initialText,
            highlight: nil,
            invalidAlertTitle: NSLocalizedString("codex.config.editor.error.title", value: "Invalid config.toml", comment: "Invalid config title"),
            minWidth: 860,
            minHeight: 620,
            onValidate: { text in
                try validate(text)
            },
            onSave: { text in
                try STFile(configURL).overlay(with: text)
                onSave()
            }
        )
        .task {
            if initialText.isEmpty {
                initialText = (try? STFile(configURL).read()) ?? ""
            }
        }
    }

    private func validate(_ text: String) throws {
        let data = Data(text.utf8)
        _ = try CodexGeneratedFilesParser.parseConfigToml(data: data)
    }
}
