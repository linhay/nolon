import SwiftUI
import NolonUIFoundation

public struct DestructiveConfirmationDialogPresenter: ViewModifier {
    let data: DestructiveConfirmationDialogData
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        data: DestructiveConfirmationDialogData,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.data = data
        self._isPresented = isPresented
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public func body(content: Content) -> some View {
        content.confirmationDialog(
            data.title,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(data.confirmTitle, role: .destructive) {
                onConfirm()
            }
            Button(data.cancelTitle, role: .cancel) {
                onCancel()
            }
        } message: {
            Text(data.message)
        }
    }
}

public extension View {
    func destructiveConfirmationDialog(
        data: DestructiveConfirmationDialogData,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(
            DestructiveConfirmationDialogPresenter(
                data: data,
                isPresented: isPresented,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }
}
