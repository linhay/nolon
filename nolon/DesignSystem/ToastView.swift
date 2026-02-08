import SwiftUI

struct ToastView: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            Text(text)
                .dsSecondaryText(font: .callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.Background.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: DesignSystem.Colors.Shadow.floating, radius: 16, x: 0, y: 8)
    }
}
