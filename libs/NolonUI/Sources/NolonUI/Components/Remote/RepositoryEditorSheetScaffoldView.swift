import SwiftUI

public struct RepositoryEditorSheetScaffoldView<Content: View, Footer: View>: View {
    let isBlocking: Bool
    let blockingMessage: String
    let content: () -> Content
    let footer: () -> Footer

    public init(
        isBlocking: Bool,
        blockingMessage: String = NSLocalizedString(
            "repository.editor.blocking.adding",
            value: "Adding repository...",
            comment: "Repository editor blocking message while adding"
        ),
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.isBlocking = isBlocking
        self.blockingMessage = blockingMessage
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content()
                    .padding(.horizontal, SheetLayout.horizontalPadding)
                    .padding(.top, SheetLayout.contentVerticalPadding)
                    .padding(.bottom, SheetLayout.contentBottomPadding)
            }

            SheetDivider()

            footer()
        }
        .frame(width: 640, height: 600)
        .textSelection(.enabled)
        .dsGlassPanel()
        .overlay {
            if isBlocking {
                BlockingProgressOverlayView(message: blockingMessage)
            }
        }
    }
}
