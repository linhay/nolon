import SwiftUI

public struct OnboardingFooterBar<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(24)
            .background(
                Rectangle()
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.55))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(DesignSystem.Colors.Component.separator.opacity(0.25)),
                        alignment: .top
                    )
            )
    }
}
