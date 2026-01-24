import Foundation

/// Installation state for a skill
public enum SkillInstallationState: Sendable, Equatable {
    case installed  // Properly symlinked
    case orphaned  // Physical file in provider directory (needs migration)
    case broken  // Symlink points to non-existent file
}

/// Represents a skill folder in the global storage
public struct Skill: Sendable, Equatable, Identifiable, Hashable {

    // MARK: - Identity

    /// Skill ID (folder name)
    public let id: String

    /// Skill name from YAML frontmatter
    public let name: String

    /// Skill description from YAML frontmatter
    public let description: String

    /// Skill version from YAML frontmatter
    public let version: String

    /// Full path to skill folder in global storage (~/.nolon/skills/skill-id)
    public let globalPath: String

    // MARK: - Content

    /// Full SKILL.md content
    public let content: String

    // MARK: - Metadata

    /// Number of reference files in references/ directory
    public let referenceCount: Int

    /// Number of script files in scripts/ directory
    public let scriptCount: Int

    // MARK: - Init

    public init(
        id: String,
        name: String,
        description: String,
        version: String,
        globalPath: String,
        content: String,
        referenceCount: Int = 0,
        scriptCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.globalPath = globalPath
        self.content = content
        self.referenceCount = referenceCount
        self.scriptCount = scriptCount
    }

    // MARK: - Computed Properties

    /// Whether this skill has reference files
    public var hasReferences: Bool {
        referenceCount > 0
    }

    /// Whether this skill has script files
    public var hasScripts: Bool {
        scriptCount > 0
    }
    
    /// Content for the associated workflow file
    /// Generates a lightweight declaration that tells CLI a skill exists,
    /// allowing CLI to discover and load the full skill content itself.
    public var workflowContent: String {
        """
        ---
        description: \(description)
        ---
        
        使用 `\(name)` skill 来\(description)。
        """
    }

    // MARK: - Search

    /// Check if skill matches a search query
    public func matches(query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(query)
            || description.localizedCaseInsensitiveContains(query)
    }

    // MARK: - Mutation Methods

    /// Returns a copy with updated content
    public func updating(content newContent: String) -> Skill {
        Skill(
            id: id,
            name: name,
            description: description,
            version: version,
            globalPath: globalPath,
            content: newContent,
            referenceCount: referenceCount,
            scriptCount: scriptCount
        )
    }
}
