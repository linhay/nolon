public enum RepositoryEditorTemplateKind: String, Equatable, Sendable {
    case clawdhub
    case localFolder
    case git
}

public struct RepositoryTemplateDetailData: Equatable, Sendable {
    public let templateKind: RepositoryEditorTemplateKind
    public let detailsSectionTitle: String
    public let skillsFolderSectionTitle: String
    public let gitRepositorySectionTitle: String
    public let clawdhubBaseURL: String
    public let clawdhubHint: String
    public let localFolderDisplayText: String
    public let localFolderPlaceholderText: String
    public let localFolderHintText: String
    public let localFolderSecondaryHint: String
    public let gitProviderDisplayName: String?
    public let gitProviderLogoName: String?
    public let gitSupportHint: String
    public let gitSyncHint: String

    public init(
        templateKind: RepositoryEditorTemplateKind,
        detailsSectionTitle: String,
        skillsFolderSectionTitle: String,
        gitRepositorySectionTitle: String,
        clawdhubBaseURL: String,
        clawdhubHint: String,
        localFolderDisplayText: String,
        localFolderPlaceholderText: String,
        localFolderHintText: String,
        localFolderSecondaryHint: String,
        gitProviderDisplayName: String?,
        gitProviderLogoName: String?,
        gitSupportHint: String,
        gitSyncHint: String
    ) {
        self.templateKind = templateKind
        self.detailsSectionTitle = detailsSectionTitle
        self.skillsFolderSectionTitle = skillsFolderSectionTitle
        self.gitRepositorySectionTitle = gitRepositorySectionTitle
        self.clawdhubBaseURL = clawdhubBaseURL
        self.clawdhubHint = clawdhubHint
        self.localFolderDisplayText = localFolderDisplayText
        self.localFolderPlaceholderText = localFolderPlaceholderText
        self.localFolderHintText = localFolderHintText
        self.localFolderSecondaryHint = localFolderSecondaryHint
        self.gitProviderDisplayName = gitProviderDisplayName
        self.gitProviderLogoName = gitProviderLogoName
        self.gitSupportHint = gitSupportHint
        self.gitSyncHint = gitSyncHint
    }
}
