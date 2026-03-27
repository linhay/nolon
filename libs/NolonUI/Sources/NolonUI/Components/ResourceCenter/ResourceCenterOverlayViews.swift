import SwiftUI
import NolonUIFoundation

public struct ResourceCenterImportWarningOverlay: View {
    let message: String
    let onDismiss: () -> Void

    public init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        DismissibleWarningBannerView(message: message, onDismiss: onDismiss)
            .padding(.horizontal, 16)
            .padding(.top, 10)
    }
}

public struct ResourceCenterUITestActionsOverlay: View {
    let actions: [ResourceCenterUITestActionData]
    let onTapAction: (ResourceCenterUITestActionData) -> Void

    public init(
        actions: [ResourceCenterUITestActionData],
        onTapAction: @escaping (ResourceCenterUITestActionData) -> Void
    ) {
        self.actions = actions
        self.onTapAction = onTapAction
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(actions) { action in
                Button(action.title) {
                    onTapAction(action)
                }
                .accessibilityIdentifier(action.accessibilityIdentifier)
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}

public extension View {
    func resourceCenterOverlays(
        importErrorMessage: String?,
        onDismissImportError: @escaping () -> Void,
        uiTestActions: [ResourceCenterUITestActionData],
        onTapUITestAction: @escaping (ResourceCenterUITestActionData) -> Void
    ) -> some View {
        self
            .overlay(alignment: .top) {
                if let message = importErrorMessage, !message.isEmpty {
                    ResourceCenterImportWarningOverlay(
                        message: message,
                        onDismiss: onDismissImportError
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if !uiTestActions.isEmpty {
                    ResourceCenterUITestActionsOverlay(
                        actions: uiTestActions,
                        onTapAction: onTapUITestAction
                    )
                }
            }
    }
}
