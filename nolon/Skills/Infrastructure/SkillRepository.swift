import Foundation

/// Manages the global skills repository at ~/.nolon/skills/
public final class SkillRepository {

    private let fileManager: FileManager
    private let globalSkillsPath: String
    private let metadataPath: String

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let homePath = fileManager.homeDirectoryForCurrentUser.path
        self.globalSkillsPath = "\(homePath)/.nolon/skills"
        self.metadataPath = "\(globalSkillsPath)/.metadata.json"

        // Ensure global skills directory exists
        try? createGlobalDirectory()
    }

    // MARK: - Directory Management

    private func createGlobalDirectory() throws {
        if !fileManager.fileExists(atPath: globalSkillsPath) {
            try fileManager.createDirectory(
                atPath: globalSkillsPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - Skill Management

    /// List all skills in global storage
    public func listSkills() throws -> [Skill] {
        let metadata = try loadMetadata()
        var skills: [Skill] = []

        guard let contents = try? fileManager.contentsOfDirectory(atPath: globalSkillsPath) else {
            return []
        }

        for item in contents {
            // Skip hidden files and metadata
            if item.hasPrefix(".") { continue }

            let skillPath = "\(globalSkillsPath)/\(item)"
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: skillPath, isDirectory: &isDirectory),
                isDirectory.boolValue
            else {
                continue
            }

            // Try to parse SKILL.md
            let skillMdPath = "\(skillPath)/SKILL.md"
            guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
                continue
            }

            // Count additional files
            let referenceCount = countFiles(in: "\(skillPath)/references")
            let scriptCount = countFiles(in: "\(skillPath)/scripts")

            // Parse skill
            var skill = try SkillParser.parse(
                content: content,
                id: item,
                globalPath: skillPath
            )

            // Apply metadata
            if let meta = metadata.skills[item] {
                skill = skill.withInstalledProviders(meta.installedProviders)
            }

            // Update counts
            skill = Skill(
                id: skill.id,
                name: skill.name,
                description: skill.description,
                version: skill.version,
                globalPath: skill.globalPath,
                content: skill.content,
                installedProviders: skill.installedProviders,
                referenceCount: referenceCount,
                scriptCount: scriptCount
            )

            skills.append(skill)
        }

        return skills
    }

    /// Import a skill folder to global storage
    public func importSkill(from sourceURL: URL) throws -> Skill {
        let skillName = sourceURL.lastPathComponent
        let targetPath = "\(globalSkillsPath)/\(skillName)"

        // Check if skill already exists
        if fileManager.fileExists(atPath: targetPath) {
            throw SkillError.fileOperationFailed(
                "Skill '\(skillName)' already exists in global storage")
        }

        // Copy skill folder to global storage
        try fileManager.copyItem(atPath: sourceURL.path, toPath: targetPath)

        // Parse the imported skill
        let skillMdPath = "\(targetPath)/SKILL.md"
        guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
            throw SkillError.parsingFailed("SKILL.md not found in '\(skillName)'")
        }

        let referenceCount = countFiles(in: "\(targetPath)/references")
        let scriptCount = countFiles(in: "\(targetPath)/scripts")

        let skill = try SkillParser.parse(
            content: content,
            id: skillName,
            globalPath: targetPath
        )

        return Skill(
            id: skill.id,
            name: skill.name,
            description: skill.description,
            version: skill.version,
            globalPath: skill.globalPath,
            content: skill.content,
            installedProviders: skill.installedProviders,
            referenceCount: referenceCount,
            scriptCount: scriptCount
        )
    }

    /// Delete a skill from global storage
    public func deleteSkill(id: String) throws {
        let skillPath = "\(globalSkillsPath)/\(id)"

        guard fileManager.fileExists(atPath: skillPath) else {
            throw SkillError.skillNotFound(id: id)
        }

        try fileManager.removeItem(atPath: skillPath)

        // Remove from metadata
        var metadata = try loadMetadata()
        metadata.skills.removeValue(forKey: id)
        try saveMetadata(metadata)
    }

    // MARK: - Metadata Management

    /// Load metadata from disk
    public func loadMetadata() throws -> SkillMetadataStore {
        guard fileManager.fileExists(atPath: metadataPath),
            let data = try? Data(contentsOf: URL(fileURLWithPath: metadataPath))
        else {
            return SkillMetadataStore()
        }

        let decoder = JSONDecoder()
        return (try? decoder.decode(SkillMetadataStore.self, from: data)) ?? SkillMetadataStore()
    }

    /// Save metadata to disk
    public func saveMetadata(_ metadata: SkillMetadataStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(to: URL(fileURLWithPath: metadataPath))
    }

    /// Update metadata for a specific skill
    public func updateMetadata(for skillId: String, installedProviders: Set<SkillProvider>) throws {
        var metadata = try loadMetadata()
        metadata.skills[skillId] = SkillMetadata(
            id: skillId,
            installedProviders: installedProviders,
            lastUpdated: Date()
        )
        try saveMetadata(metadata)
    }

    // MARK: - Helpers

    private func countFiles(in directory: String) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return 0
        }
        return contents.filter { !$0.hasPrefix(".") }.count
    }
}
