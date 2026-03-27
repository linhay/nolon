public struct SkillUpdateRowData: Identifiable, Equatable, Sendable {
    public let id: String
    public let skillName: String
    public let sourceLabel: String
    public let sourceSystemImage: String
    public let currentVersionText: String?
    public let latestVersionText: String?
    public let hasUpdate: Bool
    public let updateButtonTitle: String
    public let upToDateText: String

    public init(
        id: String,
        skillName: String,
        sourceLabel: String,
        sourceSystemImage: String,
        currentVersionText: String?,
        latestVersionText: String?,
        hasUpdate: Bool,
        updateButtonTitle: String,
        upToDateText: String
    ) {
        self.id = id
        self.skillName = skillName
        self.sourceLabel = sourceLabel
        self.sourceSystemImage = sourceSystemImage
        self.currentVersionText = currentVersionText
        self.latestVersionText = latestVersionText
        self.hasUpdate = hasUpdate
        self.updateButtonTitle = updateButtonTitle
        self.upToDateText = upToDateText
    }
}
