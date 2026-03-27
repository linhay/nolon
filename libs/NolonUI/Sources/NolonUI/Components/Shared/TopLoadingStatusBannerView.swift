import SwiftUI

public struct TopLoadingStatusBannerView: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }
}
