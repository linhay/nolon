import Foundation
import STFilePath

/// Manages the global skills repository at ~/.nolon/skills/
public final class SkillRepository {

    private let nolonManager: NolonManager
    private var globalSkillsPath: String { nolonManager.skillsPath }
    private var metadataPath: String { "\(globalSkillsPath)/.metadata.json" }

    public init(nolonManager: NolonManager = .shared) {
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

        let globalFolder = STFolder(globalSkillsPath)
        guard let folders = try? globalFolder.folders() else {
            return []
        }

        for folder in folders {
            let item = folder.url.lastPathComponent
            if item.hasPrefix(".") { continue }

            let skillPath = folder.url.path

            let skillMdFile = folder.file("SKILL.md")
            guard let content = try? skillMdFile.read() else {
                continue
            }

            // Count additional files
            let referenceCount = countFiles(in: folder.folder("references"))
            let scriptCount = countFiles(in: folder.folder("scripts"))

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
        if STPath(targetPath).isExists {
            throw SkillError.fileOperationFailed(
                "Skill '\(skillName)' already exists in global storage")
        }

        // Copy skill folder to global storage
        try STPath(sourceURL).copy(to: STPath(targetPath))

        // Parse the imported skill
        let skillMdPath = "\(targetPath)/SKILL.md"
        guard let content = try? STFile(skillMdPath).read() else {
            throw SkillError.parsingFailed("SKILL.md not found in '\(skillName)'")
        }

        let importedFolder = STFolder(targetPath)
        let referenceCount = countFiles(in: importedFolder.folder("references"))
        let scriptCount = countFiles(in: importedFolder.folder("scripts"))

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

        guard STPath(skillPath).isExists else {
            throw SkillError.skillNotFound(id: id)
        }

        try STPath(skillPath).deleteIncludingBrokenSymlink()

        // Remove from metadata
        var metadata = try loadMetadata()
        metadata.skills.removeValue(forKey: id)
        try saveMetadata(metadata)
        
        // Remove global workflow if exists
        let workflowPath = "\(nolonManager.generatedWorkflowsPath)/\(id).md"
        if STPath(workflowPath).isExists {
            try? STPath(workflowPath).deleteIncludingBrokenSymlink()
        }
    }
    
    // MARK: - Workflow Management
    
    /// Create a global workflow file for a skill
    public func createGlobalWorkflow(for skill: Skill) throws -> String {
        let path = "\(nolonManager.generatedWorkflowsPath)/\(skill.id).md"
        
        // Always overwrite to ensure content is up to date with skill changes
        try STFile(path).overlay(with: skill.workflowContent)
        
        return path
    }

    // MARK: - Metadata Management

    /// Load metadata from disk
    public func loadMetadata() throws -> SkillMetadataStore {
        let metadataFile = STFile(metadataPath)
        guard metadataFile.isExists,
            let data = try? metadataFile.data()
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
        try STFile(metadataPath).overlay(with: data)
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

    private func countFiles(in directory: STFolder) -> Int {
        guard let contents = try? directory.subFilePaths() else {
            return 0
        }
        return contents.filter { !$0.url.lastPathComponent.hasPrefix(".") }.count
    }
}
