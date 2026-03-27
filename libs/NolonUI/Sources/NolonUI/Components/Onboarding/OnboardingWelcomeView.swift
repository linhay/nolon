import SwiftUI
import Observation

public struct OnboardingWelcomeView: View {
    @Bindable private var viewModel: OnboardingWelcomeViewViewModel

    public init(viewModel: OnboardingWelcomeViewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.Background.elevated.opacity(0.8))
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.Colors.Component.border.opacity(0.25), lineWidth: 1)
                        )

                    viewModel.appIcon
                        .resizable()
                        .frame(width: 100, height: 100)
                        .shadow(color: DesignSystem.Colors.Text.primary.opacity(0.10), radius: 15, y: 10)
                }

                VStack(spacing: 8) {
                    Text(viewModel.titleKey)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                    Text(viewModel.subtitleKey)
                        .font(.system(size: 16))
                        .dsSecondaryText(font: .system(size: 16))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.bottom, 60)

            VStack(spacing: 12) {
                ForEach(viewModel.featureItems) { item in
                    FeatureCard(item: item)
                }
            }
            .padding(.horizontal, 60)

            Spacer()
        }
    }
}

private struct FeatureCard: View {
    let item: OnboardingWelcomeViewViewModel.FeatureItem

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )

                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.titleKey)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(item.descriptionKey)
                    .font(.system(size: 12))
                    .dsSecondaryText(font: .system(size: 12))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingWelcomeView(
        viewModel: OnboardingWelcomeViewViewModel(
            appIcon: Image(systemName: "app.fill")
        )
    )
    .frame(width: 600, height: 500)
}
