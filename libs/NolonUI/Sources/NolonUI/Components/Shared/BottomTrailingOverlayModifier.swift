import SwiftUI

private struct BottomTrailingOverlayModifier<Overlay: View>: ViewModifier {
    let isPresented: Bool
    let trailing: CGFloat
    let bottom: CGFloat
    let overlay: () -> Overlay

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isPresented {
                overlay()
                    .padding(.trailing, trailing)
                    .padding(.bottom, bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

public extension View {
    func bottomTrailingOverlay<Overlay: View>(
        isPresented: Bool,
        trailing: CGFloat = 16,
        bottom: CGFloat = 16,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) -> some View {
        modifier(
            BottomTrailingOverlayModifier(
                isPresented: isPresented,
                trailing: trailing,
                bottom: bottom,
                overlay: overlay
            )
        )
    }
}
