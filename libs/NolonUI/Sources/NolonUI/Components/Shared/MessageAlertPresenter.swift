import SwiftUI
import NolonUIFoundation

public struct MessageAlertPresenter: ViewModifier {
    let title: String
    @Binding var message: String?
    let okTitle: String

    public init(
        title: String,
        message: Binding<String?>,
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
    ) {
        self.title = title
        self._message = message
        self.okTitle = okTitle
    }

    public func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button(okTitle) {
                message = nil
            }
        } message: {
            Text(message ?? "")
        }
    }
}

public struct DynamicMessageAlertPresenter: ViewModifier {
    @Binding var alert: MessageAlertData?
    let okTitle: String

    public init(
        alert: Binding<MessageAlertData?>,
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
    ) {
        self._alert = alert
        self.okTitle = okTitle
    }

    public func body(content: Content) -> some View {
        content.alert(
            alert?.title ?? "",
            isPresented: Binding(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            )
        ) {
            Button(okTitle) {
                alert = nil
            }
        } message: {
            Text(alert?.message ?? "")
        }
    }
}

public struct CopyableMessageAlertPresenter: ViewModifier {
    let title: String
    @Binding var message: String?
    let copyTitle: String
    let okTitle: String
    let onCopy: (String) -> Void

    public init(
        title: String,
        message: Binding<String?>,
        copyTitle: String = NSLocalizedString("generic.copy", value: "Copy", comment: "Copy"),
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK"),
        onCopy: @escaping (String) -> Void
    ) {
        self.title = title
        self._message = message
        self.copyTitle = copyTitle
        self.okTitle = okTitle
        self.onCopy = onCopy
    }

    public func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button(copyTitle) {
                onCopy(message ?? "")
            }
            Button(okTitle, role: .cancel) {
                message = nil
            }
        } message: {
            Text(message ?? "")
        }
    }
}

public extension View {
    func messageAlert(
        title: String,
        message: Binding<String?>,
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
    ) -> some View {
        modifier(
            MessageAlertPresenter(
                title: title,
                message: message,
                okTitle: okTitle
            )
        )
    }

    func messageAlert(
        alert: Binding<MessageAlertData?>,
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
    ) -> some View {
        modifier(
            DynamicMessageAlertPresenter(
                alert: alert,
                okTitle: okTitle
            )
        )
    }

    func copyableMessageAlert(
        title: String,
        message: Binding<String?>,
        copyTitle: String = NSLocalizedString("generic.copy", value: "Copy", comment: "Copy"),
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK"),
        onCopy: @escaping (String) -> Void
    ) -> some View {
        modifier(
            CopyableMessageAlertPresenter(
                title: title,
                message: message,
                copyTitle: copyTitle,
                okTitle: okTitle,
                onCopy: onCopy
            )
        )
    }
}
