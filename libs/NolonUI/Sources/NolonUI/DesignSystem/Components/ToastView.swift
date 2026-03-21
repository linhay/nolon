import SwiftUI

public struct ToastView: View {
    public enum Style {
        case neutral
        case success
    }

    let text: String
    var systemImage: String?
    var style: Style = .neutral

    public init(text: String, systemImage: String? = nil, style: Style = .neutral) {
        self.text = text
        self.systemImage = systemImage
        self.style = style
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral:
            return DesignSystem.Colors.Background.elevated
        case .success:
            return DesignSystem.Colors.Status.success.opacity(0.92)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .success:
            return DesignSystem.Colors.Text.onAccent
        }
    }

    private var borderColor: Color {
        switch style {
        case .neutral:
            return DesignSystem.Colors.Component.border.opacity(0.35)
        case .success:
            return DesignSystem.Colors.Status.success.opacity(0.95)
        }
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Metrics.spacingS) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(foregroundColor)
            }
            Text(text)
                .font(DesignSystem.Typography.label)
                .foregroundStyle(foregroundColor)
        }
        .padding(.horizontal, DesignSystem.Metrics.spacingM)
        .padding(.vertical, DesignSystem.Metrics.spacingS)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous))
        .shadow(
            color: DesignSystem.CardShadow.medium.color,
            radius: DesignSystem.CardShadow.medium.radius,
            x: DesignSystem.CardShadow.medium.x,
            y: DesignSystem.CardShadow.medium.y
        )
        .transition(DesignSystem.Transitions.scale)
    }
}
