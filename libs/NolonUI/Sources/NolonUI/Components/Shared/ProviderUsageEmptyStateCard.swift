import SwiftUI

public struct ProviderUsageEmptyStateCard: View {
    @State private var viewModel: ProviderUsageEmptyStateCardViewModel

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        descriptionText: Text
    ) {
        _viewModel = State(
            initialValue: ProviderUsageEmptyStateCardViewModel(
                title: title,
                systemImage: systemImage,
                descriptionText: descriptionText
            )
        )
    }

    public var body: some View {
        ContentUnavailableView(
            viewModel.title,
            systemImage: viewModel.systemImage,
            description: viewModel.descriptionText
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
