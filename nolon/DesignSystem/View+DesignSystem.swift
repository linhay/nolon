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
            .shadow(color: DesignSystem.Colors.Shadow.floating, radius: 30, x: 0, y: 15)
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
                    .stroke(DesignSystem.Colors.Component.border.opacity(0.25), lineWidth: 1)
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

