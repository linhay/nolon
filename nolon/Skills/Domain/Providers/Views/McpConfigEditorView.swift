import SwiftUI
import STFilePath
import STJSON
import TOML
import NolonResourceKit

struct McpConfigEditorView: View {
    let configURL: URL
    let format: WebCodeEditorFormat
    let highlightKey: String?
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var bridge = WebCodeEditorBridge()
    @State private var initialText: String = ""
    @State private var isDirty = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var highlight: WebCodeEditorHighlight? {
        guard let highlightKey else { return nil }
        return WebCodeEditorHighlight(format: format, key: highlightKey)
    }

    var body: some View {
        NavigationStack {
            WebCodeEditorView(
                bridge: bridge,
                initialText: initialText,
                highlight: highlight,
                onDirtyChanged: { isDirty = $0 }
            )
            .background(DesignSystem.Colors.Background.surface)
            .navigationTitle(NSLocalizedString("mcp.editor.title", value: "Edit MCP", comment: "MCP editor title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("action.save", value: "Save", comment: "Save")) {
                        Task { await save() }
                    }
                    .disabled(!isDirty || isSaving)
                }
            }
            .alert(
                NSLocalizedString("mcp.editor.invalid_config.title", value: "Invalid Configuration", comment: "Invalid config title"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {}
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
        .frame(minWidth: 760, minHeight: 560)
        .task {
            if initialText.isEmpty {
                initialText = (try? STFile(configURL).read()) ?? ""
                bridge.setText(initialText)
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let text = try await bridge.requestText()
            try validate(text)
            try STFile(configURL).overlay(with: text)
            await onSave(text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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
