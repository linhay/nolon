public struct CodexBinaryActionBarData: Equatable, Sendable {
    public let primaryActionTitle: String
    public let checkUpdatesTitle: String
    public let importLocalTitle: String
    public let openGitHubTitle: String
    public let moreActionsTitle: String
    public let showBetaTitle: String
    public let isBusy: Bool
    public let showBetaEnabled: Bool

    public init(
        primaryActionTitle: String,
        checkUpdatesTitle: String,
        importLocalTitle: String,
        openGitHubTitle: String,
        moreActionsTitle: String,
        showBetaTitle: String,
        isBusy: Bool,
        showBetaEnabled: Bool
    ) {
        self.primaryActionTitle = primaryActionTitle
        self.checkUpdatesTitle = checkUpdatesTitle
        self.importLocalTitle = importLocalTitle
        self.openGitHubTitle = openGitHubTitle
        self.moreActionsTitle = moreActionsTitle
        self.showBetaTitle = showBetaTitle
        self.isBusy = isBusy
        self.showBetaEnabled = showBetaEnabled
    }
}
