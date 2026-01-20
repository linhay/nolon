import Foundation

/// Skill state in a provider directory
public struct ProviderSkillState: Sendable {
    public let skillName: String
    public let state: SkillInstallationState
    public let path: String

    public init(skillName: String, state: SkillInstallationState, path: String) {
        self.skillName = skillName
        self.state = state
        self.path = path
    }
}

/// Handles skill installation via symlinks, migration, and health checks
public final class SkillInstaller {

    private let fileManager: FileManager
    private let repository: SkillRepository
    private let settings: ProviderSettings

    public init(
        fileManager: FileManager = .default,
        repository: SkillRepository,
        settings: ProviderSettings
    ) {
        self.fileManager = fileManager
        self.repository = repository
        self.settings = settings
    }

    // MARK: - Installation

    /// Install a skill to a provider
    public func install(skill: Skill, to provider: SkillProvider) throws {
        let providerPath = settings.path(for: provider).path
        let targetPath = "\(providerPath)/\(skill.id)"

        // Check if already exists
        if fileManager.fileExists(atPath: targetPath) {
            throw SkillError.symlinkFailed("Skill already exists at '\(targetPath)'")
        }

        // Ensure provider directory exists
        try createDirectory(at: providerPath)

        // Check installation method
        let method = settings.method(for: provider)

        switch method {
        case .symlink:
            // Create symlink
            try fileManager.createSymbolicLink(
                atPath: targetPath,
                withDestinationPath: skill.globalPath
            )
        case .copy:
            // Copy directory
            try fileManager.copyItem(atPath: skill.globalPath, toPath: targetPath)
        }

        // Update metadata
        var installedProviders = skill.installedProviders
        installedProviders.insert(provider)
        try repository.updateMetadata(for: skill.id, installedProviders: installedProviders)
    }

    /// Uninstall a skill from a provider
    public func uninstall(skill: Skill, from provider: SkillProvider) throws {
        let providerPath = settings.path(for: provider).path
        let targetPath = "\(providerPath)/\(skill.id)"

        guard fileManager.fileExists(atPath: targetPath) else {
            return  // Already uninstalled
        }

        try fileManager.removeItem(atPath: targetPath)

        // Update metadata
        var installedProviders = skill.installedProviders
        installedProviders.remove(provider)
        try repository.updateMetadata(for: skill.id, installedProviders: installedProviders)
    }
    
    // MARK: - Custom Provider Installation
    
    /// Install a skill to a custom provider
    public func installToCustomProvider(skill: Skill, customProvider: CustomProvider) throws {
        let providerPath = customProvider.path
        let targetPath = "\(providerPath)/\(skill.id)"

        // Check if already exists
        if fileManager.fileExists(atPath: targetPath) {
            throw SkillError.symlinkFailed("Skill already exists at '\(targetPath)'")
        }

        // Ensure provider directory exists
        try createDirectory(at: providerPath)

        // Always use symlink for custom providers
        try fileManager.createSymbolicLink(
            atPath: targetPath,
            withDestinationPath: skill.globalPath
        )
    }
    
    /// Uninstall a skill from a custom provider
    public func uninstallFromCustomProvider(skill: Skill, customProvider: CustomProvider) throws {
        let providerPath = customProvider.path
        let targetPath = "\(providerPath)/\(skill.id)"

        guard fileManager.fileExists(atPath: targetPath) else {
            return  // Already uninstalled
        }

        try fileManager.removeItem(atPath: targetPath)
    }
    
    /// Scan a custom provider directory and return skill states
    public func scanCustomProvider(customProvider: CustomProvider) throws -> [ProviderSkillState] {
        let providerPath = customProvider.path

        guard fileManager.fileExists(atPath: providerPath) else {
            return []
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: providerPath) else {
            return []
        }

        var states: [ProviderSkillState] = []

        for item in contents {
            // Skip hidden files
            if item.hasPrefix(".") { continue }

            let itemPath = "\(providerPath)/\(item)"
            let state = determineSkillState(at: itemPath)

            states.append(
                ProviderSkillState(
                    skillName: item,
                    state: state,
                    path: itemPath
                ))
        }

        return states
    }

    // MARK: - Provider Scanning

    /// Scan a provider directory and return skill states
    public func scanProvider(provider: SkillProvider) throws -> [ProviderSkillState] {
        let providerPath = settings.path(for: provider).path

        guard fileManager.fileExists(atPath: providerPath) else {
            return []
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: providerPath) else {
            return []
        }

        var states: [ProviderSkillState] = []

        for item in contents {
            // Skip hidden files
            if item.hasPrefix(".") { continue }

            let itemPath = "\(providerPath)/\(item)"
            let state = determineSkillState(at: itemPath)

            states.append(
                ProviderSkillState(
                    skillName: item,
                    state: state,
                    path: itemPath
                ))
        }

        return states
    }

    /// Determine the state of a skill at a given path
    private func determineSkillState(at path: String) -> SkillInstallationState {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .broken
        }

        // Check if it's a symlink
        if let attributes = try? fileManager.attributesOfItem(atPath: path),
            attributes[.type] as? FileAttributeType == .typeSymbolicLink
        {

            // Check if symlink target exists
            guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: path),
                fileManager.fileExists(atPath: destination)
            else {
                return .broken
            }

            return .installed
        }

        // If it is a directory and not a symlink, it is 'orphaned' (unmanaged) or 'installed via copy'
        // For scan purposes, we check if it matches a known global skill to decide?
        // Current logic treats physical dirs as 'orphaned', which is correct for migration detection.
        // It complicates 'installed' detection if we use Copy mode.
        // For now, we leave it as orphaned/physical. Application layer checks if matches metadata.
        return .orphaned
    }

    // MARK: - Migration

    /// Migrate a skill from provider directory to global storage
    /// Returns the imported skill
    public func migrate(skillName: String, from provider: SkillProvider) throws -> Skill {
        let providerPath = settings.path(for: provider).path
        let sourcePath = "\(providerPath)/\(skillName)"

        // Verify it's a physical directory (not a symlink)
        let state = determineSkillState(at: sourcePath)
        guard state == .orphaned else {
            throw SkillError.fileOperationFailed(
                "Skill '\(skillName)' is not an orphaned physical file")
        }

        // Check for conflicts in global storage
        let globalPath =
            "\(fileManager.homeDirectoryForCurrentUser.path)/.nolon/skills/\(skillName)"
        if fileManager.fileExists(atPath: globalPath) {
            // Conflict detected - need user resolution
            throw SkillError.conflictDetected(skillName: skillName, providers: [provider])
        }

        // Move to global storage
        try fileManager.moveItem(atPath: sourcePath, toPath: globalPath)

        // Install back to provider based on settings
        let method = settings.method(for: provider)
        switch method {
        case .symlink:
            try fileManager.createSymbolicLink(
                atPath: sourcePath,
                withDestinationPath: globalPath
            )
        case .copy:
            try fileManager.copyItem(atPath: globalPath, toPath: sourcePath)
        }

        // Parse and return the skill
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
            throw SkillError.parsingFailed("SKILL.md not found in '\(skillName)'")
        }

        var skill = try SkillParser.parse(
            content: content,
            id: skillName,
            globalPath: globalPath
        )

        // Update metadata
        skill = skill.installing(for: provider)
        try repository.updateMetadata(for: skill.id, installedProviders: skill.installedProviders)

        return skill
    }

    /// Migrate all orphaned skills from a provider
    public func migrateAll(from provider: SkillProvider) throws -> [Skill] {
        let states = try scanProvider(provider: provider)
        let orphaned = states.filter { $0.state == .orphaned }

        var migratedSkills: [Skill] = []

        for orphanedSkill in orphaned {
            do {
                let skill = try migrate(skillName: orphanedSkill.skillName, from: provider)
                migratedSkills.append(skill)
            } catch {
                // Log error but continue with other skills
                print("Failed to migrate '\(orphanedSkill.skillName)': \(error)")
            }
        }

        return migratedSkills
    }

    // MARK: - Health Checks

    /// Validate all symlinks and return broken ones
    public func validateSymlinks() throws -> [ProviderSkillState] {
        var brokenLinks: [ProviderSkillState] = []

        for provider in SkillProvider.allCases {
            let states = try scanProvider(provider: provider)
            let broken = states.filter { $0.state == .broken }
            brokenLinks.append(contentsOf: broken)
        }

        return brokenLinks
    }

    /// Repair a broken symlink by recreating it
    public func repairSymlink(skillName: String, for provider: SkillProvider) throws {
        let providerPath = settings.path(for: provider).path
        let targetPath = "\(providerPath)/\(skillName)"
        let globalPath =
            "\(fileManager.homeDirectoryForCurrentUser.path)/.nolon/skills/\(skillName)"

        // Remove broken symlink
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }

        // Verify global skill exists
        guard fileManager.fileExists(atPath: globalPath) else {
            throw SkillError.skillNotFound(id: skillName)
        }

        // Recreate symlink (Always repair with symlink? Or respect settings?)
        // Let's respect settings
        let method = settings.method(for: provider)
        switch method {
        case .symlink:
            try fileManager.createSymbolicLink(
                atPath: targetPath,
                withDestinationPath: globalPath
            )
        case .copy:
            try fileManager.copyItem(atPath: globalPath, toPath: targetPath)
        }
    }

    // MARK: - Helpers

    private func createDirectory(at path: String) throws {
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
