import Foundation

/// Manages the global skills repository at ~/.nolon/skills/
public final class SkillRepository {

    private let fileManager: FileManager
    private let nolonManager: NolonManager
    private var globalSkillsPath: String { nolonManager.skillsPath }
    private var metadataPath: String { "\(globalSkillsPath)/.metadata.json" }

    public init(fileManager: FileManager = .default, nolonManager: NolonManager = .shared) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
        // Directories are ensured by NolonManager
    }

    // MARK: - Directory Management

    private func createGlobalDirectory() throws {
        // Handled by NolonManager
    }

    // MARK: - Skill Management

    /// List all skills in global storage
    public func listSkills() throws -> [Skill] {
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
            guard let parsedSkill = try? SkillParser.parse(
                content: content,
                id: item,
                globalPath: skillPath
            ) else {
                continue
            }

            // Create skill with counts
            let skill = Skill(
                id: parsedSkill.id,
                name: parsedSkill.name,
                description: parsedSkill.description,
                version: parsedSkill.version,
                globalPath: parsedSkill.globalPath,
                content: parsedSkill.content,
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

        let parsedSkill = try SkillParser.parse(
            content: content,
            id: skillName,
            globalPath: targetPath
        )

        return Skill(
            id: parsedSkill.id,
            name: parsedSkill.name,
            description: parsedSkill.description,
            version: parsedSkill.version,
            globalPath: parsedSkill.globalPath,
            content: parsedSkill.content,
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
        
        // Remove global workflow if exists
        let workflowPath = "\(nolonManager.generatedWorkflowsPath)/\(id).md"
        if fileManager.fileExists(atPath: workflowPath) {
            try? fileManager.removeItem(atPath: workflowPath)
        }
    }
    
    // MARK: - Workflow Management
    
    /// Create a global workflow file for a skill
    public func createGlobalWorkflow(for skill: Skill) throws -> String {
        let path = "\(nolonManager.generatedWorkflowsPath)/\(skill.id).md"
        
        // Always overwrite to ensure content is up to date with skill changes
        try skill.workflowContent.write(toFile: path, atomically: true, encoding: .utf8)
        
        return path
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
    public func updateMetadata(for skillId: String, lastUpdated: Date = Date(), sourceURL: String? = nil) throws {
        var metadata = try loadMetadata()
        metadata.skills[skillId] = SkillMetadata(
            id: skillId,
            lastUpdated: lastUpdated,
            sourceURL: sourceURL
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
