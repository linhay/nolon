import Foundation

public enum SettingsActionCardTrailingTone: Sendable {
    case secondary
    case warning
}

public struct SettingsActionCardData: Sendable {
    public let leadingSystemImage: String?
    public let isLeadingLoading: Bool
    public let title: String
    public let trailingText: String?
    public let trailingTone: SettingsActionCardTrailingTone

    public init(
        leadingSystemImage: String?,
        isLeadingLoading: Bool = false,
        title: String,
        trailingText: String? = nil,
        trailingTone: SettingsActionCardTrailingTone = .secondary
    ) {
        self.leadingSystemImage = leadingSystemImage
        self.isLeadingLoading = isLeadingLoading
        self.title = title
        self.trailingText = trailingText
        self.trailingTone = trailingTone
    }
}

public extension SettingsActionCardData {
    static func onboardingRerun(
        leadingSystemImage: String? = "arrow.counterclockwise",
        trailingTone: SettingsActionCardTrailingTone = .secondary
    ) -> SettingsActionCardData {
        SettingsActionCardData(
            leadingSystemImage: leadingSystemImage,
            title: NSLocalizedString(
                "settings.onboarding.rerun",
                value: "Run onboarding again",
                comment: "Rerun onboarding action title"
            ),
            trailingText: NSLocalizedString(
                "settings.onboarding.description",
                value: "Refresh agents & project picks",
                comment: "Rerun onboarding action description"
            ),
            trailingTone: trailingTone
        )
    }
}
