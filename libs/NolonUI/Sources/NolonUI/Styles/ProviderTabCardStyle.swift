import SwiftUI

extension View {
    func providerTabCardStyle(isSelected: Bool = false) -> some View {
        dsCard(
            background: isSelected
                ? DesignSystem.Colors.primary.opacity(DesignSystem.Colors.Opacity.subtle)
                : DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusL,
            borderColor: isSelected
                ? DesignSystem.Colors.primary
                : DesignSystem.Colors.Component.border.opacity(DesignSystem.Colors.Opacity.high),
            borderWidth: isSelected ? 2 : 1
        )
    }
}
