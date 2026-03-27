import SwiftUI

private struct RemoteDetailSheetFrameModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(
            minWidth: 920,
            idealWidth: 1100,
            maxWidth: .infinity,
            minHeight: 620,
            idealHeight: 720,
            maxHeight: .infinity
        )
    }
}

public extension View {
    func remoteDetailSheetFrame() -> some View {
        modifier(RemoteDetailSheetFrameModifier())
    }
}
