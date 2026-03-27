import SwiftUI

public struct ResourceCatalogGridOverlayScaffold<Content: View, Overlay: View>: View {
    let contentPadding: EdgeInsets
    let showOverlay: Bool
    let content: () -> Content
    let overlay: () -> Overlay

    public init(
        contentPadding: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16),
        showOverlay: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.contentPadding = contentPadding
        self.showOverlay = showOverlay
        self.content = content
        self.overlay = overlay
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaddedScrollContainer(
                padding: contentPadding
            ) {
                content()
            }
        }
        .bottomTrailingOverlay(isPresented: showOverlay) {
            overlay()
        }
    }
}
