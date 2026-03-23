import SwiftUI
import NolonUI

struct UISheetHeaderView: View {
    private enum TrailingContent {
        case close(isDisabled: Bool, onClose: () -> Void)
        case custom(() -> AnyView)
    }

    private let title: String
    private let subtitle: String?
    private let trailingContent: TrailingContent

    init(
        title: String,
        subtitle: String? = nil,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingContent = .close(isDisabled: isCloseDisabled, onClose: onClose)
    }

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingContent = .custom { AnyView(trailing()) }
    }

    var body: some View {
        switch trailingContent {
        case let .close(isDisabled, onClose):
            NolonUI.SheetHeaderView(
                title: title,
                subtitle: subtitle,
                isCloseDisabled: isDisabled,
                onClose: onClose
            )
        case let .custom(trailing):
            NolonUI.SheetHeaderView(title: title, subtitle: subtitle) {
                trailing()
            }
        }
    }
}

struct UIResourceCenterCloseButton: View {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        NolonUI.ResourceCenterCloseButton(
            help: NSLocalizedString("Close", comment: "Close"),
            enableCancelShortcut: true,
            action: action
        )
    }
}
