import Foundation
import ProviderCatalog
import STFilePath

/// Git hosting provider type
public enum GitProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case github
    case gitlab
    case bitbucket

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .gitlab: return "GitLab"
        case .bitbucket: return "Bitbucket"
        }
    }

    public var iconName: String {
        return "chevron.left.forwardslash.chevron.right"
    }

    public var logoName: String? {
        switch self {
        case .github: return "github"
        case .gitlab: return "gitlab"
        case .bitbucket: return nil
        }
    }

    public var baseURL: String {
        switch self {
        case .github: return "https://github.com"
        case .gitlab: return "https://gitlab.com"
        case .bitbucket: return "https://bitbucket.org"
        }
    }

    /// Directory name for storing repositories
    public nonisolated var directoryName: String {
        rawValue
    }

    /// Normalize URL to this provider's format
    public nonisolated func normalizeURL(_ url: String) -> String {
        var normalized =
            url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        switch self {
        case .github:
            normalized = normalized.replacingOccurrences(
                of: "git@github.com:", with: "https://github.com/")
            normalized = normalized.replacingOccurrences(of: "https://github.com/", with: "")
        case .gitlab:
            normalized = normalized.replacingOccurrences(
                of: "git@gitlab.com:", with: "https://gitlab.com/")
            normalized = normalized.replacingOccurrences(of: "https://gitlab.com/", with: "")
        case .bitbucket:
            normalized = normalized.replacingOccurrences(
                of: "git@bitbucket.org:", with: "https://bitbucket.org/")
            normalized = normalized.replacingOccurrences(of: "https://bitbucket.org/", with: "")
        }

        return normalized
    }

    /// Extract owner and repo name from URL
    public nonisolated func extractComponents(from url: String) -> (owner: String, repoName: String) {
        let normalized = normalizeURL(url)
        let components = normalized.split(separator: "/")
        if components.count >= 2 {
            let owner = String(components[components.count - 2])
            let repoName = String(components.last ?? Substring(normalized))
            return (owner, repoName)
        }
        return (normalized, normalized)
    }
}

/// Template types for remote repositories
public enum RepositoryTemplate: String, CaseIterable, Identifiable, Codable, Sendable {
    case globalSkills
    case clawdhub
    case localFolder
    case git

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .globalSkills:
            return NSLocalizedString("repo_type.global_skills", comment: "Global Skills")
        case .clawdhub: return "Clawdhub"
        case .localFolder:
            return NSLocalizedString("repo_type.local_folder", comment: "Local Folder")
        case .git: return "Git Repository"
        }
    }

    public var iconName: String {
        switch self {
        case .globalSkills: return "star.fill"
        case .clawdhub: return "cloud"
        case .localFolder: return "folder"
        case .git: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var logoName: String? {
        switch self {
        case .globalSkills: return nil
        case .clawdhub: return "clawhub"
        case .localFolder: return nil
        case .git: return nil
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .clawdhub: return "https://clawhub.ai"
        case .globalSkills, .localFolder, .git: return ""
        }
    }

    public var defaultName: String {
        switch self {
        case .globalSkills:
            return NSLocalizedString("repo_type.global_skills", comment: "Global Skills")
        case .clawdhub: return "Clawdhub"
        case .localFolder, .git: return ""
        }
    }

    public var isAPIBased: Bool {
        switch self {
        case .clawdhub: return true
        case .globalSkills, .localFolder, .git: return false
        }
    }

    public var isURLEditable: Bool {
        return false
    }

    public var requiresLocalPath: Bool {
        switch self {
        case .localFolder: return true
        case .globalSkills, .clawdhub, .git: return false
        }
    }

    /// Supported Git providers for this template
    public var supportedProviders: [GitProvider] {
        switch self {
        case .globalSkills, .clawdhub, .localFolder: return []
        case .git: return GitProvider.allCases
        }
    }

    /// Create a repository from this template
    public func createRepository(
        name: String? = nil,
        baseURL: String? = nil,
        localPath: String? = nil,
        gitURL: String? = nil,
        provider: GitProvider = .github,
        skillsPaths: [String] = []
    ) -> RemoteRepository {
        RemoteRepository(
            name: name ?? defaultName,
            baseURL: baseURL ?? defaultBaseURL,
            iconName: iconName,
            logoName: logoName,
            templateType: self,
            isBuiltIn: self == .clawdhub || self == .globalSkills,
            localPath: localPath,
            gitURL: gitURL,
            provider: provider,
            skillsPaths: skillsPaths
        )
    }
}

/// Represents a remote skill repository (e.g., Clawdhub, GitHub, GitLab)
public struct RemoteRepository: Identifiable, Codable, Hashable, Sendable {
    public var name: String
    public var baseURL: String
    public var iconName: String
    public var logoName: String?
    public var templateType: RepositoryTemplate
    public var isBuiltIn: Bool

    // Local folder specific
    public var localPath: String?

    // Git repository specific
    public var gitURL: String?
    public var provider: GitProvider = .github
    public var skillsPaths: [String]
    public var lastSyncDate: Date?
    public var accessToken: String?  // Personal Access Token for private repos

    // Auto-detected skills directories (from GitRepository)
    public var detectedDirectories: [String]?
    
    nonisolated public var id: String { _id }
    private let _id: String
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case name, baseURL, iconName, logoName, templateType, isBuiltIn
        case localPath, gitURL, provider, skillsPaths, lastSyncDate, accessToken
        case detectedDirectories
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        baseURL: String = "",
        iconName: String = "cloud",
        logoName: String? = nil,
        templateType: RepositoryTemplate = .git,
        isBuiltIn: Bool = false,
        localPath: String? = nil,
        gitURL: String? = nil,
        provider: GitProvider = .github,
        skillsPaths: [String] = [],
        lastSyncDate: Date? = nil,
        accessToken: String? = nil,
        detectedDirectories: [String]? = nil
    ) {
        self._id = id
        self.name = name
        self.baseURL = baseURL
        self.iconName = iconName
        self.logoName = logoName
        self.templateType = templateType
        self.isBuiltIn = isBuiltIn
        self.localPath = localPath
        self.gitURL = gitURL
        self.provider = provider
        self.skillsPaths = skillsPaths
        self.lastSyncDate = lastSyncDate
        self.accessToken = accessToken
        self.detectedDirectories = detectedDirectories
    }

    /// The effective paths to scan for skills (returns all configured paths)
    public var effectiveSkillsPaths: [String] {
        switch templateType {
        case .localFolder:
            guard let path = localPath, !path.isEmpty else { return [] }
            return [path]
        case .git:
            let basePath = localClonePath
            
            if !skillsPaths.isEmpty {
                return skillsPaths.map { subpath in
                    subpath == "."
                        ? basePath.path
                        : basePath.appendingPathComponent(subpath).path
                }
            }

            return [basePath.path]
        case .clawdhub:
            return []
        case .globalSkills:
            let globalPath = STFolder(NSHomeDirectory()).url
                .appendingPathComponent(".nolon/skills").path
            return [globalPath]
        }
    }

    /// Get the local clone path for this repository
    /// Format for git repos: ~/.nolon/repositories/{domain}/{owner}@{repo}
    nonisolated public var localClonePath: URL {
        let repositoriesPath = STFolder(NSHomeDirectory()).url
            .appendingPathComponent(".nolon/repositories")
        switch templateType {
        case .localFolder:
            guard let path = localPath else {
                return repositoriesPath.appendingPathComponent("unknown")
            }
            return STPath(path).url
        case .git:
            guard let gitURL = gitURL else {
                return repositoriesPath.appendingPathComponent("unknown")
            }
            if let suggested = SkillsRepositoryFacade.suggestedClonePath(
                gitURL: gitURL,
                repositoriesRoot: repositoriesPath
            ) {
                return suggested
            }
            // Fallback: keep deterministic path layout based on façade identity if available.
            if let identity = SkillsRepositoryFacade.parseRepositoryIdentity(from: gitURL) {
                return repositoriesPath
                    .appendingPathComponent(identity.host)
                    .appendingPathComponent(identity.repoFullName)
            }
            // Final fallback to legacy provider-based parsing.
            let components = provider.extractComponents(from: gitURL)
            let repoFullName = "\(components.owner)@\(components.repoName)"
            return
                repositoriesPath
                .appendingPathComponent(provider.directoryName)
                .appendingPathComponent(repoFullName)
        case .clawdhub:
            return repositoriesPath.appendingPathComponent("clawdhub")
        case .globalSkills:
            return repositoriesPath.appendingPathComponent("skills")
        }
    }

    nonisolated public var localCloneFolder: STFolder {
        STFolder(localClonePath)
    }

    /// Extract repository name from Git URL
    public static func extractRepoName(from url: String) -> String {
        if let identity = SkillsRepositoryFacade.parseRepositoryIdentity(from: url) {
            return identity.repo
        }
        let cleaned =
            url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let components = cleaned.split(separator: "/")
        return components.last.map(String.init) ?? cleaned
    }

    /// Extract full repository identifier in "owner@repo" format
    public static func extractRepoFullName(from url: String) -> String {
        if let identity = SkillsRepositoryFacade.parseRepositoryIdentity(from: url) {
            return identity.repoFullName
        }
        return extractRepoName(from: url)
    }

    /// Detect Git provider from URL
    public static func detectProvider(from url: String) -> GitProvider? {
        switch SkillsRepositoryFacade.detectGitProvider(from: url) {
        case .github:
            return .github
        case .gitlab:
            return .gitlab
        case .bitbucket:
            return .bitbucket
        case .unknown:
            return nil
        }
    }

    /// Extract host, owner and repo from a Git URL (HTTPS or SSH)
    /// Supports: https://gitlab.dxy.net/ios-developer/tod-skills
    ///           git@gitlab.dxy.net:ios-developer/tod-skills.git
    public nonisolated static func extractURLComponents(from url: String) -> (
        host: String, owner: String, repo: String
    )? {
        guard let components = SkillsRepositoryFacade.extractURLComponents(from: url) else {
            return nil
        }
        return (components.host, components.owner, components.repo)
    }

    /// Built-in Clawdhub repository
    public static let clawdhub = RepositoryTemplate.clawdhub.createRepository()
    
    /// Built-in Global Skills repository (~/.nolon/skills/)
    public static let globalSkills = RepositoryTemplate.globalSkills.createRepository()
}
