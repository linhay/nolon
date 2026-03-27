import SwiftUI

public struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DesignSystem.Colors.Background.surface)
            .frame(height: 44)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                    .fill(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35))
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

public struct OnboardingSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsSecondaryText(font: .body)
            .frame(height: 44)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}
