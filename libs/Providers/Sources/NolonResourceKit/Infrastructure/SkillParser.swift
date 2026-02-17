import Foundation
import STFilePath
import ProviderCatalog

/// Parses SKILL.md files to extract YAML frontmatter metadata
public enum SkillParser: Sendable {
    public struct StandardMetadata: Sendable, Equatable {
        public let name: String
        public let description: String
        public let license: String?
        public let compatibility: String?
        public let metadata: [String: String]
        public let argumentHint: String?
        public let allowedTools: [String]
        public let warnings: [String]
    }

    /// Check if a directory is a valid skill directory (contains SKILL.md)
    /// - Parameter path: Path to the directory to check
    /// - Returns: true if the directory contains a valid SKILL.md file
    public nonisolated static func isSkillDirectory(at path: String) -> Bool {
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        return STFile(skillMdPath).isExists
    }
    
    /// Check if a directory is a valid skill directory and return skill name if valid
    /// - Parameter path: Path to the directory to check
    /// - Returns: The skill name (from frontmatter or directory name) if valid, nil otherwise
    public nonisolated static func skillName(at path: String) -> String? {
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard STFile(skillMdPath).isExists,
              let content = try? STFile(skillMdPath).read() else {
            return nil
        }
        
        let directoryName = (path as NSString).lastPathComponent
        
        // Try to extract name from frontmatter
        let metadata = FrontmatterParser.parseMetadata(from: content)
        if !metadata.isEmpty {
            return metadata["name"] ?? directoryName
        }
        
        return directoryName
    }

    /// Parse a SKILL.md file content
    /// - Parameters:
    ///   - content: The raw string content of the SKILL.md file
    ///   - id: The skill identifier (folder name)
    ///   - globalPath: Path to the skill folder in global storage
    /// - Returns: A parsed Skill model
    /// - Throws: SkillError.parsingFailed if parsing fails
    public nonisolated static func parse(
        content: String,
        id: String,
        globalPath: String
    ) throws -> Skill {
        if let standard = parseStandardMetadata(content: content, directoryName: id) {
            let version = standard.metadata["version"] ?? "1.0.0"
            return Skill(
                id: id,
                name: standard.name.isEmpty ? id : standard.name,
                description: standard.description.isEmpty ? "No description available" : standard.description,
                version: version,
                globalPath: globalPath,
                content: content
            )
        }

        // Parse YAML frontmatter
        let metadata = FrontmatterParser.parseMetadata(from: content)
        guard !metadata.isEmpty else {
            // If no frontmatter, use defaults
            return Skill(
                id: id,
                name: id,
                description: "No description available",
                version: "1.0.0",
                globalPath: globalPath,
                content: content
            )
        }

        let name = metadata["name"] ?? id
        let description = metadata["description"] ?? "No description available"
        let version = metadata["version"] ?? "1.0.0"

        return Skill(
            id: id,
            name: name,
            description: description,
            version: version,
            globalPath: globalPath,
            content: content
        )
    }

    /// Parse skills standard metadata from SKILL.md content.
    /// Reference: https://agentskills.io/specification
    public nonisolated static func parseStandardMetadata(
        content: String,
        directoryName: String?
    ) -> StandardMetadata? {
        guard let parsed = SkillSpecificationParser.parseStandardMetadata(
            from: content,
            directoryName: directoryName
        ) else {
            return nil
        }

        return StandardMetadata(
            name: parsed.name,
            description: parsed.description,
            license: parsed.license,
            compatibility: parsed.compatibility,
            metadata: parsed.metadata,
            argumentHint: parsed.argumentHint,
            allowedTools: parsed.allowedTools,
            warnings: parsed.warnings
        )
    }
}
