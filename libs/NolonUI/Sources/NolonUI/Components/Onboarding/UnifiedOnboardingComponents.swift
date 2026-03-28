import NolonUIFoundation
import SwiftUI

// MARK: - OnboardingWelcomeView

public struct OnboardingWelcomeView: View {
    public struct Config {
        public var viewModel: OnboardingWelcomeViewViewModel

        public init(viewModel: OnboardingWelcomeViewViewModel) {
            self.viewModel = viewModel
        }
    }

    @Bindable private var viewModel: OnboardingWelcomeViewViewModel

    public init(config: Config) {
        self.viewModel = config.viewModel
    }

    public init(viewModel: OnboardingWelcomeViewViewModel) {
        self.init(config: Config(viewModel: viewModel))
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


// MARK: - OnboardingProviderSelectionView

public struct OnboardingProviderSelectionView: View {
    public struct Config {
        public var viewModel: OnboardingProviderSelectionViewViewModel

        public init(viewModel: OnboardingProviderSelectionViewViewModel) {
            self.viewModel = viewModel
        }
    }

    @Bindable private var viewModel: OnboardingProviderSelectionViewViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    public init(config: Config) {
        self.viewModel = config.viewModel
    }

    public init(viewModel: OnboardingProviderSelectionViewViewModel) {
        self.init(config: Config(viewModel: viewModel))
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


// MARK: - OnboardingCompletionView

public struct OnboardingCompletionView: View {
    public struct Config {
        public var viewModel: OnboardingCompletionViewViewModel

        public init(viewModel: OnboardingCompletionViewViewModel) {
            self.viewModel = viewModel
        }
    }

    @Bindable private var viewModel: OnboardingCompletionViewViewModel
    @State private var showCheckmark = false

    public init(config: Config) {
        self.viewModel = config.viewModel
    }

    public init(viewModel: OnboardingCompletionViewViewModel) {
        self.init(config: Config(viewModel: viewModel))
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


// MARK: - UnifiedOnboardingScaffolds

public struct OnboardingPrimaryButtonStyle: ButtonStyle {
    public struct Config {
        public var isEnabled: Bool

        public init(isEnabled: Bool = true) {
            self.isEnabled = isEnabled
        }
    }

    let isEnabled: Bool

    public init(config: Config) {
        self.isEnabled = config.isEnabled
    }

    public init(isEnabled: Bool = true) {
        self.init(config: Config(isEnabled: isEnabled))
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DesignSystem.Colors.Background.surface)
            .frame(height: 44)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                    .fill(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35))
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

public struct OnboardingSecondaryButtonStyle: ButtonStyle {
    public struct Config {
        public init() {}
    }

    public init(config: Config) {}

    public init() {
        self.init(config: Config())
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsSecondaryText(font: .body)
            .frame(height: 44)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

public struct OnboardingFooterBar<Content: View>: View {
    public struct Config {
        public var content: () -> Content

        public init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
    }

    let content: () -> Content

    public init(config: Config) {
        self.content = config.content
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.init(config: Config(content: content))
    }

    public var body: some View {
        content()
            .padding(24)
            .background(
                Rectangle()
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.55))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(DesignSystem.Colors.Component.separator.opacity(0.25)),
                        alignment: .top
                    )
            )
    }
}

public struct OnboardingStepFooterView: View {
    public struct Config {
        public var data: OnboardingFooterData
        public var onSkip: () -> Void
        public var onBack: () -> Void
        public var onNext: () -> Void
        public var onStart: () -> Void

        public init(
            data: OnboardingFooterData,
            onSkip: @escaping () -> Void,
            onBack: @escaping () -> Void,
            onNext: @escaping () -> Void,
            onStart: @escaping () -> Void
        ) {
            self.data = data
            self.onSkip = onSkip
            self.onBack = onBack
            self.onNext = onNext
            self.onStart = onStart
        }
    }

    let data: OnboardingFooterData
    let onSkip: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onStart: () -> Void

    public init(config: Config) {
        self.data = config.data
        self.onSkip = config.onSkip
        self.onBack = config.onBack
        self.onNext = config.onNext
        self.onStart = config.onStart
    }

    public init(
        data: OnboardingFooterData,
        onSkip: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onStart: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onSkip: onSkip,
                onBack: onBack,
                onNext: onNext,
                onStart: onStart
            )
        )
    }

    public var body: some View {
        OnboardingFooterBar {
            HStack(spacing: 12) {
                switch data.step {
                case .welcome:
                    Button(action: onSkip) {
                        Text(data.skipTitle)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())

                    Spacer()

                    Button(action: onNext) {
                        Text(data.getStartedTitle)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())

                case .providerSelection:
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text(data.backTitle)
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())

                    Spacer()

                    if let centerHintText = data.centerHintText, !centerHintText.isEmpty {
                        Text(centerHintText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(centerHintColor)
                    }

                    Spacer()

                    Button(action: onNext) {
                        HStack(spacing: 8) {
                            Text(data.continueTitle)
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: data.isContinueEnabled))
                    .disabled(!data.isContinueEnabled)

                case .completion:
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text(data.backTitle)
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())

                    Spacer()

                    Button(action: onStart) {
                        Text(data.startTitle)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                }
            }
        }
    }

    private var centerHintColor: Color {
        switch data.centerHintTone.rawValue {
        case OnboardingFooterTextTone.warning.rawValue:
            return DesignSystem.Colors.Status.warning
        case OnboardingFooterTextTone.primary.rawValue:
            return DesignSystem.Colors.primary
        default:
            return DesignSystem.Colors.Text.secondary
        }
    }
}

public struct OnboardingCardScaffold<HeaderLeading: View, Content: View, Footer: View>: View {
    public struct Config {
        public var currentStepIndex: Int
        public var totalSteps: Int
        public var headerLeading: () -> HeaderLeading
        public var content: () -> Content
        public var footer: () -> Footer

        public init(
            currentStepIndex: Int,
            totalSteps: Int,
            @ViewBuilder headerLeading: @escaping () -> HeaderLeading,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder footer: @escaping () -> Footer
        ) {
            self.currentStepIndex = currentStepIndex
            self.totalSteps = totalSteps
            self.headerLeading = headerLeading
            self.content = content
            self.footer = footer
        }
    }

    let currentStepIndex: Int
    let totalSteps: Int
    let headerLeading: () -> HeaderLeading
    let content: () -> Content
    let footer: () -> Footer

    public init(config: Config) {
        self.currentStepIndex = config.currentStepIndex
        self.totalSteps = config.totalSteps
        self.headerLeading = config.headerLeading
        self.content = config.content
        self.footer = config.footer
    }

    public init(
        currentStepIndex: Int,
        totalSteps: Int,
        @ViewBuilder headerLeading: @escaping () -> HeaderLeading,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            config: Config(
                currentStepIndex: currentStepIndex,
                totalSteps: totalSteps,
                headerLeading: headerLeading,
                content: content,
                footer: footer
            )
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer()
        }
        .frame(width: 840, height: 620)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                )
        )
        .shadow(color: DesignSystem.Colors.Text.primary.opacity(0.10), radius: 40, x: 0, y: 20)
        .padding(40)
    }

    private var header: some View {
        HStack(spacing: 12) {
            headerLeading()

            HStack(spacing: 10) {
                ForEach(0..<max(totalSteps, 0), id: \.self) { index in
                    Capsule()
                        .fill(index == currentStepIndex ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35))
                        .frame(width: index == currentStepIndex ? 20 : 8, height: 8)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }
}
