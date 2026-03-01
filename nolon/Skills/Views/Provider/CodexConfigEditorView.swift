import SwiftUI
import STFilePath
import CodexProvider

struct CodexConfigEditorView: View {
    let configURL: URL
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var bridge = WebCodeEditorBridge()
    @State private var initialText: String = ""
    @State private var isDirty = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            WebCodeEditorView(
                bridge: bridge,
                initialText: initialText,
                highlight: nil,
                onDirtyChanged: { isDirty = $0 }
            )
            .background(DesignSystem.Colors.Background.surface)
            .navigationTitle(NSLocalizedString("codex.config.editor.title", value: "Edit config.toml", comment: "Codex config editor title"))
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
                NSLocalizedString("codex.config.editor.error.title", value: "Invalid config.toml", comment: "Invalid config title"),
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
        .frame(minWidth: 860, minHeight: 620)
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
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validate(_ text: String) throws {
        let data = Data(text.utf8)
        _ = try CodexGeneratedFilesParser.parseConfigToml(data: data)
    }
}
