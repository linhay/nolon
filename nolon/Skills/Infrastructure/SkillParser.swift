import Yams
import Foundation

/// Parses SKILL.md files to extract YAML frontmatter metadata
public enum SkillParser: Sendable {

    /// Check if a directory is a valid skill directory (contains SKILL.md)
    /// - Parameter path: Path to the directory to check
    /// - Returns: true if the directory contains a valid SKILL.md file
    public static func isSkillDirectory(at path: String) -> Bool {
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        return FileManager.default.fileExists(atPath: skillMdPath)
    }
    
    /// Check if a directory is a valid skill directory and return skill name if valid
    /// - Parameter path: Path to the directory to check
    /// - Returns: The skill name (from frontmatter or directory name) if valid, nil otherwise
    public static func skillName(at path: String) -> String? {
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillMdPath),
              let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
            return nil
        }
        
        let directoryName = (path as NSString).lastPathComponent
        
        // Try to extract name from frontmatter
        if let frontmatter = extractFrontmatter(from: content) {
            let metadata = parseYAMLFrontmatter(frontmatter)
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
    public static func parse(
        content: String,
        id: String,
        globalPath: String
    ) throws -> Skill {
        // Extract frontmatter between --- markers
        guard let frontmatter = extractFrontmatter(from: content) else {
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

        // Parse YAML frontmatter
        let metadata = parseYAMLFrontmatter(frontmatter)

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

    /// Parse metadata from content with YAML frontmatter
    public static func parseMetadata(from content: String) -> [String: String] {
        guard let frontmatter = extractFrontmatter(from: content) else { return [:] }
        return parseYAMLFrontmatter(frontmatter)
    }
    
    /// Remove YAML frontmatter from content
    public static func stripFrontmatter(from content: String) -> String {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return content }
        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract frontmatter content between --- markers
    private static func extractFrontmatter(from content: String) -> String? {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
            let match = regex.firstMatch(
                in: content, options: [], range: NSRange(content.startIndex..., in: content)),
            let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        return String(content[range])
    }

    /// Parse YAML frontmatter using Yams
    private static func parseYAMLFrontmatter(_ yaml: String) -> [String: String] {
        guard let decoded = try? Yams.load(yaml: yaml) as? [String: Any] else {
            return [:]
        }
        
        var result: [String: String] = [:]
        for (key, value) in decoded {
            result[key] = "\(value)"
        }
        return result
    }
}
