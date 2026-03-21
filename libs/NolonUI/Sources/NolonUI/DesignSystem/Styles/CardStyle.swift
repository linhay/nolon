import SwiftUI

extension DesignSystem {
    public struct CardShadow {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }

        public static var none: CardShadow { CardShadow(color: .clear, radius: 0, x: 0, y: 0) }
        public static var subtle: CardShadow {
            CardShadow(
                color: DesignSystem.Colors.Shadow.floating.opacity(0.35),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        public static var small: CardShadow {
            CardShadow(
                color: DesignSystem.Colors.Shadow.floating,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        public static var medium: CardShadow {
            CardShadow(
                color: DesignSystem.Colors.Shadow.floating,
                radius: 12,
                x: 0,
                y: 6
            )
        }
        public static var large: CardShadow {
            CardShadow(
                color: DesignSystem.Colors.Shadow.floating,
                radius: 16,
                x: 0,
                y: 8
            )
        }
        public static var floating: CardShadow {
            CardShadow(
                color: DesignSystem.Colors.Shadow.floating,
                radius: 20,
                x: 0,
                y: 10
            )
        }
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

public extension View {
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
