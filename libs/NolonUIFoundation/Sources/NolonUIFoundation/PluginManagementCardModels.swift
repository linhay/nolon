import Foundation

public struct PluginManagementCardData: Sendable {
    public let name: String
    public let runtimeActionTitle: String
    public let runtimeActionEnabled: Bool
    public let logsTitle: String
    public let showsUpgradeButton: Bool
    public let upgradeActionTitle: String
    public let upgradeActionEnabled: Bool
    public let openReleaseTitle: String
    public let showsUninstallButton: Bool
    public let uninstallActionTitle: String
    public let uninstallActionEnabled: Bool
    public let statusText: String
    public let installedText: String
    public let latestText: String
    public let runtimeStatusText: String

    public init(
        name: String,
        runtimeActionTitle: String,
        runtimeActionEnabled: Bool,
        logsTitle: String,
        showsUpgradeButton: Bool,
        upgradeActionTitle: String,
        upgradeActionEnabled: Bool,
        openReleaseTitle: String,
        showsUninstallButton: Bool,
        uninstallActionTitle: String,
        uninstallActionEnabled: Bool,
        statusText: String,
        installedText: String,
        latestText: String,
        runtimeStatusText: String
    ) {
        self.name = name
        self.runtimeActionTitle = runtimeActionTitle
        self.runtimeActionEnabled = runtimeActionEnabled
        self.logsTitle = logsTitle
        self.showsUpgradeButton = showsUpgradeButton
        self.upgradeActionTitle = upgradeActionTitle
        self.upgradeActionEnabled = upgradeActionEnabled
        self.openReleaseTitle = openReleaseTitle
        self.showsUninstallButton = showsUninstallButton
        self.uninstallActionTitle = uninstallActionTitle
        self.uninstallActionEnabled = uninstallActionEnabled
        self.statusText = statusText
        self.installedText = installedText
        self.latestText = latestText
        self.runtimeStatusText = runtimeStatusText
    }
}
