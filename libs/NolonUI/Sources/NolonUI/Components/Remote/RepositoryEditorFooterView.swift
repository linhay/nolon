import SwiftUI
import NolonUIFoundation

public struct RepositoryEditorFooterView: View {
    let data: RepositoryEditorFooterData
    let onCancel: () -> Void
    let onPrimary: () -> Void

    public init(
        data: RepositoryEditorFooterData,
        onCancel: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.data = data
        self.onCancel = onCancel
        self.onPrimary = onPrimary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage = data.errorMessage {
                Text(errorMessage)
                    .dsErrorText(font: .system(size: 12))
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            }

            SheetActionFooterView(
                cancelTitle: data.cancelTitle,
                primaryTitle: data.primaryTitle,
                isPrimaryDisabled: data.isPrimaryDisabled,
                onCancel: onCancel,
                onPrimary: onPrimary
            )
        }
    }
}
