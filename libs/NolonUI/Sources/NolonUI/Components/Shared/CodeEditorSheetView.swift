import SwiftUI

public struct CodeEditorSheetView: View {
    let title: String
    let initialText: String
    let highlight: WebCodeEditorHighlight?
    let invalidAlertTitle: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let cancelTitle: String
    let saveTitle: String
    let okTitle: String
    let onValidate: (String) throws -> Void
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var bridge = WebCodeEditorBridge()
    @State private var isDirty = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(
        title: String,
        initialText: String,
        highlight: WebCodeEditorHighlight?,
        invalidAlertTitle: String = NSLocalizedString(
            "generic.error",
            value: "Error",
            comment: "Generic error title"
        ),
        minWidth: CGFloat = 760,
        minHeight: CGFloat = 560,
        cancelTitle: String = NSLocalizedString(
            "action.cancel",
            value: "Cancel",
            comment: "Cancel"
        ),
        saveTitle: String = NSLocalizedString(
            "action.save",
            value: "Save",
            comment: "Save"
        ),
        okTitle: String = NSLocalizedString(
            "generic.ok",
            value: "OK",
            comment: "OK"
        ),
        onValidate: @escaping (String) throws -> Void,
        onSave: @escaping (String) async throws -> Void
    ) {
        self.title = title
        self.initialText = initialText
        self.highlight = highlight
        self.invalidAlertTitle = invalidAlertTitle
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.cancelTitle = cancelTitle
        self.saveTitle = saveTitle
        self.okTitle = okTitle
        self.onValidate = onValidate
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            WebCodeEditorView(
                bridge: bridge,
                initialText: initialText,
                highlight: highlight,
                onDirtyChanged: { isDirty = $0 }
            )
            .background(DesignSystem.Colors.Background.surface)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        Task { await saveDraft() }
                    }
                    .disabled(!isDirty || isSaving)
                }
            }
            .alert(
                invalidAlertTitle,
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button(okTitle) {}
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
        .frame(minWidth: minWidth, minHeight: minHeight)
        .task(id: initialText) {
            bridge.setText(initialText)
            bridge.setHighlight(highlight)
        }
    }

    private func saveDraft() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let text = try await bridge.requestText()
            try onValidate(text)
            try await onSave(text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
