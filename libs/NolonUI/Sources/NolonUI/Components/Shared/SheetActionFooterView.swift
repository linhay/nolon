import SwiftUI

public struct SheetActionFooterView: View {
    let cancelTitle: String
    let primaryTitle: String
    let isPrimaryDisabled: Bool
    let onCancel: () -> Void
    let onPrimary: () -> Void

    public init(
        cancelTitle: String = NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
        primaryTitle: String,
        isPrimaryDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.primaryTitle = primaryTitle
        self.isPrimaryDisabled = isPrimaryDisabled
        self.onCancel = onCancel
        self.onPrimary = onPrimary
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(cancelTitle) {
                onCancel()
            }
            .dsLinkButton()

            Spacer(minLength: 0)

            Button(primaryTitle) {
                onPrimary()
            }
            .dsPrimaryButton()
            .disabled(isPrimaryDisabled)
        }
        .padding(.horizontal, SheetLayout.footerHorizontalPadding)
        .padding(.vertical, SheetLayout.footerVerticalPadding)
    }
}
