import SwiftUI

struct ToastView: View {
    enum Style {
        case neutral
        case success
    }

    let text: String
    var systemImage: String?
    var style: Style = .neutral

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

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(foregroundColor)
            }
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(foregroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: DesignSystem.Colors.Shadow.floating, radius: 16, x: 0, y: 8)
    }
}
