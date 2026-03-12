import SwiftUI

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.Component.border.opacity(0.35), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.CardShadow.floating.color,
                radius: DesignSystem.CardShadow.floating.radius,
                x: DesignSystem.CardShadow.floating.x,
                y: DesignSystem.CardShadow.floating.y
            )
    }
}

private struct FieldModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.Component.controlFillStrong)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.Component.border.opacity(DesignSystem.Colors.Opacity.low), lineWidth: 1)
            )
    }
}

extension View {
    func dsGlassPanel(cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusXL) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }

    func dsField(cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusM) -> some View {
        modifier(FieldModifier(cornerRadius: cornerRadius))
    }
}

