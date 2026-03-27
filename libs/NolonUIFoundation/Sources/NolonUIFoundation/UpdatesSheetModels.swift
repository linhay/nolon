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
        refreshHelpText: String = "Check for updates",
        closeAccessibilityLabel: String = "Close",
        emptyTitle: String = "All skills up to date",
        emptySystemImage: String = "checkmark.circle.fill",
        emptyDescription: String = "No updates available.",
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
