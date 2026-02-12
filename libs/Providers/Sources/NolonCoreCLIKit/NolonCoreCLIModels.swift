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
