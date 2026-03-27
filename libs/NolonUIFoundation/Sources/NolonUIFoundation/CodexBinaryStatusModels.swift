import Foundation

public struct CodexBinaryStatusHeaderData: Equatable, Sendable {
    public let hasUpdateAvailable: Bool
    public let statusText: String
    public let currentCLITitle: String
    public let currentCLIVersion: String
    public let isSyncingRemoteVersions: Bool
    public let remoteVersionSyncFailed: Bool
    public let syncingText: String
    public let failedText: String

    public init(
        hasUpdateAvailable: Bool,
        statusText: String,
        currentCLITitle: String = NSLocalizedString(
            "codex.binary.cli_version",
            value: "Current CLI",
            comment: "Current CLI version"
        ),
        currentCLIVersion: String,
        isSyncingRemoteVersions: Bool,
        remoteVersionSyncFailed: Bool,
        syncingText: String = NSLocalizedString(
            "codex.binary.update.checking",
            value: "Checking updates...",
            comment: "Update status"
        ),
        failedText: String = NSLocalizedString(
            "codex.binary.update.failed",
            value: "Update check failed",
            comment: "Update status"
        )
    ) {
        self.hasUpdateAvailable = hasUpdateAvailable
        self.statusText = statusText
        self.currentCLITitle = currentCLITitle
        self.currentCLIVersion = currentCLIVersion
        self.isSyncingRemoteVersions = isSyncingRemoteVersions
        self.remoteVersionSyncFailed = remoteVersionSyncFailed
        self.syncingText = syncingText
        self.failedText = failedText
    }
}
