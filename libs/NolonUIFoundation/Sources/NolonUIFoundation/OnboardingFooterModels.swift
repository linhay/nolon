import Foundation

public enum OnboardingStepKind: Sendable {
    case welcome
    case providerSelection
    case completion
}

public struct OnboardingFooterTextTone: Sendable {
    public static let warning = OnboardingFooterTextTone(rawValue: "warning")
    public static let primary = OnboardingFooterTextTone(rawValue: "primary")
    public static let secondary = OnboardingFooterTextTone(rawValue: "secondary")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct OnboardingFooterData: Sendable {
    public let step: OnboardingStepKind
    public let skipTitle: String
    public let getStartedTitle: String
    public let backTitle: String
    public let continueTitle: String
    public let startTitle: String
    public let centerHintText: String?
    public let centerHintTone: OnboardingFooterTextTone
    public let isContinueEnabled: Bool

    public init(
        step: OnboardingStepKind,
        skipTitle: String = NSLocalizedString("onboarding.button.skip", value: "Skip", comment: "Onboarding skip"),
        getStartedTitle: String = NSLocalizedString("onboarding.button.get_started", value: "Get Started", comment: "Onboarding get started"),
        backTitle: String = NSLocalizedString("onboarding.button.back", value: "Back", comment: "Onboarding back"),
        continueTitle: String = NSLocalizedString("onboarding.button.continue", value: "Continue", comment: "Onboarding continue"),
        startTitle: String = NSLocalizedString("onboarding.button.start", value: "Start", comment: "Onboarding start"),
        centerHintText: String? = nil,
        centerHintTone: OnboardingFooterTextTone = .secondary,
        isContinueEnabled: Bool = true
    ) {
        self.step = step
        self.skipTitle = skipTitle
        self.getStartedTitle = getStartedTitle
        self.backTitle = backTitle
        self.continueTitle = continueTitle
        self.startTitle = startTitle
        self.centerHintText = centerHintText
        self.centerHintTone = centerHintTone
        self.isContinueEnabled = isContinueEnabled
    }
}
