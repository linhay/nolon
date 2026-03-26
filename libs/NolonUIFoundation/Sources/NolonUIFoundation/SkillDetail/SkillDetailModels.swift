import Foundation

public enum SkillDetailMode: Equatable, Sendable {
    case local
    case remoteInstalled
    case remoteCatalog
}

public enum SkillDetailContentMode: Equatable, Sendable {
    case fileBrowser
    case remoteOverview
}

public enum SkillDetailFileType: Equatable, Sendable {
    case markdown
    case code
    case image
    case other
}

public struct SkillDetailFile: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let type: SkillDetailFileType
    public let content: String
    public let baseURL: URL?

    public init(
        id: String,
        name: String,
        type: SkillDetailFileType,
        content: String,
        baseURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.content = content
        self.baseURL = baseURL
    }
}

public struct SkillDetailMetadataRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct SkillDetailRemoteStats: Equatable, Sendable {
    public let stars: Int?
    public let downloads: Int?

    public init(stars: Int?, downloads: Int?) {
        self.stars = stars
        self.downloads = downloads
    }
}

public struct SkillDetailProviderItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let logoName: String?

    public init(id: String, name: String, logoName: String? = nil) {
        self.id = id
        self.name = name
        self.logoName = logoName
    }
}

public struct SkillDetailViewData: Equatable, Sendable {
    public let mode: SkillDetailMode
    public let contentMode: SkillDetailContentMode
    public let title: String
    public let detailDescription: String
    public let version: String
    public let contentTitle: String
    public let showsLocalBadge: Bool
    public let showsFileNavigator: Bool
    public let showsRevealInFinder: Bool
    public let showsSyncSection: Bool
    public let isWorkflowLinked: Bool
    public let files: [SkillDetailFile]
    public let selectedFileID: String?
    public let aboutMetadataRows: [SkillDetailMetadataRow]
    public let remoteStats: SkillDetailRemoteStats?
    public let remoteChangelog: String?
    public let remoteSummary: String?
    public let providers: [SkillDetailProviderItem]
    public let currentProviderID: String?
    public let providerInstallationStates: [String: Bool]

    public init(
        mode: SkillDetailMode,
        contentMode: SkillDetailContentMode,
        title: String,
        detailDescription: String,
        version: String,
        contentTitle: String,
        showsLocalBadge: Bool,
        showsFileNavigator: Bool,
        showsRevealInFinder: Bool,
        showsSyncSection: Bool,
        isWorkflowLinked: Bool,
        files: [SkillDetailFile],
        selectedFileID: String?,
        aboutMetadataRows: [SkillDetailMetadataRow],
        remoteStats: SkillDetailRemoteStats?,
        remoteChangelog: String?,
        remoteSummary: String?,
        providers: [SkillDetailProviderItem],
        currentProviderID: String?,
        providerInstallationStates: [String: Bool]
    ) {
        self.mode = mode
        self.contentMode = contentMode
        self.title = title
        self.detailDescription = detailDescription
        self.version = version
        self.contentTitle = contentTitle
        self.showsLocalBadge = showsLocalBadge
        self.showsFileNavigator = showsFileNavigator
        self.showsRevealInFinder = showsRevealInFinder
        self.showsSyncSection = showsSyncSection
        self.isWorkflowLinked = isWorkflowLinked
        self.files = files
        self.selectedFileID = selectedFileID
        self.aboutMetadataRows = aboutMetadataRows
        self.remoteStats = remoteStats
        self.remoteChangelog = remoteChangelog
        self.remoteSummary = remoteSummary
        self.providers = providers
        self.currentProviderID = currentProviderID
        self.providerInstallationStates = providerInstallationStates
    }
}
