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
    
    public nonisolated init(
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

    public enum CodingKeys: String, CodingKey {
        case source
        case sourceType
        case sourceUrl
        case skillPath
        case skillFolderHash
        case installedAt
        case updatedAt
        case version
        case displayName
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try container.decode(String.self, forKey: .source)
        self.sourceType = try container.decode(String.self, forKey: .sourceType)
        self.sourceUrl = try container.decode(String.self, forKey: .sourceUrl)
        self.skillPath = try container.decodeIfPresent(String.self, forKey: .skillPath)
        self.skillFolderHash = try container.decodeIfPresent(String.self, forKey: .skillFolderHash)
        self.installedAt = try container.decode(Date.self, forKey: .installedAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.version = try container.decodeIfPresent(String.self, forKey: .version)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(sourceUrl, forKey: .sourceUrl)
        try container.encodeIfPresent(skillPath, forKey: .skillPath)
        try container.encodeIfPresent(skillFolderHash, forKey: .skillFolderHash)
        try container.encode(installedAt, forKey: .installedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(displayName, forKey: .displayName)
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
    
    public nonisolated init(
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
    public nonisolated static let currentVersion = 3
    
    /// Create an empty lock file
    public nonisolated static func empty() -> SkillLockFile {
        SkillLockFile(version: currentVersion, skills: [:])
    }

    public enum CodingKeys: String, CodingKey {
        case version
        case skills
        case dismissedPrompts
        case lastSelectedProviders
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(Int.self, forKey: .version)
        self.skills = try container.decode([String: SkillLockEntry].self, forKey: .skills)
        self.dismissedPrompts = try container.decodeIfPresent([String: Bool].self, forKey: .dismissedPrompts)
        self.lastSelectedProviders = try container.decodeIfPresent([String].self, forKey: .lastSelectedProviders)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(skills, forKey: .skills)
        try container.encodeIfPresent(dismissedPrompts, forKey: .dismissedPrompts)
        try container.encodeIfPresent(lastSelectedProviders, forKey: .lastSelectedProviders)
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
    
    public nonisolated init(
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
