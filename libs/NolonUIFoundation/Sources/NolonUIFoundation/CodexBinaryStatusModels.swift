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
        currentCLITitle: String,
        currentCLIVersion: String,
        isSyncingRemoteVersions: Bool,
        remoteVersionSyncFailed: Bool,
        syncingText: String,
        failedText: String
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
