import SwiftUI
import NolonUI
import STFilePath
import STJSON
import TOML
import NolonResourceKit

struct McpConfigEditorView: View {
    let configURL: URL
    let format: NolonUI.WebCodeEditorFormat
    let highlightKey: String?
    let onSave: (String) async -> Void

    @State private var initialText: String = ""

    private var highlight: NolonUI.WebCodeEditorHighlight? {
        guard let highlightKey else { return nil }
        return NolonUI.WebCodeEditorHighlight(format: format, key: highlightKey)
    }

    var body: some View {
        NolonUI.CodeEditorSheetView(
            title: NSLocalizedString("mcp.editor.title", value: "Edit MCP", comment: "MCP editor title"),
            initialText: initialText,
            highlight: highlight,
            invalidAlertTitle: NSLocalizedString("mcp.editor.invalid_config.title", value: "Invalid Configuration", comment: "Invalid config title"),
            onValidate: { text in
                try validate(text)
            },
            onSave: { text in
                try STFile(configURL).overlay(with: text)
                await onSave(text)
            }
        )
        .task {
            if initialText.isEmpty {
                initialText = (try? STFile(configURL).read()) ?? ""
            }
        }
    }

    private func validate(_ text: String) throws {
        switch format {
        case .json:
            guard let data = text.data(using: .utf8) else {
                throw NSError(domain: "nolon.mcp.editor", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("mcp.editor.invalid_json", value: "Invalid JSON.", comment: "Invalid JSON"),
                ])
            }
            _ = try JSON(data: data)
        case .toml:
            let data = Data(text.utf8)
            _ = try TOMLDecoder().decode(CodexMCPConfig.self, from: data)
        }
    }
}
