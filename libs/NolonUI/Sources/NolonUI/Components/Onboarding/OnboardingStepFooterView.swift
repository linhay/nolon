import SwiftUI
import NolonUIFoundation

public struct OnboardingStepFooterView: View {
    let data: OnboardingFooterData
    let onSkip: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onStart: () -> Void

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

