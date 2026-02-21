import Foundation

public enum NolonGitPullStrategy: String, Sendable, Equatable, Codable, CaseIterable {
    case ffOnly = "ff-only"
    case rebase
}

public enum NolonGitCredentialStrategy: String, Sendable, Equatable, Codable, CaseIterable {
    case automatic
    case tokenOnly = "token-only"
    case sshOnly = "ssh-only"
}

public enum NolonSkillInstallMethod: String, Sendable, Equatable, Codable, CaseIterable {
    case symlink
    case copy
}

public struct NolonGitImportPlan: Sendable, Equatable, Codable {
    public let source: String
    public let normalizedGitURL: String
    public let subpath: String?
    public let providerHost: String
    public let owner: String
    public let repo: String
    public let localClonePath: URL

    public init(
        source: String,
        normalizedGitURL: String,
        subpath: String?,
        providerHost: String,
        owner: String,
        repo: String,
        localClonePath: URL
    ) {
        self.source = source
        self.normalizedGitURL = normalizedGitURL
        self.subpath = subpath
        self.providerHost = providerHost
        self.owner = owner
        self.repo = repo
        self.localClonePath = localClonePath
    }
}

public struct NolonSkillsDirectoryCandidate: Sendable, Equatable, Codable {
    public let path: String
    public let skillCount: Int
    public let skillNames: [String]

    public init(path: String, skillCount: Int, skillNames: [String]) {
        self.path = path
        self.skillCount = skillCount
        self.skillNames = skillNames
    }
}

public struct NolonGitSyncResult: Sendable, Equatable, Codable {
    public let mode: String
    public let updatedAt: Date
    public let directories: [NolonSkillsDirectoryCandidate]
    public let defaultBranch: String?
    public let credentialMode: String

    public init(
        mode: String,
        updatedAt: Date,
        directories: [NolonSkillsDirectoryCandidate],
        defaultBranch: String?,
        credentialMode: String
    ) {
        self.mode = mode
        self.updatedAt = updatedAt
        self.directories = directories
        self.defaultBranch = defaultBranch
        self.credentialMode = credentialMode
    }
}

public struct NolonGitSyncPreflight: Sendable, Equatable, Codable {
    public let isValidURL: Bool
    public let normalizedGitURL: String
    public let pullStrategy: NolonGitPullStrategy
    public let credentialStrategy: NolonGitCredentialStrategy
    public let credentialMode: String
    public let requiresAccessToken: Bool
    public let warnings: [String]
    public let issues: [NolonGitSyncPreflightIssue]

    public init(
        isValidURL: Bool,
        normalizedGitURL: String,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        credentialMode: String,
        requiresAccessToken: Bool,
        warnings: [String],
        issues: [NolonGitSyncPreflightIssue]
    ) {
        self.isValidURL = isValidURL
        self.normalizedGitURL = normalizedGitURL
        self.pullStrategy = pullStrategy
        self.credentialStrategy = credentialStrategy
        self.credentialMode = credentialMode
        self.requiresAccessToken = requiresAccessToken
        self.warnings = warnings
        self.issues = issues
    }
}

public struct NolonGitSyncPreflightIssue: Sendable, Equatable, Codable {
    public let code: NolonGitSyncPreflightIssueCode
    public let severity: NolonGitSyncPreflightIssueSeverity
    public let message: String

    public init(
        code: NolonGitSyncPreflightIssueCode,
        severity: NolonGitSyncPreflightIssueSeverity,
        message: String
    ) {
        self.code = code
        self.severity = severity
        self.message = message
    }
}

public enum NolonGitSyncPreflightIssueCode: String, Sendable, Equatable, Codable {
    case invalidGitURL = "invalid_git_url"
    case accessTokenRequired = "access_token_required"
    case tokenStrategyRequiresHTTPS = "token_strategy_requires_https"
    case sshStrategyRequiresSSH = "ssh_strategy_requires_ssh"
}

public enum NolonGitSyncPreflightIssueSeverity: String, Sendable, Equatable, Codable {
    case warning
    case error
}

public struct NolonGitSyncErrorDetail: Sendable, Equatable, Codable {
    public let gitURL: String
    public let pullStrategy: NolonGitPullStrategy
    public let credentialStrategy: NolonGitCredentialStrategy
    public let hasAccessToken: Bool
    public let phase: String?
    public let host: String?

    enum CodingKeys: String, CodingKey {
        case gitURL = "git_url"
        case pullStrategy = "pull_strategy"
        case credentialStrategy = "credential_strategy"
        case hasAccessToken = "has_access_token"
        case phase
        case host
    }

    public init(
        gitURL: String,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        hasAccessToken: Bool,
        phase: String? = nil,
        host: String? = nil
    ) {
        self.gitURL = gitURL
        self.pullStrategy = pullStrategy
        self.credentialStrategy = credentialStrategy
        self.hasAccessToken = hasAccessToken
        self.phase = phase
        self.host = host
    }
}

public struct NolonSkillStandardMetadata: Sendable, Equatable, Codable {
    public let name: String
    public let description: String
    public let license: String?
    public let compatibility: String?
    public let metadata: [String: String]
    public let argumentHint: String?
    public let allowedTools: [String]
    public let isValid: Bool
    public let warnings: [String]
    public let issues: [NolonSkillValidationIssue]

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case license
        case compatibility
        case metadata
        case argumentHint
        case allowedTools
        case isValid = "is_valid"
        case warnings
        case issues
    }

    public init(
        name: String,
        description: String,
        license: String?,
        compatibility: String?,
        metadata: [String: String],
        argumentHint: String?,
        allowedTools: [String],
        isValid: Bool,
        warnings: [String],
        issues: [NolonSkillValidationIssue]
    ) {
        self.name = name
        self.description = description
        self.license = license
        self.compatibility = compatibility
        self.metadata = metadata
        self.argumentHint = argumentHint
        self.allowedTools = allowedTools
        self.isValid = isValid
        self.warnings = warnings
        self.issues = issues
    }
}

public enum NolonSkillValidationIssueSeverity: String, Sendable, Equatable, Codable {
    case warning
    case error
}

public enum NolonSkillValidationIssueCode: String, Sendable, Equatable, Codable {
    case unknownTopLevelField = "unknown_top_level_field"
    case metadataNotObject = "metadata_not_object"
    case metadataValueNotString = "metadata_value_not_string"
    case missingName = "missing_name"
    case missingDescription = "missing_description"
    case invalidNameFormat = "invalid_name_format"
    case nameDirectoryMismatch = "name_directory_mismatch"
    case descriptionTooLong = "description_too_long"
    case compatibilityOutOfRange = "compatibility_out_of_range"
    case allowedToolsUnsupportedFormat = "allowed_tools_unsupported_format"
    case allowedToolsNonStringItem = "allowed_tools_non_string_item"
}

public struct NolonSkillValidationIssue: Sendable, Equatable, Codable {
    public let code: NolonSkillValidationIssueCode
    public let severity: NolonSkillValidationIssueSeverity
    public let message: String

    public init(
        code: NolonSkillValidationIssueCode,
        severity: NolonSkillValidationIssueSeverity,
        message: String
    ) {
        self.code = code
        self.severity = severity
        self.message = message
    }
}

public struct NolonSkillInstallResult: Sendable, Equatable, Codable {
    public let skillID: String
    public let sourcePath: String
    public let targetPath: String
    public let installMethod: NolonSkillInstallMethod

    enum CodingKeys: String, CodingKey {
        case skillID = "skill_id"
        case sourcePath = "source_path"
        case targetPath = "target_path"
        case installMethod = "install_method"
    }

    public init(
        skillID: String,
        sourcePath: String,
        targetPath: String,
        installMethod: NolonSkillInstallMethod
    ) {
        self.skillID = skillID
        self.sourcePath = sourcePath
        self.targetPath = targetPath
        self.installMethod = installMethod
    }
}

public struct NolonSkillUninstallResult: Sendable, Equatable, Codable {
    public let skillID: String
    public let targetPath: String
    public let removed: Bool

    enum CodingKeys: String, CodingKey {
        case skillID = "skill_id"
        case targetPath = "target_path"
        case removed
    }

    public init(skillID: String, targetPath: String, removed: Bool) {
        self.skillID = skillID
        self.targetPath = targetPath
        self.removed = removed
    }
}

public struct NolonCLIExecutionResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum NolonProviderSkillStateKind: String, Sendable, Equatable, Codable, CaseIterable {
    case installed
    case orphaned
    case broken
}

public enum NolonResourceSourceType: String, Sendable, Equatable, Codable, CaseIterable {
    case local
    case remote
    case fromSkill = "from_skill"
    case fromWorkflow = "from_workflow"
    case fromMcp = "from_mcp"
    case unknown
}

public enum NolonResourceSourceKind: String, Sendable, Equatable, Codable, CaseIterable {
    case skill
    case workflow
    case mcp
    case repo
    case url
    case path
    case unknown
}

public struct NolonResourceOrigin: Sendable, Equatable, Codable {
    public let schemaVersion: Int
    public let resourceKind: NolonRemoteCatalogKind
    public let sourceType: NolonResourceSourceType
    public let sourceKind: NolonResourceSourceKind
    public let sourceRef: String
    public let sourceDisplay: String
    public let createdAt: Date
    public let updatedAt: Date
    public let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case resourceKind = "resource_kind"
        case sourceType = "source_type"
        case sourceKind = "source_kind"
        case sourceRef = "source_ref"
        case sourceDisplay = "source_display"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
    }

    public init(
        schemaVersion: Int = 1,
        resourceKind: NolonRemoteCatalogKind,
        sourceType: NolonResourceSourceType,
        sourceKind: NolonResourceSourceKind,
        sourceRef: String,
        sourceDisplay: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.resourceKind = resourceKind
        self.sourceType = sourceType
        self.sourceKind = sourceKind
        self.sourceRef = sourceRef
        self.sourceDisplay = sourceDisplay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

public struct NolonProviderSkillState: Sendable, Equatable, Codable {
    public let skillID: String
    public let path: String
    public let state: NolonProviderSkillStateKind

    enum CodingKeys: String, CodingKey {
        case skillID = "skill_id"
        case path
        case state
    }

    public init(skillID: String, path: String, state: NolonProviderSkillStateKind) {
        self.skillID = skillID
        self.path = path
        self.state = state
    }
}

public struct NolonSkillMigrateScanResult: Sendable, Equatable, Codable {
    public let providerPath: String
    public let globalSkillsPath: String
    public let states: [NolonProviderSkillState]

    enum CodingKeys: String, CodingKey {
        case providerPath = "provider_path"
        case globalSkillsPath = "global_skills_path"
        case states
    }

    public init(providerPath: String, globalSkillsPath: String, states: [NolonProviderSkillState]) {
        self.providerPath = providerPath
        self.globalSkillsPath = globalSkillsPath
        self.states = states
    }
}

public struct NolonResourceFile: Sendable, Equatable, Codable {
    public let path: String
    public let kind: String

    public init(path: String, kind: String) {
        self.path = path
        self.kind = kind
    }
}

public enum NolonResourceKind: String, Sendable, Equatable, Codable, CaseIterable {
    case workflow
    case mcp
}

public struct NolonResourceInstallResult: Sendable, Equatable, Codable {
    public let kind: NolonResourceKind
    public let resourceName: String
    public let sourcePath: String
    public let targetPath: String
    public let installMethod: NolonSkillInstallMethod

    enum CodingKeys: String, CodingKey {
        case kind
        case resourceName = "resource_name"
        case sourcePath = "source_path"
        case targetPath = "target_path"
        case installMethod = "install_method"
    }

    public init(
        kind: NolonResourceKind,
        resourceName: String,
        sourcePath: String,
        targetPath: String,
        installMethod: NolonSkillInstallMethod
    ) {
        self.kind = kind
        self.resourceName = resourceName
        self.sourcePath = sourcePath
        self.targetPath = targetPath
        self.installMethod = installMethod
    }
}

public struct NolonResourceUninstallResult: Sendable, Equatable, Codable {
    public let kind: NolonResourceKind
    public let resourceName: String
    public let targetPath: String
    public let removed: Bool

    enum CodingKeys: String, CodingKey {
        case kind
        case resourceName = "resource_name"
        case targetPath = "target_path"
        case removed
    }

    public init(kind: NolonResourceKind, resourceName: String, targetPath: String, removed: Bool) {
        self.kind = kind
        self.resourceName = resourceName
        self.targetPath = targetPath
        self.removed = removed
    }
}

public enum NolonRemoteCatalogKind: String, Sendable, Equatable, Codable, CaseIterable {
    case skill
    case workflow
    case mcp
}

public struct NolonRemoteCatalogItem: Sendable, Equatable, Codable {
    public let kind: NolonRemoteCatalogKind
    public let slug: String
    public let displayName: String
    public let summary: String?
    public let latestVersion: String?
    public let updatedAt: Date?
    public let downloads: Int?
    public let stars: Int?
    public let installs: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case slug
        case displayName = "display_name"
        case summary
        case latestVersion = "latest_version"
        case updatedAt = "updated_at"
        case downloads
        case stars
        case installs
    }
}

public struct NolonRemoteListResult: Sendable, Equatable, Codable {
    public let kind: NolonRemoteCatalogKind
    public let baseURL: String
    public let query: String?
    public let limit: Int
    public let items: [NolonRemoteCatalogItem]

    enum CodingKeys: String, CodingKey {
        case kind
        case baseURL = "base_url"
        case query
        case limit
        case items
    }
}

public struct NolonRemoteDownloadResult: Sendable, Equatable, Codable {
    public let kind: NolonRemoteCatalogKind
    public let slug: String
    public let version: String?
    public let baseURL: String
    public let filePath: String

    enum CodingKeys: String, CodingKey {
        case kind
        case slug
        case version
        case baseURL = "base_url"
        case filePath = "file_path"
    }
}

public struct NolonRemoteInstallResult: Sendable, Equatable, Codable {
    public let kind: NolonRemoteCatalogKind
    public let slug: String
    public let version: String?
    public let baseURL: String
    public let downloadedFilePath: String
    public let installedPath: String
    public let installMethod: NolonSkillInstallMethod
    public let skillID: String?
    public let resourceName: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case slug
        case version
        case baseURL = "base_url"
        case downloadedFilePath = "downloaded_file_path"
        case installedPath = "installed_path"
        case installMethod = "install_method"
        case skillID = "skill_id"
        case resourceName = "resource_name"
    }
}

public struct NolonRemoteSyncInstallResult: Sendable, Equatable, Codable {
    public let kind: NolonRemoteCatalogKind
    public let source: String
    public let repositoriesRoot: String
    public let path: String
    public let repositoryFilePath: String
    public let installedPath: String
    public let installMethod: NolonSkillInstallMethod
    public let skillID: String?
    public let resourceName: String?
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case kind
        case source
        case repositoriesRoot = "repositories_root"
        case path
        case repositoryFilePath = "repository_file_path"
        case installedPath = "installed_path"
        case installMethod = "install_method"
        case skillID = "skill_id"
        case resourceName = "resource_name"
        case warnings
    }

    public init(
        kind: NolonRemoteCatalogKind,
        source: String,
        repositoriesRoot: String,
        path: String,
        repositoryFilePath: String,
        installedPath: String,
        installMethod: NolonSkillInstallMethod,
        skillID: String?,
        resourceName: String?,
        warnings: [String] = []
    ) {
        self.kind = kind
        self.source = source
        self.repositoriesRoot = repositoriesRoot
        self.path = path
        self.repositoryFilePath = repositoryFilePath
        self.installedPath = installedPath
        self.installMethod = installMethod
        self.skillID = skillID
        self.resourceName = resourceName
        self.warnings = warnings
    }
}

public struct NolonRepositoryResources: Sendable, Equatable, Codable {
    public let skillsDirectories: [NolonSkillsDirectoryCandidate]
    public let workflows: [NolonResourceFile]
    public let mcps: [NolonResourceFile]

    public init(
        skillsDirectories: [NolonSkillsDirectoryCandidate],
        workflows: [NolonResourceFile],
        mcps: [NolonResourceFile]
    ) {
        self.skillsDirectories = skillsDirectories
        self.workflows = workflows
        self.mcps = mcps
    }
}

public struct NolonLocalRepositorySummary: Sendable, Equatable, Codable {
    public let name: String
    public let path: String
    public let skillsDirectoryCount: Int
    public let workflowCount: Int
    public let mcpCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case skillsDirectoryCount = "skills_directory_count"
        case workflowCount = "workflow_count"
        case mcpCount = "mcp_count"
    }

    public init(
        name: String,
        path: String,
        skillsDirectoryCount: Int,
        workflowCount: Int,
        mcpCount: Int
    ) {
        self.name = name
        self.path = path
        self.skillsDirectoryCount = skillsDirectoryCount
        self.workflowCount = workflowCount
        self.mcpCount = mcpCount
    }
}

public struct NolonSkillsListItem: Sendable, Equatable, Codable {
    public let providerID: String
    public let providerPath: String
    public let skillID: String
    public let state: NolonProviderSkillStateKind
    public let path: String
    public let origin: NolonResourceOrigin?

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerPath = "provider_path"
        case skillID = "skill_id"
        case state
        case path
        case origin
    }

    public init(
        providerID: String,
        providerPath: String,
        skillID: String,
        state: NolonProviderSkillStateKind,
        path: String,
        origin: NolonResourceOrigin? = nil
    ) {
        self.providerID = providerID
        self.providerPath = providerPath
        self.skillID = skillID
        self.state = state
        self.path = path
        self.origin = origin
    }
}

public struct NolonSkillsListSummary: Sendable, Equatable, Codable {
    public let providerCount: Int
    public let itemCount: Int
    public let installedCount: Int
    public let orphanedCount: Int
    public let brokenCount: Int

    enum CodingKeys: String, CodingKey {
        case providerCount = "provider_count"
        case itemCount = "item_count"
        case installedCount = "installed_count"
        case orphanedCount = "orphaned_count"
        case brokenCount = "broken_count"
    }

    public init(providerCount: Int, itemCount: Int, installedCount: Int, orphanedCount: Int, brokenCount: Int) {
        self.providerCount = providerCount
        self.itemCount = itemCount
        self.installedCount = installedCount
        self.orphanedCount = orphanedCount
        self.brokenCount = brokenCount
    }
}

public struct NolonSkillsListResult: Sendable, Equatable, Codable {
    public let providerFilter: String?
    public let stateFilter: NolonProviderSkillStateKind?
    public let includeEmpty: Bool
    public let items: [NolonSkillsListItem]
    public let summary: NolonSkillsListSummary

    enum CodingKeys: String, CodingKey {
        case providerFilter = "provider_filter"
        case stateFilter = "state_filter"
        case includeEmpty = "include_empty"
        case items
        case summary
    }

    public init(
        providerFilter: String?,
        stateFilter: NolonProviderSkillStateKind?,
        includeEmpty: Bool,
        items: [NolonSkillsListItem],
        summary: NolonSkillsListSummary
    ) {
        self.providerFilter = providerFilter
        self.stateFilter = stateFilter
        self.includeEmpty = includeEmpty
        self.items = items
        self.summary = summary
    }
}

public enum NolonSkillsAddSourceKind: String, Sendable, Equatable, Codable {
    case local
    case remote
}

public enum NolonSkillsAddTargetStatus: String, Sendable, Equatable, Codable {
    case planned
    case installed
    case failed
}

public struct NolonSkillsAddTargetResult: Sendable, Equatable, Codable {
    public let providerID: String
    public let providerPath: String
    public let sourcePath: String
    public let installedPath: String?
    public let status: NolonSkillsAddTargetStatus
    public let errorCode: String?
    public let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerPath = "provider_path"
        case sourcePath = "source_path"
        case installedPath = "installed_path"
        case status
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }

    public init(
        providerID: String,
        providerPath: String,
        sourcePath: String,
        installedPath: String?,
        status: NolonSkillsAddTargetStatus,
        errorCode: String?,
        errorMessage: String?
    ) {
        self.providerID = providerID
        self.providerPath = providerPath
        self.sourcePath = sourcePath
        self.installedPath = installedPath
        self.status = status
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public struct NolonSkillsAddResult: Sendable, Equatable, Codable {
    public let slug: String
    public let source: NolonSkillsAddSourceKind
    public let cachedPath: String
    public let installMethod: NolonSkillInstallMethod
    public let targets: [NolonSkillsAddTargetResult]
    public let successCount: Int
    public let failureCount: Int
    public let warnings: [String]
    public let dryRun: Bool

    enum CodingKeys: String, CodingKey {
        case slug
        case source
        case cachedPath = "cached_path"
        case installMethod = "install_method"
        case targets
        case successCount = "success_count"
        case failureCount = "failure_count"
        case warnings
        case dryRun = "dry_run"
    }

    public init(
        slug: String,
        source: NolonSkillsAddSourceKind,
        cachedPath: String,
        installMethod: NolonSkillInstallMethod,
        targets: [NolonSkillsAddTargetResult],
        successCount: Int,
        failureCount: Int,
        warnings: [String],
        dryRun: Bool
    ) {
        self.slug = slug
        self.source = source
        self.cachedPath = cachedPath
        self.installMethod = installMethod
        self.targets = targets
        self.successCount = successCount
        self.failureCount = failureCount
        self.warnings = warnings
        self.dryRun = dryRun
    }
}

public struct NolonCLISuccessEnvelope<Payload: Encodable & Sendable>: Encodable, Sendable {
    public let ok = true
    public let command: String
    public let data: Payload

    public init(command: String, data: Payload) {
        self.command = command
        self.data = data
    }
}

public struct NolonCLIErrorEnvelope: Encodable, Sendable {
    public struct Body: Encodable, Sendable {
        public let code: String
        public let message: String
        public let detail: NolonGitSyncErrorDetail?

        public init(code: String, message: String, detail: NolonGitSyncErrorDetail? = nil) {
            self.code = code
            self.message = message
            self.detail = detail
        }
    }

    public let ok = false
    public let error: Body

    public init(code: String, message: String, detail: NolonGitSyncErrorDetail? = nil) {
        self.error = Body(code: code, message: message, detail: detail)
    }
}
