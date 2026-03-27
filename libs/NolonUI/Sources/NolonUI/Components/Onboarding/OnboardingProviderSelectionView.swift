import SwiftUI
import Observation

public struct OnboardingProviderSelectionView: View {
    @Bindable private var viewModel: OnboardingProviderSelectionViewViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    public init(viewModel: OnboardingProviderSelectionViewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(viewModel.titleKey)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(viewModel.subtitleKey)
                    .font(.system(size: 14))
                    .dsSecondaryText(font: .system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.providers) { provider in
                                    Button {
                                        viewModel.toggleSelection(id: provider.id)
                                    } label: {
                                        ProviderSelectionCard(
                                            provider: provider,
                                            isSelected: viewModel.isSelected(id: provider.id),
                                            isDetected: viewModel.isDetected(id: provider.id)
                                        )
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedProviderIDs)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

private struct ProviderSelectionCard: View {
    let provider: OnboardingProviderSelectionViewViewModel.ProviderItem
    let isSelected: Bool
    let isDetected: Bool

    var body: some View {
        VStack(spacing: 12) {
            ProviderLogoView(
                name: provider.name,
                logoName: provider.logoName,
                iconSize: 32
            )
            .grayscale(isSelected ? 0 : 1)
            .opacity(isSelected ? 1 : 0.6)

            VStack(spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                    .lineLimit(1)

                if isDetected {
                    Text("onboarding.provider.detected")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.primary.opacity(0.12))
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.Metrics.cornerRadiusXS)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.10) : DesignSystem.Colors.Background.surface.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? DesignSystem.Colors.primary.opacity(0.35) : DesignSystem.Colors.Component.border.opacity(0.22), lineWidth: 1)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

#Preview {
    OnboardingProviderSelectionView(
        viewModel: OnboardingProviderSelectionViewViewModel(
            subtitleKey: "onboarding.provider.subtitle_detected",
            sections: [
                .init(
                    id: "popular",
                    title: "Popular",
                    providers: [
                        .init(id: "claude", name: "Claude", logoName: "claude"),
                        .init(id: "codex", name: "Codex", logoName: "codex"),
                        .init(id: "gemini", name: "Gemini", logoName: "gemini")
                    ]
                )
            ],
            selectedProviderIDs: ["claude", "gemini"],
            detectedProviderIDs: ["claude", "gemini", "opencode"],
            onToggleProvider: { _ in }
        )
    )
    .frame(width: 600, height: 500)
}
