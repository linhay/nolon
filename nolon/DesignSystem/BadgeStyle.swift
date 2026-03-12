import SwiftUI

// MARK: - Badge Style

extension DesignSystem {
    struct BadgeColors {
        let foreground: Color
        let background: Color
    }
}

private struct DSBadgeModifier: ViewModifier {
    let colors: DesignSystem.BadgeColors
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.caption2)
            .foregroundStyle(colors.foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(colors.background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func dsBadge(
        foreground: Color,
        background: Color,
        horizontalPadding: CGFloat = DesignSystem.Metrics.badgePaddingHorizontal,
        verticalPadding: CGFloat = DesignSystem.Metrics.badgePaddingVertical,
        cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusXL
    ) -> some View {
        modifier(DSBadgeModifier(
            colors: DesignSystem.BadgeColors(foreground: foreground, background: background),
            cornerRadius: cornerRadius,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }

    func dsBadgeBorder(
        foreground: Color,
        background: Color,
        borderColor: Color,
        borderWidth: CGFloat = 1,
        horizontalPadding: CGFloat = DesignSystem.Metrics.badgePaddingHorizontal,
        verticalPadding: CGFloat = DesignSystem.Metrics.badgePaddingVertical,
        cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusXL
    ) -> some View {
        dsBadge(
            foreground: foreground,
            background: background,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            cornerRadius: cornerRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }
}
