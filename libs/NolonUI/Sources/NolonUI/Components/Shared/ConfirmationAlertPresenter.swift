import SwiftUI
import NolonUIFoundation

public struct ConfirmationAlertPresenter: ViewModifier {
    let data: ConfirmationAlertData
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        data: ConfirmationAlertData,
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
        content.alert(
            data.title,
            isPresented: $isPresented
        ) {
            Button(data.cancelTitle, role: .cancel) {
                onCancel()
            }
            if data.isDestructiveConfirm {
                Button(data.confirmTitle, role: .destructive) {
                    onConfirm()
                }
            } else {
                Button(data.confirmTitle) {
                    onConfirm()
                }
            }
        } message: {
            Text(data.message)
        }
    }
}

public extension View {
    func confirmationAlert(
        data: ConfirmationAlertData,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(
            ConfirmationAlertPresenter(
                data: data,
                isPresented: isPresented,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }
}
