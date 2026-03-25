import SwiftUI
import STFilePath

struct RuleMarkdownEditorView: View {
    let ruleURL: URL
    let onSave: (String) async -> Void

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
            .navigationTitle(NSLocalizedString("tab.rules", value: "Rules", comment: "Rules"))
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
                NSLocalizedString("generic.error", value: "Error", comment: "Generic error title"),
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
                initialText = (try? STFile(ruleURL).read()) ?? ""
                bridge.setText(initialText)
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let text = try await bridge.requestText()
            try STFile(ruleURL).overlay(with: text)
            await onSave(text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
