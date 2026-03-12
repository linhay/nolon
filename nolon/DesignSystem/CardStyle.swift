import SwiftUI

// MARK: - Card Style

extension DesignSystem {
    struct CardShadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let none = CardShadow(color: .clear, radius: 0, x: 0, y: 0)
        static let subtle = CardShadow(
            color: DesignSystem.Colors.Shadow.floating.opacity(0.35),
            radius: 4,
            x: 0,
            y: 2
        )
        static let small = CardShadow(
            color: DesignSystem.Colors.Shadow.floating,
            radius: 8,
            x: 0,
            y: 4
        )
        static let medium = CardShadow(
            color: DesignSystem.Colors.Shadow.floating,
            radius: 12,
            x: 0,
            y: 6
        )
        static let large = CardShadow(
            color: DesignSystem.Colors.Shadow.floating,
            radius: 16,
            x: 0,
            y: 8
        )
        static let floating = CardShadow(
            color: DesignSystem.Colors.Shadow.floating,
            radius: 20,
            x: 0,
            y: 10
        )
    }
}

private struct DSCardModifier: ViewModifier {
    let background: Color
    let cornerRadius: CGFloat
    let borderColor: Color?
    let borderWidth: CGFloat
    let shadow: DesignSystem.CardShadow?

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor ?? .clear, lineWidth: borderWidth)
            )
            .shadow(
                color: shadow?.color ?? .clear,
                radius: shadow?.radius ?? 0,
                x: shadow?.x ?? 0,
                y: shadow?.y ?? 0
            )
    }
}

extension View {
    func dsCard(
        background: Color = DesignSystem.Colors.Component.controlFillSubtle,
        cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusL,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1,
        shadow: DesignSystem.CardShadow? = nil
    ) -> some View {
        modifier(DSCardModifier(
            background: background,
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            borderWidth: borderWidth,
            shadow: shadow
        ))
    }
}
