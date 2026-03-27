import SwiftUI

public struct CodexAdvancedEditorFooterView: View {
    let closeTitle: String
    let saveTitle: String
    let isSaveDisabled: Bool
    let onClose: () -> Void
    let onSave: () -> Void

    public init(
        closeTitle: String,
        saveTitle: String,
        isSaveDisabled: Bool,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.closeTitle = closeTitle
        self.saveTitle = saveTitle
        self.isSaveDisabled = isSaveDisabled
        self.onClose = onClose
        self.onSave = onSave
    }

    public var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            Button(closeTitle) {
                onClose()
            }
            .dsSecondaryButton()

            Button(saveTitle) {
                onSave()
            }
            .dsPrimaryButton()
            .disabled(isSaveDisabled)
        }
    }
}
