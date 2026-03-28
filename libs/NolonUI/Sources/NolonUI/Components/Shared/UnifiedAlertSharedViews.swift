import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - ConfirmationAlertPresenter.swift"

public struct ConfirmationAlertPresenter: ViewModifier {
    let data: ConfirmationAlertData
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public struct Config {
        public var data: ConfirmationAlertData
        public var onConfirm: () -> Void
        public var onCancel: () -> Void

        public init(
            data: ConfirmationAlertData,
            onConfirm: @escaping () -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.data = data
            self.onConfirm = onConfirm
            self.onCancel = onCancel
        }
    }

    public init(
        isPresented: Binding<Bool>,
        config: Config
    ) {
        self.data = config.data
        self._isPresented = isPresented
        self.onConfirm = config.onConfirm
        self.onCancel = config.onCancel
    }

    public init(
        data: ConfirmationAlertData,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            isPresented: isPresented,
            config: Config(
                data: data,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
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

// MARK: - DestructiveConfirmationDialogPresenter.swift"

public struct DestructiveConfirmationDialogPresenter: ViewModifier {
    let data: DestructiveConfirmationDialogData
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public struct Config {
        public var data: DestructiveConfirmationDialogData
        public var onConfirm: () -> Void
        public var onCancel: () -> Void

        public init(
            data: DestructiveConfirmationDialogData,
            onConfirm: @escaping () -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.data = data
            self.onConfirm = onConfirm
            self.onCancel = onCancel
        }
    }

    public init(
        isPresented: Binding<Bool>,
        config: Config
    ) {
        self.data = config.data
        self._isPresented = isPresented
        self.onConfirm = config.onConfirm
        self.onCancel = config.onCancel
    }

    public init(
        data: DestructiveConfirmationDialogData,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            isPresented: isPresented,
            config: Config(
                data: data,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
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

// MARK: - MessageAlertPresenter.swift"

public struct MessageAlertPresenter: ViewModifier {
    let title: String
    @Binding var message: String?
    let okTitle: String

    public struct Config {
        public var title: String
        public var okTitle: String

        public init(
            title: String,
            okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
        ) {
            self.title = title
            self.okTitle = okTitle
        }
    }

    public init(
        message: Binding<String?>,
        config: Config
    ) {
        self.title = config.title
        self._message = message
        self.okTitle = config.okTitle
    }

    public init(
        title: String,
        message: Binding<String?>,
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
    ) {
        self.init(
            message: message,
            config: Config(
                title: title,
                okTitle: okTitle
            )
        )
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

    public struct Config {
        public var okTitle: String

        public init(
            okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
        ) {
            self.okTitle = okTitle
        }
    }

    public init(
        alert: Binding<MessageAlertData?>,
        config: Config
    ) {
        self._alert = alert
        self.okTitle = config.okTitle
    }

    public init(
        alert: Binding<MessageAlertData?>,
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK")
    ) {
        self.init(
            alert: alert,
            config: Config(okTitle: okTitle)
        )
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

    public struct Config {
        public var title: String
        public var copyTitle: String
        public var okTitle: String
        public var onCopy: (String) -> Void

        public init(
            title: String,
            copyTitle: String = NSLocalizedString("generic.copy", value: "Copy", comment: "Copy"),
            okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK"),
            onCopy: @escaping (String) -> Void
        ) {
            self.title = title
            self.copyTitle = copyTitle
            self.okTitle = okTitle
            self.onCopy = onCopy
        }
    }

    public init(
        message: Binding<String?>,
        config: Config
    ) {
        self.title = config.title
        self._message = message
        self.copyTitle = config.copyTitle
        self.okTitle = config.okTitle
        self.onCopy = config.onCopy
    }

    public init(
        title: String,
        message: Binding<String?>,
        copyTitle: String = NSLocalizedString("generic.copy", value: "Copy", comment: "Copy"),
        okTitle: String = NSLocalizedString("generic.ok", value: "OK", comment: "OK"),
        onCopy: @escaping (String) -> Void
    ) {
        self.init(
            message: message,
            config: Config(
                title: title,
                copyTitle: copyTitle,
                okTitle: okTitle,
                onCopy: onCopy
            )
        )
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

// MARK: - TriActionAlertPresenter.swift"

public struct TriActionAlertPresenter: ViewModifier {
    public struct Config {
        public var data: TriActionAlertData
        public var isPresented: Binding<Bool>
        public var onDestructive: () -> Void
        public var onSecondary: () -> Void
        public var onCancel: () -> Void

        public init(
            data: TriActionAlertData,
            isPresented: Binding<Bool>,
            onDestructive: @escaping () -> Void,
            onSecondary: @escaping () -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.data = data
            self.isPresented = isPresented
            self.onDestructive = onDestructive
            self.onSecondary = onSecondary
            self.onCancel = onCancel
        }
    }

    let data: TriActionAlertData
    @Binding var isPresented: Bool
    let onDestructive: () -> Void
    let onSecondary: () -> Void
    let onCancel: () -> Void

    public init(config: Config) {
        self.data = config.data
        self._isPresented = config.isPresented
        self.onDestructive = config.onDestructive
        self.onSecondary = config.onSecondary
        self.onCancel = config.onCancel
    }

    public init(
        data: TriActionAlertData,
        isPresented: Binding<Bool>,
        onDestructive: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                isPresented: isPresented,
                onDestructive: onDestructive,
                onSecondary: onSecondary,
                onCancel: onCancel
            )
        )
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
