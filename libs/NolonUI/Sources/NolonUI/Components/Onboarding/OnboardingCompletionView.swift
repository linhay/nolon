import SwiftUI
import Observation

public struct OnboardingCompletionView: View {
    @Bindable private var viewModel: OnboardingCompletionViewViewModel
    @State private var showCheckmark = false

    public init(viewModel: OnboardingCompletionViewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.Status.success.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(DesignSystem.Colors.Status.success)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                }

                VStack(spacing: 12) {
                    Text(viewModel.titleKey)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                    Text(viewModel.subtitleKey)
                        .font(.system(size: 16))
                        .dsSecondaryText(font: .system(size: 16))
                }
            }
            .padding(.bottom, 48)

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("onboarding.completion.providers_configured \(viewModel.providers.count)")
                        .font(.system(size: 14, weight: .bold))
                        .dsSecondaryText(font: .system(size: 14, weight: .bold))
                    Spacer()
                }

                HStack(spacing: -8) {
                    ForEach(viewModel.providers.prefix(viewModel.avatarLimit)) { item in
                        ProviderLogoView(name: item.name, logoName: item.logoName, iconSize: 24)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.8))
                                    .overlay(Circle().stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 2))
                            )
                    }

                    if viewModel.providers.count > viewModel.avatarLimit {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.Background.elevated.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 2))

                            Text("onboarding.completion.more_providers \(viewModel.providers.count - viewModel.avatarLimit)")
                                .font(.system(size: 10, weight: .bold))
                                .dsSecondaryText(font: .system(size: 10, weight: .bold))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.tipsTitleKey)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                    ForEach(viewModel.tips) { tip in
                        TipRow(icon: tip.icon, textKey: tip.textKey)
                    }
                }
            }
            .padding(24)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.Background.surface.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )
            )

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

private struct TipRow: View {
    let icon: String
    let textKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(width: 20)

            Text(textKey)
                .font(.system(size: 12))
                .dsSecondaryText(font: .system(size: 12))

            Spacer()
        }
    }
}

#Preview {
    OnboardingCompletionView(
        viewModel: OnboardingCompletionViewViewModel(
            providers: [
                .init(id: "claude", name: "Claude", logoName: "claude"),
                .init(id: "gemini", name: "Gemini", logoName: "gemini"),
                .init(id: "opencode", name: "OpenCode", logoName: "opencode")
            ]
        )
    )
    .frame(width: 800, height: 600)
}
