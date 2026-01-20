import Foundation

/// Persistent metadata for skills stored in ~/.nolon/skills/.metadata.json
public struct SkillMetadata: Codable, Sendable {
    /// Skill ID (folder name)
    public let id: String

    /// Providers where this skill is installed
    public var installedProviders: Set<SkillProvider>

    /// Last update timestamp
    public var lastUpdated: Date

    /// Optional source URL (for remote skills)
    public var sourceURL: String?

    public init(
        id: String,
        installedProviders: Set<SkillProvider> = [],
        lastUpdated: Date = Date(),
        sourceURL: String? = nil
    ) {
        self.id = id
        self.installedProviders = installedProviders
        self.lastUpdated = lastUpdated
        self.sourceURL = sourceURL
    }
}

/// Container for all skill metadata
public struct SkillMetadataStore: Codable, Sendable {
    public var skills: [String: SkillMetadata]

    public init(skills: [String: SkillMetadata] = [:]) {
        self.skills = skills
    }
}
