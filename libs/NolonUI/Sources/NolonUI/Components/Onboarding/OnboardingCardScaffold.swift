import SwiftUI

public struct OnboardingCardScaffold<HeaderLeading: View, Content: View, Footer: View>: View {
    let currentStepIndex: Int
    let totalSteps: Int
    let headerLeading: () -> HeaderLeading
    let content: () -> Content
    let footer: () -> Footer

    public init(
        currentStepIndex: Int,
        totalSteps: Int,
        @ViewBuilder headerLeading: @escaping () -> HeaderLeading,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.currentStepIndex = currentStepIndex
        self.totalSteps = totalSteps
        self.headerLeading = headerLeading
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer()
        }
        .frame(width: 840, height: 620)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                )
        )
        .shadow(color: DesignSystem.Colors.Text.primary.opacity(0.10), radius: 40, x: 0, y: 20)
        .padding(40)
    }

    private var header: some View {
        HStack(spacing: 12) {
            headerLeading()

            HStack(spacing: 10) {
                ForEach(0..<max(totalSteps, 0), id: \.self) { index in
                    Capsule()
                        .fill(index == currentStepIndex ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35))
                        .frame(width: index == currentStepIndex ? 20 : 8, height: 8)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }
}
