import Foundation

/// Service for scanning local folders for skills
public struct LocalFolderService {
    
    private let fileManager: FileManager
    private let skillParser: SkillParser.Type
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.skillParser = SkillParser.self
    }
    
    /// Scans a directory for skill folders (directories containing SKILL.md)
    public func fetchSkills(from path: String) async throws -> [RemoteSkill] {
        guard fileManager.fileExists(atPath: path) else {
            throw LocalFolderError.pathNotFound(path)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LocalFolderError.notADirectory(path)
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            throw LocalFolderError.cannotReadDirectory(path)
        }

        var skills: [RemoteSkill] = []

        // Check for SKILL.md in the root path
        let rootSkillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        if fileManager.fileExists(atPath: rootSkillMdPath) {
            let rootSlug = (path as NSString).lastPathComponent
            if let skill = try? parseSkill(at: path, skillMdPath: rootSkillMdPath, slug: rootSlug) {
                // If the directory itself is a skill, do not scan subdirectories for other skills
                return [skill]
            }
        }

        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var itemIsDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: itemPath, isDirectory: &itemIsDirectory),
                  itemIsDirectory.boolValue else {
                continue
            }

            // Check if this directory contains SKILL.md
            let skillMdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillMdPath) else {
                continue
            }

            // Parse SKILL.md to get skill info
            if let skill = try? parseSkill(at: itemPath, skillMdPath: skillMdPath, slug: item) {
                skills.append(skill)
            }
        }

        return skills.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Scans multiple directories for skill folders and aggregates results
    public func fetchSkills(fromPaths paths: [String]) async throws -> [RemoteSkill] {
        var allSkills: [RemoteSkill] = []

        for path in paths {
            do {
                let skills = try await fetchSkills(from: path)
                allSkills.append(contentsOf: skills)
            } catch {
                continue
            }
        }

        var seenSlugs = Set<String>()
        return allSkills
            .filter { skill in
                if seenSlugs.contains(skill.slug) {
                    return false
                }
                seenSlugs.insert(skill.slug)
                return true
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    /// Parses a skill from its SKILL.md file
    private func parseSkill(at path: String, skillMdPath: String, slug: String) throws -> RemoteSkill {
        let content = try String(contentsOfFile: skillMdPath, encoding: .utf8)
        let parsed = try SkillParser.parse(content: content, id: slug, globalPath: path)
        
        // Get file modification date
        let attributes = try? fileManager.attributesOfItem(atPath: skillMdPath)
        let modificationDate = attributes?[.modificationDate] as? Date
        
        return RemoteSkill(
            slug: slug,
            displayName: parsed.name,
            summary: parsed.description,
            latestVersion: parsed.version,
            updatedAt: modificationDate,
            downloads: nil,
            stars: nil,
            localPath: path
        )
    }
    
    /// Gets detailed skill information
    public func fetchSkillDetail(at path: String) async throws -> Skill? {
        let skillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        guard fileManager.fileExists(atPath: skillMdPath) else {
            return nil
        }
        
        let content = try String(contentsOfFile: skillMdPath, encoding: .utf8)
        let slug = (path as NSString).lastPathComponent
        
        let referenceCount = countFiles(in: (path as NSString).appendingPathComponent("references"))
        let scriptCount = countFiles(in: (path as NSString).appendingPathComponent("scripts"))
        
        let parsed = try SkillParser.parse(content: content, id: slug, globalPath: path)
        
        return Skill(
            id: parsed.id,
            name: parsed.name,
            description: parsed.description,
            version: parsed.version,
            globalPath: parsed.globalPath,
            content: parsed.content,
            referenceCount: referenceCount,
            scriptCount: scriptCount
        )
    }
    
    private func countFiles(in directory: String) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return 0
        }
        return contents.filter { !$0.hasPrefix(".") }.count
    }
}

// MARK: - Errors

public enum LocalFolderError: LocalizedError {
    case pathNotFound(String)
    case notADirectory(String)
    case cannotReadDirectory(String)
    case skillParsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return NSLocalizedString("error.path_not_found", comment: "Path not found: \(path)")
        case .notADirectory(let path):
            return NSLocalizedString("error.not_a_directory", comment: "Not a directory: \(path)")
        case .cannotReadDirectory(let path):
            return NSLocalizedString("error.cannot_read_directory", comment: "Cannot read directory: \(path)")
        case .skillParsingFailed(let reason):
            return NSLocalizedString("error.skill_parsing_failed", comment: "Failed to parse skill: \(reason)")
        }
    }
}
