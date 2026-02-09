import SwiftUI

extension View {
    func providerTabCardStyle(isSelected: Bool = false) -> some View {
        dsCard(
            background: isSelected ? DesignSystem.Colors.primary.opacity(0.10) : DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusL,
            borderColor: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.60),
            borderWidth: isSelected ? 2 : 1
        )
    }
}
