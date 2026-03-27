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
        detailsSectionTitle: String = "Details",
        skillsFolderSectionTitle: String = "Skills Folder",
        gitRepositorySectionTitle: String = "Git Repository",
        clawdhubBaseURL: String,
        clawdhubHint: String = "Clawdhub is the official skill marketplace.",
        localFolderDisplayText: String,
        localFolderPlaceholderText: String = "拖拽本地 skills 文件夹到这里",
        localFolderHintText: String = "或点击选择文件夹",
        localFolderSecondaryHint: String = "Select a folder containing skill directories (each with a SKILL.md file).",
        gitProviderDisplayName: String?,
        gitProviderLogoName: String?,
        gitSupportHint: String = "Supports GitHub, GitLab, Bitbucket and other Git hosting services.",
        gitSyncHint: String = "Sync 后将自动扫描仓库中的技能目录，下一步可多选确认。"
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
