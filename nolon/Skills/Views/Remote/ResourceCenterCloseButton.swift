import SwiftUI
import NolonUI

struct ResourceCenterCloseButton: View {
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
