import SwiftUI
import NolonUIFoundation

public struct TriActionAlertPresenter: ViewModifier {
    let data: TriActionAlertData
    @Binding var isPresented: Bool
    let onDestructive: () -> Void
    let onSecondary: () -> Void
    let onCancel: () -> Void

    public init(
        data: TriActionAlertData,
        isPresented: Binding<Bool>,
        onDestructive: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.data = data
        self._isPresented = isPresented
        self.onDestructive = onDestructive
        self.onSecondary = onSecondary
        self.onCancel = onCancel
    }

    public func body(content: Content) -> some View {
        content.alert(
            data.title,
            isPresented: $isPresented
        ) {
            Button(data.destructiveTitle, role: .destructive) {
                onDestructive()
            }
            Button(data.secondaryTitle) {
                onSecondary()
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
    func triActionAlert(
        data: TriActionAlertData,
        isPresented: Binding<Bool>,
        onDestructive: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(
            TriActionAlertPresenter(
                data: data,
                isPresented: isPresented,
                onDestructive: onDestructive,
                onSecondary: onSecondary,
                onCancel: onCancel
            )
        )
    }
}
