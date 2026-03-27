import Foundation

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
        checkUpdatesTitle: String = NSLocalizedString(
            "codex.binary.check_updates",
            value: "Check Updates",
            comment: "Check updates"
        ),
        importLocalTitle: String = NSLocalizedString(
            "codex.binary.import_local",
            value: "Import Local Binary",
            comment: "Import local"
        ),
        openGitHubTitle: String = NSLocalizedString(
            "codex.binary.github",
            value: "Open GitHub Releases",
            comment: "Open GitHub releases"
        ),
        moreActionsTitle: String = NSLocalizedString(
            "codex.binary.more_actions",
            value: "More",
            comment: "More actions"
        ),
        showBetaTitle: String = NSLocalizedString(
            "codex.binary.beta.toggle",
            value: "Show beta versions",
            comment: "Show beta versions toggle"
        ),
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
