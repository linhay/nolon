import Foundation

public struct UpdatesSheetContentData: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let availableCountText: String?
    public let refreshHelpText: String
    public let closeAccessibilityLabel: String
    public let emptyTitle: String
    public let emptySystemImage: String
    public let emptyDescription: String
    public let isChecking: Bool
    public let rows: [SkillUpdateRowData]

    public init(
        title: String,
        subtitle: String? = nil,
        availableCountText: String? = nil,
        refreshHelpText: String = NSLocalizedString(
            "updates.refresh_help_text",
            value: "Check for updates",
            comment: "Check for updates button help text"
        ),
        closeAccessibilityLabel: String = NSLocalizedString(
            "generic.close",
            value: "Close",
            comment: "Close accessibility label"
        ),
        emptyTitle: String = NSLocalizedString(
            "updates.empty_title",
            value: "All skills up to date",
            comment: "All skills up to date"
        ),
        emptySystemImage: String = "checkmark.circle.fill",
        emptyDescription: String = NSLocalizedString(
            "updates.empty_description",
            value: "No updates available.",
            comment: "No updates available"
        ),
        isChecking: Bool,
        rows: [SkillUpdateRowData]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.availableCountText = availableCountText
        self.refreshHelpText = refreshHelpText
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.isChecking = isChecking
        self.rows = rows
    }
}
