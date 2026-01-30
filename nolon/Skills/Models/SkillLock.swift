import Foundation

// MARK: - Skill Lock Entry

/// Represents a single installed skill entry in the lock file
/// Similar to skills CLI's SkillLockEntry
public struct SkillLockEntry: Codable, Sendable, Equatable {
    /// Normalized source identifier (e.g., "owner/repo", "clawdhub/skill-name")
    public let source: String
    
    /// The provider/source type (e.g., "github", "clawdhub", "gitlab", "local")
    public let sourceType: String
    
    /// The original URL used to install the skill (for re-fetching updates)
    public let sourceUrl: String
    
    /// Subpath within the source repo, if applicable
    public let skillPath: String?
    
    /// GitHub tree SHA for the entire skill folder
    /// This hash changes when ANY file in the skill folder changes
    public let skillFolderHash: String?
    
    /// ISO timestamp when the skill was first installed
    public let installedAt: Date
    
    /// ISO timestamp when the skill was last updated
    public var updatedAt: Date
    
    /// Version from SKILL.md frontmatter
    public let version: String?
    
    /// Display name from SKILL.md
    public let displayName: String?
    
    public init(
        source: String,
        sourceType: String,
        sourceUrl: String,
        skillPath: String? = nil,
        skillFolderHash: String? = nil,
        installedAt: Date = Date(),
        updatedAt: Date = Date(),
        version: String? = nil,
        displayName: String? = nil
    ) {
        self.source = source
        self.sourceType = sourceType
        self.sourceUrl = sourceUrl
        self.skillPath = skillPath
        self.skillFolderHash = skillFolderHash
        self.installedAt = installedAt
        self.updatedAt = updatedAt
        self.version = version
        self.displayName = displayName
    }
}

// MARK: - Skill Lock File

/// The structure of the skill lock file
/// Version 3 format (matches skills CLI)
public struct SkillLockFile: Codable, Sendable {
    /// Schema version for future migrations
    public let version: Int
    
    /// Map of skill name/slug to its lock entry
    public var skills: [String: SkillLockEntry]
    
    /// Tracks dismissed prompts (optional)
    public var dismissedPrompts: [String: Bool]?
    
    /// Last selected providers for installation
    public var lastSelectedProviders: [String]?
    
    public init(
        version: Int = SkillLockFile.currentVersion,
        skills: [String: SkillLockEntry] = [:],
        dismissedPrompts: [String: Bool]? = nil,
        lastSelectedProviders: [String]? = nil
    ) {
        self.version = version
        self.skills = skills
        self.dismissedPrompts = dismissedPrompts
        self.lastSelectedProviders = lastSelectedProviders
    }
    
    /// Current lock file version
    public static let currentVersion = 3
    
    /// Create an empty lock file
    public static func empty() -> SkillLockFile {
        SkillLockFile(version: currentVersion, skills: [:])
    }
}

// MARK: - Update Info

/// Information about a skill update availability
public struct SkillUpdateInfo: Sendable, Equatable, Identifiable {
    public let id: String  // skill slug
    public let skillName: String
    public let currentVersion: String?
    public let latestVersion: String?
    public let hasUpdate: Bool
    public let currentHash: String?
    public let latestHash: String?
    public let updateSource: UpdateSource
    
    public enum UpdateSource: String, Sendable {
        case clawdhub
        case github
        case gitlab
        case local
    }
    
    public init(
        id: String,
        skillName: String,
        currentVersion: String? = nil,
        latestVersion: String? = nil,
        hasUpdate: Bool,
        currentHash: String? = nil,
        latestHash: String? = nil,
        updateSource: UpdateSource
    ) {
        self.id = id
        self.skillName = skillName
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.hasUpdate = hasUpdate
        self.currentHash = currentHash
        self.latestHash = latestHash
        self.updateSource = updateSource
    }
}

// MARK: - Source Types

/// Source types for installed skills
public enum SkillSourceType: String, Sendable, CaseIterable {
    case clawdhub
    case github
    case gitlab
    case bitbucket
    case local
    case unknown
    
    public var displayName: String {
        switch self {
        case .clawdhub:
            return "Clawdhub"
        case .github:
            return "GitHub"
        case .gitlab:
            return "GitLab"
        case .bitbucket:
            return "Bitbucket"
        case .local:
            return "Local"
        case .unknown:
            return "Unknown"
        }
    }
}