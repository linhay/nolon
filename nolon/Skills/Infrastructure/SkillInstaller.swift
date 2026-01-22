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
    public func install(skill: Skill, to provider: Provider) throws {
        let providerPath = provider.path
        let targetPath = "\(providerPath)/\(skill.id)"

        // Check if already exists
        if fileManager.fileExists(atPath: targetPath) {
            throw SkillError.symlinkFailed("Skill already exists at '\(targetPath)'")
        }

        // Ensure provider directory exists
        try createDirectory(at: providerPath)

        // Check installation method
        let method = provider.installMethod

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
    }

    /// Install a remote skill from a zip file
    /// 1. Extract to global storage (~/.nolon/skills)
    /// 2. Link/copy to provider directory based on provider settings
    public func installRemote(zipURL: URL, slug: String, to provider: Provider) throws {
        let globalSkillsPath = "\(fileManager.homeDirectoryForCurrentUser.path)/.nolon/skills"
        let globalPath = "\(globalSkillsPath)/\(slug)"

        // Check if already exists in global storage
        let skillExistsInGlobal = fileManager.fileExists(atPath: globalPath)

        // If not in global storage, extract there first
        if !skillExistsInGlobal {
            // Ensure global skills directory exists
            try createDirectory(at: globalSkillsPath)

            // Create temp directory for extraction
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            defer {
                try? fileManager.removeItem(at: tempDir)
                try? fileManager.removeItem(at: zipURL)
            }

            // Unzip
            try unzip(zipURL, to: tempDir)

            // Find skill root (the directory containing SKILL.md)
            guard let skillRoot = findSkillRoot(in: tempDir) else {
                throw SkillError.parsingFailed("No valid skill found in the downloaded package")
            }

            // Move to global storage
            try fileManager.moveItem(at: skillRoot, to: URL(fileURLWithPath: globalPath))

            // Write origin info
            try writeClawdhubOrigin(at: URL(fileURLWithPath: globalPath), slug: slug)
        }

        // Now load the skill from global storage
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
            throw SkillError.parsingFailed("SKILL.md not found in '\(slug)'")
        }

        let parsedSkill = try SkillParser.parse(
            content: content,
            id: slug,
            globalPath: globalPath
        )

        let skill = Skill(
            id: parsedSkill.id,
            name: parsedSkill.name,
            description: parsedSkill.description,
            version: parsedSkill.version,
            globalPath: parsedSkill.globalPath,
            content: parsedSkill.content,
            referenceCount: 0,
            scriptCount: 0
        )

        // Install to provider (symlink or copy based on provider settings)
        try install(skill: skill, to: provider)
    }

    private func unzip(_ url: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, destination.path]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SkillError.fileOperationFailed("Failed to unzip skill package")
        }
    }

    /// Install a skill from a local path (e.g. cloned GitHub repo)
    /// 1. Symlink to global storage (~/.nolon/skills) to register it
    /// 2. Link/copy to provider directory based on provider settings
    public func installLocal(from sourcePath: String, slug: String, to provider: Provider) throws {
        let globalSkillsPath = "\(fileManager.homeDirectoryForCurrentUser.path)/.nolon/skills"
        let globalPath = "\(globalSkillsPath)/\(slug)"

        // Ensure global skills directory exists
        try createDirectory(at: globalSkillsPath)

        // Register in global storage (Symlink Global -> Source)
        // If it already exists, replace it to ensure we are using the requested version
        if fileManager.fileExists(atPath: globalPath) {
            try fileManager.removeItem(atPath: globalPath)
        }

        try fileManager.createSymbolicLink(atPath: globalPath, withDestinationPath: sourcePath)

        // Now load the skill from global storage
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
            throw SkillError.parsingFailed("SKILL.md not found in '\(slug)'")
        }

        let parsedSkill = try SkillParser.parse(
            content: content,
            id: slug,
            globalPath: globalPath
        )

        let skill = Skill(
            id: parsedSkill.id,
            name: parsedSkill.name,
            description: parsedSkill.description,
            version: parsedSkill.version,
            globalPath: parsedSkill.globalPath,
            content: parsedSkill.content,
            referenceCount: 0,
            scriptCount: 0
        )

        // Install to provider
        try install(skill: skill, to: provider)
    }

    private func findSkillRoot(in rootURL: URL) -> URL? {
        let directSkill = rootURL.appendingPathComponent("SKILL.md")
        if fileManager.fileExists(atPath: directSkill.path) {
            return rootURL
        }

        guard
            let children = try? fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return nil
        }

        let candidateDirs = children.compactMap { url -> URL? in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }
            let skillFile = url.appendingPathComponent("SKILL.md")
            return fileManager.fileExists(atPath: skillFile.path) ? url : nil
        }

        if candidateDirs.count == 1 {
            return candidateDirs[0]
        }

        return nil
    }

    private func writeClawdhubOrigin(at skillRoot: URL, slug: String) throws {
        let originDir = skillRoot.appendingPathComponent(".clawdhub")
        try createDirectory(at: originDir.path)

        let originURL = originDir.appendingPathComponent("origin.json")
        let payload: [String: Any] = [
            "slug": slug,
            "source": "clawdhub",
            "installedAt": Int(Date().timeIntervalSince1970),
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try data.write(to: originURL, options: [.atomic])
    }

    /// Uninstall a skill from a provider
    public func uninstall(skill: Skill, from provider: Provider) throws {
        let providerPath = provider.path
        let targetPath = "\(providerPath)/\(skill.id)"

        guard fileManager.fileExists(atPath: targetPath) else {
            return  // Already uninstalled
        }

        try fileManager.removeItem(atPath: targetPath)
    }

    // MARK: - Provider Scanning

    /// Scan a provider directory and return skill states
    public func scanProvider(provider: Provider) throws -> [ProviderSkillState] {
        let providerPath = provider.path

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
            let state = determineSkillState(skillName: item, at: itemPath, for: provider)

            states.append(
                ProviderSkillState(
                    skillName: item,
                    state: state,
                    path: itemPath
                ))
        }

        return states
    }

    /// Determine the state of a skill at a given path based on provider's install method
    private func determineSkillState(skillName: String, at path: String, for provider: Provider)
        -> SkillInstallationState
    {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .broken
        }

        // Check if it's a symlink
        let isSymlink: Bool
        if let attributes = try? fileManager.attributesOfItem(atPath: path),
            attributes[.type] as? FileAttributeType == .typeSymbolicLink
        {
            isSymlink = true

            // Check if symlink target exists
            guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: path),
                fileManager.fileExists(atPath: destination)
            else {
                return .broken
            }
        } else {
            isSymlink = false
        }

        switch provider.installMethod {
        case .symlink:
            // For symlink mode: symlinks are installed, non-symlinks are orphaned
            return isSymlink ? .installed : .orphaned

        case .copy:
            // For copy mode: compare with global storage
            if isSymlink {
                // Symlinks in copy mode are unexpected but treat as installed
                return .installed
            }

            // Check if skill exists in global storage
            let globalPath =
                "\(fileManager.homeDirectoryForCurrentUser.path)/.nolon/skills/\(skillName)"
            guard fileManager.fileExists(atPath: globalPath) else {
                // Not in global storage -> orphaned
                return .orphaned
            }

            // Compare versions
            if skillsAreDifferent(providerPath: path, globalPath: globalPath) {
                return .orphaned
            }

            return .installed
        }
    }

    /// Compare two skill folders to check if they are different (by version)
    private func skillsAreDifferent(providerPath: String, globalPath: String) -> Bool {
        let providerSkillMd = "\(providerPath)/SKILL.md"
        let globalSkillMd = "\(globalPath)/SKILL.md"

        // If either SKILL.md doesn't exist, consider them different
        guard let providerContent = try? String(contentsOfFile: providerSkillMd, encoding: .utf8),
            let globalContent = try? String(contentsOfFile: globalSkillMd, encoding: .utf8)
        else {
            return true
        }

        // Parse versions from both
        let providerVersion = parseVersion(from: providerContent)
        let globalVersion = parseVersion(from: globalContent)

        // If versions differ, they're different
        if providerVersion != globalVersion {
            return true
        }

        // Also compare file modification dates as a fallback
        let providerModDate =
            (try? fileManager.attributesOfItem(atPath: providerSkillMd)[.modificationDate] as? Date)
            ?? Date.distantPast
        let globalModDate =
            (try? fileManager.attributesOfItem(atPath: globalSkillMd)[.modificationDate] as? Date)
            ?? Date.distantPast

        // If provider is newer by more than a second, consider different
        return providerModDate.timeIntervalSince(globalModDate) > 1.0
    }

    /// Parse version from SKILL.md content
    private func parseVersion(from content: String) -> String {
        // Look for version in YAML frontmatter
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("version:") {
                return trimmed.replacingOccurrences(of: "version:", with: "").trimmingCharacters(
                    in: .whitespaces)
            }
        }
        return "unknown"
    }

    // MARK: - Migration

    /// Migrate a skill from provider directory to global storage
    /// - Parameters:
    ///   - skillName: Name of the skill to migrate
    ///   - provider: The provider to migrate from
    ///   - overwriteExisting: If true, overwrite existing skill in global storage when different
    /// - Returns: The imported skill
    ///
    /// Migration scenarios:
    /// 1. Skill identical to global → delete provider copy, reinstall from global
    /// 2. Skill not in global → move to global, install back per provider settings
    /// 3. Skill in global but different → if overwriteExisting, replace global; else throw conflict
    public func migrate(skillName: String, from provider: Provider, overwriteExisting: Bool = false)
        throws -> Skill
    {
        let providerPath = provider.path
        let sourcePath = "\(providerPath)/\(skillName)"

        // Verify it's a physical directory (not a symlink for symlink mode, or different for copy mode)
        let state = determineSkillState(skillName: skillName, at: sourcePath, for: provider)
        guard state == .orphaned else {
            throw SkillError.fileOperationFailed(
                "Skill '\(skillName)' is not an orphaned physical file")
        }

        let globalPath =
            "\(fileManager.homeDirectoryForCurrentUser.path)/.nolon/skills/\(skillName)"

        let globalExists = fileManager.fileExists(atPath: globalPath)

        if globalExists {
            // Check if identical to global
            if !skillsAreDifferent(providerPath: sourcePath, globalPath: globalPath) {
                // Scenario 1: Identical content - just delete provider copy and reinstall from global
                try fileManager.removeItem(atPath: sourcePath)
            } else {
                // Scenario 3: Different content - need user decision
                if overwriteExisting {
                    // Remove existing global skill and replace with provider version
                    try fileManager.removeItem(atPath: globalPath)
                    try fileManager.moveItem(atPath: sourcePath, toPath: globalPath)
                } else {
                    throw SkillError.conflictDetected(skillName: skillName, providers: [])
                }
            }
        } else {
            // Scenario 2: Not in global - move to global storage
            try fileManager.moveItem(atPath: sourcePath, toPath: globalPath)
        }

        // Install back to provider based on settings
        let method = provider.installMethod
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

        let skill = try SkillParser.parse(
            content: content,
            id: skillName,
            globalPath: globalPath
        )

        return skill
    }

    /// Migrate all orphaned skills from a provider
    public func migrateAll(from provider: Provider) throws -> [Skill] {
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

    // MARK: - Query
    
    /// Find all installed skills across all providers
    public func findAllInstalledSkills() -> Set<String> {
        var installedSkills: Set<String> = []
        
        for provider in settings.providers {
            if let states = try? scanProvider(provider: provider) {
                for state in states {
                    if state.state == .installed {
                        installedSkills.insert(state.skillName)
                    }
                }
            }
        }
        
        return installedSkills
    }

    // MARK: - Health Checks

    /// Validate all symlinks and return broken ones
    public func validateSymlinks() throws -> [ProviderSkillState] {
        var brokenLinks: [ProviderSkillState] = []

        for provider in settings.providers {
            let states = try scanProvider(provider: provider)
            let broken = states.filter { $0.state == .broken }
            brokenLinks.append(contentsOf: broken)
        }

        return brokenLinks
    }

    /// Repair a broken symlink by recreating it
    public func repairSymlink(skillName: String, for provider: Provider) throws {
        let providerPath = provider.path
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

        // Recreate based on provider's install method
        let method = provider.installMethod
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
