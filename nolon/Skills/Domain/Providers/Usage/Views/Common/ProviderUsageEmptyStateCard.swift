import SwiftUI

struct ProviderUsageEmptyStateCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let descriptionText: Text

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: descriptionText
                .dsSecondaryText(font: .body)
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .padding(24)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, alignment: .center)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            borderColor: DesignSystem.Colors.Component.border.opacity(DesignSystem.Colors.Opacity.high)
        )
    }
}
