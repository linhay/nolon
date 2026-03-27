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

    private var highlight: NolonUI.WebCodeEditorHighlight? {
        guard let highlightKey else { return nil }
        return NolonUI.WebCodeEditorHighlight(format: format, key: highlightKey)
    }

    var body: some View {
        NolonUI.CodeEditorSheetView(
            title: NSLocalizedString("mcp.editor.title", value: "Edit MCP", comment: "MCP editor title"),
            initialTextLoader: {
                (try? STFile(configURL).read()) ?? ""
            },
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
