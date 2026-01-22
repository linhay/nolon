import Foundation

/// Parses SKILL.md files to extract YAML frontmatter metadata
public enum SkillParser {

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

    /// Parse simple YAML frontmatter into key-value pairs
    /// Supports single-line and multiline (|) values
    private static func parseYAMLFrontmatter(_ yaml: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentKey: String?
        var currentValue: [String] = []
        var isMultiline = false

        let lines = yaml.components(separatedBy: .newlines)

        for line in lines {
            if isMultiline {
                // Check if this line starts a new key (not indented)
                if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                    // Save previous multiline value
                    if let key = currentKey {
                        result[key] = currentValue.joined(separator: "\n").trimmingCharacters(
                            in: .whitespacesAndNewlines)
                    }
                    isMultiline = false
                    currentKey = nil
                    currentValue = []
                } else {
                    // Continue multiline value
                    let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
                    if !trimmed.isEmpty {
                        currentValue.append(trimmed)
                    }
                    continue
                }
            }

            // Parse key: value pairs
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueStart = line.index(after: colonIndex)
                let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)

                if value == "|" {
                    // Start multiline value
                    currentKey = key
                    currentValue = []
                    isMultiline = true
                } else if !value.isEmpty {
                    result[key] = value
                }
            }
        }

        // Don't forget the last multiline value
        if isMultiline, let key = currentKey {
            result[key] = currentValue.joined(separator: "\n").trimmingCharacters(
                in: .whitespacesAndNewlines)
        }

        return result
    }
}
