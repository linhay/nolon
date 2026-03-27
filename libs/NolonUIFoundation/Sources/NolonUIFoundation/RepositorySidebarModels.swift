import Foundation

public enum RepositorySyncStatusData {
    case syncing
    case lastSynced(Date)
    case notSynced(String)
}

public struct RepositorySidebarRowData: Identifiable {
    public let id: String
    public let title: String
    public let secondaryText: String?
    public let logoName: String?
    public let fallbackSystemIconName: String
    public let showGitStatus: Bool
    public let syncStatus: RepositorySyncStatusData?
    public let isBuiltIn: Bool
    public let builtInText: String

    public init(
        id: String,
        title: String,
        secondaryText: String?,
        logoName: String?,
        fallbackSystemIconName: String,
        showGitStatus: Bool,
        syncStatus: RepositorySyncStatusData?,
        isBuiltIn: Bool,
        builtInText: String = NSLocalizedString("Built-in", comment: "Built-in repository badge")
    ) {
        self.id = id
        self.title = title
        self.secondaryText = secondaryText
        self.logoName = logoName
        self.fallbackSystemIconName = fallbackSystemIconName
        self.showGitStatus = showGitStatus
        self.syncStatus = syncStatus
        self.isBuiltIn = isBuiltIn
        self.builtInText = builtInText
    }
}
