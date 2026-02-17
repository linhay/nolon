import Foundation
import Yams

/// Parses YAML frontmatter metadata from Markdown content.
public enum FrontmatterParser: Sendable {
    
    /// Parse metadata from content with YAML frontmatter.
    public nonisolated static func parseMetadata(from content: String) -> [String: String] {
        guard let frontmatter = extractFrontmatter(from: content) else { return [:] }
        return parseYAMLFrontmatter(frontmatter)
    }

    /// Parse raw metadata object from content with YAML frontmatter.
    public nonisolated static func parseMetadataObject(from content: String) -> [String: Any]? {
        guard let frontmatter = extractFrontmatter(from: content) else { return nil }
        return parseYAMLFrontmatterObject(frontmatter)
    }
    
    /// Remove YAML frontmatter from content.
    public nonisolated static func stripFrontmatter(from content: String) -> String {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return content }
        let range = NSRange(content.startIndex..., in: content)
        return regex
            .stringByReplacingMatches(in: content, options: [], range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Private
    
    /// Extract frontmatter content between --- markers.
    private nonisolated static func extractFrontmatter(from content: String) -> String? {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
              ),
              let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        return String(content[range])
    }
    
    /// Parse YAML frontmatter using Yams.
    private nonisolated static func parseYAMLFrontmatter(_ yaml: String) -> [String: String] {
        guard let decoded = parseYAMLFrontmatterObject(yaml) else {
            return [:]
        }
        
        var result: [String: String] = [:]
        for (key, value) in decoded {
            result[key] = "\(value)"
        }
        return result
    }

    private nonisolated static func parseYAMLFrontmatterObject(_ yaml: String) -> [String: Any]? {
        return try? Yams.load(yaml: yaml) as? [String: Any]
    }
}
