import Foundation

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
        switch self {
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .gitlab: return "chevron.left.forwardslash.chevron.right"
        case .bitbucket: return "chevron.left.forwardslash.chevron.right"
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
    public var directoryName: String {
        rawValue
    }

    /// Normalize URL to this provider's format
    public func normalizeURL(_ url: String) -> String {
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
    public func extractComponents(from url: String) -> (owner: String, repoName: String) {
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

    public var defaultBaseURL: String {
        switch self {
        case .clawdhub: return "https://clawdhub.com"
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
    public let id: String
    public var name: String
    public var baseURL: String
    public var iconName: String
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

    // Auto-detected skills directories (from GitRepositoryService)
    public var detectedDirectories: [String]?

    public init(
        id: String = UUID().uuidString,
        name: String,
        baseURL: String = "",
        iconName: String = "cloud",
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
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.iconName = iconName
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
            let globalPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".nolon/skills").path
            return [globalPath]
        }
    }

    /// Get the local clone path for this repository
    /// Format for git repos: ~/.nolon/repositories/{domain}/{owner}@{repo}
    public var localClonePath: URL {
        let repositoriesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nolon/repositories")
        switch templateType {
        case .localFolder:
            guard let path = localPath else {
                return repositoriesPath.appendingPathComponent("unknown")
            }
            return URL(fileURLWithPath: path)
        case .git:
            guard let gitURL = gitURL else {
                return repositoriesPath.appendingPathComponent("unknown")
            }
            // Parse URL to extract domain/owner@repo format
            if let components = Self.extractURLComponents(from: gitURL) {
                return
                    repositoriesPath
                    .appendingPathComponent(components.host)
                    .appendingPathComponent("\(components.owner)@\(components.repo)")
            }
            // Fallback to old format if parsing fails
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

    /// Extract repository name from Git URL
    public static func extractRepoName(from url: String) -> String {
        if let provider = detectProvider(from: url) {
            return provider.extractComponents(from: url).repoName
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
        guard let provider = detectProvider(from: url) else {
            return extractRepoName(from: url)
        }
        let components = provider.extractComponents(from: url)
        return "\(components.owner)@\(components.repoName)"
    }

    /// Detect Git provider from URL
    public static func detectProvider(from url: String) -> GitProvider? {
        let lowercased = url.lowercased()
        if lowercased.contains("gitlab.com") || lowercased.contains("git@gitlab") {
            return .gitlab
        }
        if lowercased.contains("bitbucket.org") || lowercased.contains("git@bitbucket") {
            return .bitbucket
        }
        if lowercased.contains("github.com") || lowercased.contains("git@github") {
            return .github
        }
        return nil
    }

    /// Extract host, owner and repo from a Git URL (HTTPS or SSH)
    /// Supports: https://gitlab.dxy.net/ios-developer/tod-skills
    ///           git@gitlab.dxy.net:ios-developer/tod-skills.git
    public static func extractURLComponents(from url: String) -> (
        host: String, owner: String, repo: String
    )? {
        let cleaned =
            url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // SSH format: git@host:owner/repo
        if cleaned.hasPrefix("git@") {
            let withoutPrefix = cleaned.dropFirst(4)  // Remove "git@"
            if let colonIndex = withoutPrefix.firstIndex(of: ":") {
                let host = String(withoutPrefix[..<colonIndex])
                let path = String(withoutPrefix[withoutPrefix.index(after: colonIndex)...])
                let pathComponents = path.split(separator: "/")
                if pathComponents.count >= 2 {
                    let owner = String(pathComponents[0])
                    let repo = String(pathComponents[1])
                    return (host, owner, repo)
                }
            }
        }

        // HTTPS format: https://host/owner/repo
        if let urlObj = URL(string: cleaned), let host = urlObj.host {
            let pathComponents = urlObj.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
            if pathComponents.count >= 2 {
                let owner = String(pathComponents[0])
                let repo = String(pathComponents[1])
                return (host, owner, repo)
            }
        }

        return nil
    }

    /// Built-in Clawdhub repository
    public static let clawdhub = RepositoryTemplate.clawdhub.createRepository()
    
    /// Built-in Global Skills repository (~/.nolon/skills/)
    public static let globalSkills = RepositoryTemplate.globalSkills.createRepository()
}
