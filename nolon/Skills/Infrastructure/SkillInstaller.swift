import Foundation
import STJSON
import STFilePath
import OSLog

/// Skill state in a provider directory
public struct ProviderSkillState: Sendable {
    public let skillName: String
    public let state: SkillInstallationState
    public let path: String
    public let basePath: String // Path from which this skill was found

    public init(skillName: String, state: SkillInstallationState, path: String, basePath: String) {
        self.skillName = skillName
        self.state = state
        self.path = path
        self.basePath = basePath
    }
}

/// Handles skill installation via symlinks, migration, and health checks
public final class SkillInstaller {
    private static let logger = Logger(subsystem: "com.nolon", category: "SkillInstaller")

    private let repository: SkillRepository
    private let settings: ProviderSettings
    private let nolonManager: NolonManager
    private let lockFileManager: SkillLockFileManager

    public init(
        repository: SkillRepository,
        settings: ProviderSettings,
        nolonManager: NolonManager = .shared,
        lockFileManager: SkillLockFileManager = SkillLockFileManager()
    ) {
        self.repository = repository
        self.settings = settings
        self.nolonManager = nolonManager
        self.lockFileManager = lockFileManager
    }

    // MARK: - Installation

    /// Install a skill to a provider
    public func install(skill: Skill, to provider: Provider) throws {
        let providerPath = provider.defaultSkillsPath
        let targetPath = "\(providerPath)/\(skill.id)"

        // If already exists, remove it first to allow reinstall/update
        try STPath(targetPath).deleteIncludingBrokenSymlink()

        // Ensure provider directory exists
        STFolder(providerPath).createIfNotExists()

        // Check installation method
        let method = provider.installMethod

        switch method {
        case .symlink:
            try STPath(targetPath).createSymbolicLink(to: STPath(skill.globalPath))
        case .copy:
            try STPath(skill.globalPath).copy(to: STPath(targetPath), isOverlay: true)
        }
    }

    /// Install a remote skill from a zip file
    /// 1. Extract to global storage (~/.nolon/skills)
    /// 2. Link/copy to provider directory based on provider settings
    public func installRemote(zipURL: URL, slug: String, to provider: Provider) throws {
        let globalSkillsPath = nolonManager.skillsPath
        let globalPath = "\(globalSkillsPath)/\(slug)"

        // Check if already exists in global storage
        let skillExistsInGlobal = STPath(globalPath).isExists

        // If not in global storage, extract there first
        if !skillExistsInGlobal {
            // Ensure global skills directory exists
            STFolder(globalSkillsPath).createIfNotExists()

            // Create temp directory for extraction
            let tempDir = try STFolder(sanbox: .temporary).folder(UUID().uuidString).create()

            defer {
                try? tempDir.deleteIncludingBrokenSymlink()
                try? STPath(zipURL).deleteIncludingBrokenSymlink()
            }

            // Unzip
            try unzip(zipURL, to: tempDir.url)

            // Find skill root (the directory containing SKILL.md)
            guard let skillRoot = findSkillRoot(in: tempDir.url) else {
                throw SkillError.parsingFailed("No valid skill found in the downloaded package")
            }

            // Move to global storage
            try STPath(skillRoot).move(to: STPath(globalPath), isOverlay: true)

            // Write origin info
            try writeClawdhubOrigin(at: URL(fileURLWithPath: globalPath), slug: slug)
        }

        // Now load the skill from global storage
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? STFile(skillMdPath).read() else {
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
        
        Task {
            do {
                try await lockFileManager.addOrUpdateSkill(
                    slug: slug,
                    source: "clawdhub/\(slug)",
                    sourceType: "clawdhub",
                    sourceUrl: "https://clawdhub.com/skills/\(slug)",
                    skillPath: nil,
                    skillFolderHash: nil,
                    version: skill.version,
                    displayName: skill.name
                )
            } catch {
                Self.logger.error("Failed to record skill \(slug, privacy: .public) in lock file: \(error.localizedDescription, privacy: .public)")
            }
        }
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
    
    public func updateSkill(slug: String, to provider: Provider, zipURL: URL) throws {
        let updatedSkill = try updateSkillGlobal(slug: slug, zipURL: zipURL)
        try install(skill: updatedSkill, to: provider)
    }
    
    /// Update a skill in global storage (~/.nolon/skills/{slug}) from a downloaded zip.
    /// - Note: The caller owns `zipURL` cleanup.
    public func updateSkillGlobal(slug: String, zipURL: URL) throws -> Skill {
        let globalSkillsPath = nolonManager.skillsPath
        let globalPath = "\(globalSkillsPath)/\(slug)"
        
        try STPath(globalPath).deleteIncludingBrokenSymlink()
        
        STFolder(globalSkillsPath).createIfNotExists()
        
        let tempDir = try STFolder(sanbox: .temporary).folder(UUID().uuidString).create()
        
        defer {
            try? tempDir.deleteIncludingBrokenSymlink()
        }
        
        try unzip(zipURL, to: tempDir.url)
        
        guard let skillRoot = findSkillRoot(in: tempDir.url) else {
            throw SkillError.parsingFailed("No valid skill found in the downloaded package")
        }
        
        try STPath(skillRoot).move(to: STPath(globalPath), isOverlay: true)
        
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? STFile(skillMdPath).read() else {
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
        
        Task {
            do {
                try await lockFileManager.addOrUpdateSkill(
                    slug: slug,
                    source: "clawdhub/\(slug)",
                    sourceType: "clawdhub",
                    sourceUrl: "https://clawdhub.com/skills/\(slug)",
                    skillPath: nil,
                    skillFolderHash: nil,
                    version: skill.version,
                    displayName: skill.name
                )
            } catch {
                Self.logger.error("Failed to record skill \(slug, privacy: .public) in lock file: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        return skill
    }

    /// Install a skill from a local path (e.g. cloned GitHub repo)
    /// 2. Link/copy to provider directory based on provider settings
    public func installLocal(from sourcePath: String, slug: String, to provider: Provider) throws {
        let globalSkillsPath = nolonManager.skillsPath
        let globalPath = "\(globalSkillsPath)/\(slug)"
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let globalURL = URL(fileURLWithPath: globalPath).standardizedFileURL
        let lockSource = inferLockSourceInfo(sourceURL: sourceURL, slug: slug)

        // Ensure global skills directory exists
        STFolder(globalSkillsPath).createIfNotExists()

        // Register in global storage (copy to ~/.nolon/skills).
        // If it already exists (including broken symlinks), replace it.
        if sourceURL != globalURL {
            let globalPathRef = STPath(globalURL)
            try globalPathRef.deleteIncludingBrokenSymlink()
            try STPath(sourceURL).copy(to: STPath(globalURL), isOverlay: true)
        } else {
            // Source is already in global storage; nothing to copy
            let globalPathRef = STPath(globalURL)
            guard globalPathRef.isExists || globalPathRef.isSymbolicLink else {
                throw SkillError.fileOperationFailed("Global skill path missing at \(globalPath)")
            }
        }

        // Now load the skill from global storage
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? STFile(skillMdPath).read() else {
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
        
        Task {
            await recordInstalledSkillInLockFile(skill: skill, lockSource: lockSource)
        }
    }

    private struct LockSourceInfo: Sendable {
        let source: String
        let sourceType: String
        let sourceUrl: String
        let skillPath: String?
    }
    
    private func inferLockSourceInfo(sourceURL: URL, slug: String) -> LockSourceInfo {
        let sourcePath = sourceURL.standardizedFileURL.path
        
        // Prefer mapping to a known Git repository (so we can support update checking).
        for repo in settings.remoteRepositories where repo.templateType == .git {
            let clonePath = repo.localClonePath.standardizedFileURL.path
            guard sourcePath == clonePath || sourcePath.hasPrefix(clonePath + "/") else { continue }
            
            let sourceUrl = (repo.gitURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sourceUrl.isEmpty else { break }
            
            let skillPath: String?
            if sourcePath == clonePath {
                skillPath = nil
            } else if sourcePath.count > clonePath.count {
                var relative = String(sourcePath.dropFirst(clonePath.count))
                if relative.hasPrefix("/") { relative.removeFirst() }
                skillPath = relative.isEmpty ? nil : relative
            } else {
                skillPath = nil
            }

            let sourceType = RemoteRepository.detectProvider(from: sourceUrl)?.rawValue ?? repo.provider.rawValue
            let source = repo.provider.normalizeURL(sourceUrl)
            
            return LockSourceInfo(source: source, sourceType: sourceType, sourceUrl: sourceUrl, skillPath: skillPath)
        }
        
        // Fallback to local install source.
        return LockSourceInfo(
            source: "local/\(slug)",
            sourceType: "local",
            sourceUrl: sourceURL.absoluteString,
            skillPath: nil
        )
    }
    
    private func recordInstalledSkillInLockFile(skill: Skill, lockSource: LockSourceInfo) async {
        do {
            var skillFolderHash: String? = nil
            
            if lockSource.sourceType == "github" {
                let gitHubAPI = GitHubAPIService()
                if let ownerRepo = await gitHubAPI.extractOwnerRepo(from: lockSource.sourceUrl) {
                    skillFolderHash = try await gitHubAPI.fetchSkillFolderHash(
                        owner: ownerRepo.owner,
                        repo: ownerRepo.repo,
                        skillPath: lockSource.skillPath
                    )
                }
            }
            
            try await lockFileManager.addOrUpdateSkill(
                slug: skill.id,
                source: lockSource.source,
                sourceType: lockSource.sourceType,
                sourceUrl: lockSource.sourceUrl,
                skillPath: lockSource.skillPath,
                skillFolderHash: skillFolderHash,
                version: skill.version,
                displayName: skill.name
            )
        } catch {
            Self.logger.error("Failed to record skill \(skill.id, privacy: .public) in lock file: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func findSkillRoot(in rootURL: URL) -> URL? {
        let directSkill = rootURL.appendingPathComponent("SKILL.md")
        if STFile(directSkill).isExists {
            return rootURL
        }

        let rootFolder = STFolder(rootURL)
        guard let children = try? rootFolder.folders() else { return nil }

        let candidateDirs = children
            .filter { !$0.url.lastPathComponent.hasPrefix(".") }
            .compactMap { folder -> URL? in
                folder.fileIfExist(name: "SKILL.md") == nil ? nil : folder.url
            }

        if candidateDirs.count == 1 {
            return candidateDirs[0]
        }

        return nil
    }

    private func writeClawdhubOrigin(at skillRoot: URL, slug: String) throws {
        let originDir = skillRoot.appendingPathComponent(".clawdhub")
        STFolder(originDir).createIfNotExists()

        let originURL = originDir.appendingPathComponent("origin.json")
        let payload: [String: Any] = [
            "slug": slug,
            "source": "clawdhub",
            "installedAt": Int(Date().timeIntervalSince1970),
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try STFile(originURL).overlay(with: data)
    }

    /// Uninstall a skill from a provider
    public func uninstall(skill: Skill, from provider: Provider) throws {
        let providerPath = provider.defaultSkillsPath
        let targetPath = "\(providerPath)/\(skill.id)"

        try STPath(targetPath).deleteIncludingBrokenSymlink()
    }
    
    // MARK: - Workflow Installation
    
    /// Install a workflow for a skill (symlink to global workflow)
    public func installWorkflow(skill: Skill, to provider: Provider) throws {
        let providerWorkflowPath = provider.workflowPath
        let targetPath = "\(providerWorkflowPath)/\(skill.id).md"
        
        // Ensure provider workflow directory exists
        STFolder(providerWorkflowPath).createIfNotExists()
        
        // Ensure global workflow exists
        let globalWorkflowPath = try repository.createGlobalWorkflow(for: skill)
        
        // Remove existing link/file if present
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        // Create symlink
        try STPath(targetPath).createSymbolicLink(to: STPath(globalWorkflowPath))
    }
    
    /// Uninstall a workflow for a skill
    public func uninstallWorkflow(skill: Skill, from provider: Provider) throws {
        let providerWorkflowPath = provider.workflowPath
        let targetPath = "\(providerWorkflowPath)/\(skill.id).md"
        
        try STPath(targetPath).deleteIncludingBrokenSymlink()
    }
    
    /// Install a workflow for an MCP (symlink to mcps-workflows)
    public func installMcpWorkflow(mcp: MCP, to provider: Provider) throws {
        let providerWorkflowPath = provider.workflowPath
        let globalMcpWorkflowPath = "\(nolonManager.mcpsWorkflowsPath)/\(mcp.name).md"
        let targetPath = "\(providerWorkflowPath)/\(mcp.name).md"
        
        // 1. Ensure provider workflow directory exists
        STFolder(providerWorkflowPath).createIfNotExists()
        
        // 2. Ensure global MCP workflow exists in ~/.nolon/mcps-workflows
        STFolder(nolonManager.mcpsWorkflowsPath).createIfNotExists()
        if STPath(globalMcpWorkflowPath).isExists {
            // Repair legacy/invalid workflow format (missing required YAML frontmatter).
            if let content = try? STFile(globalMcpWorkflowPath).read() {
                let metadata = FrontmatterParser.parseMetadata(from: content)
                let isDescriptionMissing = (metadata["description"] ?? "").isEmpty
                let isAgentMissingForOpenCode = provider.templateId == "opencode"
                    && (metadata["agent"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if isDescriptionMissing || isAgentMissingForOpenCode {
                    try STFile(globalMcpWorkflowPath).overlay(with: mcp.workflowContent)
                }
            } else {
                try STFile(globalMcpWorkflowPath).overlay(with: mcp.workflowContent)
            }
        } else {
            try STFile(globalMcpWorkflowPath).overlay(with: mcp.workflowContent)
        }
        
        // 3. Remove existing link/file if present in provider directory
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        // 4. Create symlink from provider to global
        try STPath(targetPath).createSymbolicLink(to: STPath(globalMcpWorkflowPath))
    }
    
    /// Uninstall a workflow for an MCP
    public func uninstallMcpWorkflow(mcp: MCP, from provider: Provider) throws {
        let providerWorkflowPath = provider.workflowPath
        let targetPath = "\(providerWorkflowPath)/\(mcp.name).md"
        
        try STPath(targetPath).deleteIncludingBrokenSymlink()
    }

    // MARK: - Provider Scanning

    /// Scan a provider directory and return skill states
    public func scanProvider(provider: Provider) throws -> [ProviderSkillState] {
        var allStates: [ProviderSkillState] = []
        
        // 1. Scan default path (primary)
        let defaultPath = provider.defaultSkillsPath
        allStates.append(contentsOf: try scanDirectory(at: defaultPath, for: provider))
        
        // 2. Scan additional paths (penetration), excluding defaultSkillsPath to avoid duplicates
        if let additionals = provider.additionalSkillsPaths {
            for path in additionals where path != defaultPath {
                allStates.append(contentsOf: try scanDirectory(at: path, for: provider))
            }
        }

        return allStates
    }

    private func scanDirectory(at directoryPath: String, for provider: Provider) throws -> [ProviderSkillState] {
        guard STPath(directoryPath).isFolderExists else {
            return []
        }

        guard let contents = try? STFolder(directoryPath).subFilePaths() else {
            return []
        }

        var states: [ProviderSkillState] = []

        for item in contents {
            // Skip hidden files
            let name = item.url.lastPathComponent
            if name.hasPrefix(".") { continue }

            let itemPath = item.url.path
            let state = determineSkillState(skillName: name, at: itemPath, for: provider)

            states.append(
                ProviderSkillState(
                    skillName: name,
                    state: state,
                    path: itemPath,
                    basePath: directoryPath
                ))
        }

        return states
    }

    /// Determine the state of a skill at a given path based on provider's install method
    /// - Symlink mode: Skills symlinked from .nolon/skills are "installed", others are "orphaned"
    /// - Copy mode: Skills with same name in .nolon/skills are "installed", others are "orphaned"
    private func determineSkillState(skillName: String, at path: String, for provider: Provider)
        -> SkillInstallationState
    {
        let skillPath = STPath(path)
        guard skillPath.isExists || skillPath.isSymbolicLink else {
            return .broken
        }

        // Check if it's a symlink
        let isSymlink: Bool
        var symlinkDestination: String? = nil
        if skillPath.isSymbolicLink {
            isSymlink = true
            symlinkDestination = try? skillPath.destinationOfSymbolicLink().url.path

            // Check if symlink target exists
            guard let destination = symlinkDestination,
                STPath(destination).isExists
            else {
                return .broken
            }
        } else {
            isSymlink = false
        }

        switch provider.installMethod {
        case .symlink:
            // For symlink mode: symlinks FROM .nolon/skills are installed, others are orphaned
            if isSymlink, let dest = symlinkDestination {
                let globalSkillsPath = nolonManager.skillsPath
                // Check if symlink points to global skills
                if dest.hasPrefix(globalSkillsPath) {
                    return .installed
                }
            }
            return .orphaned

        case .copy:
            // For copy mode: compare with global storage by name
            if isSymlink {
                // Symlinks in copy mode are unexpected but treat as installed
                return .installed
            }

            // Check if skill exists in global storage
            let globalPath = "\(nolonManager.skillsPath)/\(skillName)"
            guard STPath(globalPath).isExists else {
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
        let providerModDate = STFile(providerSkillMd).attributes.modificationDate
        let globalModDate = STFile(globalSkillMd).attributes.modificationDate

        // If provider is newer by more than a second, consider different
        return providerModDate.timeIntervalSince(globalModDate) > 1.0
    }

    /// Parse version from SKILL.md content
    private func parseVersion(from content: String) -> String {
        return FrontmatterParser.parseMetadata(from: content)["version"] ?? "unknown"
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
        let providerPath = provider.defaultSkillsPath
        let sourcePath = "\(providerPath)/\(skillName)"

        // Verify it's a physical directory (not a symlink for symlink mode, or different for copy mode)
        let state = determineSkillState(skillName: skillName, at: sourcePath, for: provider)
        guard state == .orphaned else {
            throw SkillError.fileOperationFailed(
                "Skill '\(skillName)' is not an orphaned physical file")
        }

        let globalPath = "\(NolonManager.shared.skillsPath)/\(skillName)"

        let globalExists = STPath(globalPath).isExists

        if globalExists {
            // Check if identical to global
            if !skillsAreDifferent(providerPath: sourcePath, globalPath: globalPath) {
                // Scenario 1: Identical content - just delete provider copy and reinstall from global
                try STPath(sourcePath).deleteIncludingBrokenSymlink()
            } else {
                // Scenario 3: Different content - need user decision
                if overwriteExisting {
                    // Remove existing global skill and replace with provider version
                    try STPath(globalPath).deleteIncludingBrokenSymlink()
                    try STPath(sourcePath).move(to: STPath(globalPath), isOverlay: true)
                } else {
                    throw SkillError.conflictDetected(skillName: skillName, providers: [])
                }
            }
        } else {
            // Scenario 2: Not in global - move to global storage
            try STPath(sourcePath).move(to: STPath(globalPath), isOverlay: true)
        }

        // Install back to provider based on settings
        let method = provider.installMethod
        switch method {
        case .symlink:
            try STPath(sourcePath).createSymbolicLink(to: STPath(globalPath))
        case .copy:
            try STPath(globalPath).copy(to: STPath(sourcePath), isOverlay: true)
        }

        // Parse and return the skill
        let skillMdPath = "\(globalPath)/SKILL.md"
        guard let content = try? STFile(skillMdPath).read() else {
            throw SkillError.parsingFailed("SKILL.md not found in '\(skillName)'")
        }

        let skill = try SkillParser.parse(
            content: content,
            id: skillName,
            globalPath: globalPath
        )

        Task {
            let lockSource = LockSourceInfo(
                source: "local/\(skillName)",
                sourceType: "local",
                sourceUrl: URL(fileURLWithPath: globalPath).standardizedFileURL.absoluteString,
                skillPath: nil
            )
            await recordInstalledSkillInLockFile(skill: skill, lockSource: lockSource)
        }
        
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
                Self.logger.error("Failed to migrate '\(orphanedSkill.skillName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
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
        let providerPath = provider.defaultSkillsPath
        let targetPath = "\(providerPath)/\(skillName)"
        let globalPath = "\(nolonManager.skillsPath)/\(skillName)"

        // Remove broken symlink
        try STPath(targetPath).deleteIncludingBrokenSymlink()

        // Verify global skill exists
        guard STPath(globalPath).isExists else {
            throw SkillError.skillNotFound(id: skillName)
        }

        // Recreate based on provider's install method
        let method = provider.installMethod
        switch method {
        case .symlink:
            try STPath(targetPath).createSymbolicLink(to: STPath(globalPath))
        case .copy:
            try STPath(globalPath).copy(to: STPath(targetPath), isOverlay: true)
        }
    }

    // MARK: - Workflow Installation

    /// Install a remote workflow from a markdown file
    public func installRemoteWorkflow(fileURL: URL, slug: String, to provider: Provider) throws {
        let workflowPath = provider.workflowPath
        let targetPath = "\(workflowPath)/\(slug).md"
        
        // Ensure workflow directory exists
        STFolder(workflowPath).createIfNotExists()
        
        // If already exists, remove it first
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        // Copy workflow file
        try STPath(fileURL).copy(to: STPath(targetPath), isOverlay: true)

        if provider.templateId == "opencode" {
            try ensureOpenCodeCommandFrontmatter(at: targetPath, slug: slug)
        }
        
        // Write origin metadata
        try writeClawdhubWorkflowOrigin(at: URL(fileURLWithPath: workflowPath), slug: slug)
    }

    /// Install a workflow from a local markdown file without writing Clawdhub metadata
    public func installLocalWorkflow(fileURL: URL, slug: String, to provider: Provider) throws {
        let workflowPath = provider.workflowPath
        let targetPath = "\(workflowPath)/\(slug).md"

        // Ensure workflow directory exists
        STFolder(workflowPath).createIfNotExists()

        // If already exists, remove it first
        try STPath(targetPath).deleteIncludingBrokenSymlink()

        let isOpenCode = provider.templateId == "opencode"
        switch provider.installMethod {
        case .symlink where !isOpenCode:
            try STPath(targetPath).createSymbolicLink(to: STPath(fileURL))
        case .symlink, .copy:
            // For OpenCode, avoid symlinking the user's source file because we may need
            // to add required YAML frontmatter fields (e.g., `agent`) to the installed copy.
            try STPath(fileURL).copy(to: STPath(targetPath), isOverlay: true)
        }

        if isOpenCode {
            try ensureOpenCodeCommandFrontmatter(at: targetPath, slug: slug)
        }
    }

    private func ensureOpenCodeCommandFrontmatter(at path: String, slug: String) throws {
        guard let content = try? STFile(path).read() else { return }
        let metadata = FrontmatterParser.parseMetadata(from: content)
        let existingAgent = (metadata["agent"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !existingAgent.isEmpty { return }

        func yamlQuoted(_ value: String) -> String {
            var v = value
            v = v.replacingOccurrences(of: "\\", with: "\\\\")
            v = v.replacingOccurrences(of: "\"", with: "\\\"")
            v = v.replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(v)\""
        }

        let agentLine = "agent: \(yamlQuoted("default"))\n"

        // If frontmatter exists, inject (or repair) `agent` while preserving formatting.
        if content.hasPrefix("---") {
            let pattern = "^---\\s*\\r?\\n([\\s\\S]*?)\\r?\\n---"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
               ),
               let frontmatterRange = Range(match.range(at: 1), in: content),
               let fullRange = Range(match.range(at: 0), in: content) {
                let frontmatter = String(content[frontmatterRange])
                let hasAgentKey = frontmatter.range(
                    of: #"(?m)^\s*agent\s*:"#,
                    options: .regularExpression
                ) != nil

                var updatedFrontmatter = frontmatter
                if hasAgentKey {
                    updatedFrontmatter = frontmatter.replacingOccurrences(
                        of: #"(?m)^\s*agent\s*:\s*.*$"#,
                        with: agentLine.trimmingCharacters(in: .newlines),
                        options: .regularExpression
                    )
                } else {
                    updatedFrontmatter = agentLine + frontmatter
                }

                let updated = """
                ---
                \(updatedFrontmatter)
                ---
                """ + String(content[fullRange.upperBound...])

                try STFile(path).overlay(with: updated)
                return
            }
        }

        // No frontmatter: prepend a minimal one so OpenCode can load it and Nolon can discover it.
        let header = """
        ---
        name: \(yamlQuoted(slug))
        description: \(yamlQuoted("OpenCode command installed by Nolon."))
        \(agentLine)---
        
        """
        try STFile(path).overlay(with: header + content)
    }

    private func writeClawdhubWorkflowOrigin(at workflowDir: URL, slug: String) throws {
        let originFile = workflowDir.appendingPathComponent(".clawdhub_workflows")
        
        var origins: [String] = []
        if let existingData = try? Data(contentsOf: originFile),
           let existingOrigins = try? JSONDecoder().decode([String].self, from: existingData) {
            origins = existingOrigins
        }
        
        if !origins.contains(slug) {
            origins.append(slug)
            let data = try JSONEncoder().encode(origins)
            try data.write(to: originFile)
        }
    }

    // MARK: - MCP Installation

    /// Install a remote MCP from configuration
    @MainActor
    public func installRemoteMCP(_ remoteMCP: RemoteMCP, to provider: Provider) throws {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            throw SkillError.fileOperationFailed("Invalid provider template")
        }
        
        let configPath = template.defaultMcpConfigPath
        
        // Read existing config or create new
        var json: JSON
        if STFile(configPath).isExists,
           let data = try? Data(contentsOf: configPath),
           let fileJson = try? JSON(data: data) {
            json = fileJson
        } else {
            json = JSON([:])
        }
        
        // Ensure mcpServers object exists
        if json["mcpServers"].dictionary == nil {
            json["mcpServers"] = JSON([:])
        }
        
        // Add MCP configuration
        var servers = json["mcpServers"].dictionaryValue
        
        if let config = remoteMCP.configuration {
            var mcpConfig: [String: Any] = [:]
            
            if let command = config.command {
                mcpConfig["command"] = command
            }
            if let args = config.args {
                mcpConfig["args"] = args
            }
            if let env = config.env {
                mcpConfig["env"] = env
            }
            
            servers[remoteMCP.slug] = JSON(mcpConfig)
        }
        
        json["mcpServers"] = JSON(servers)
        
        // Write back
        if let str = json.rawString() {
            try str.write(to: configPath, atomically: true, encoding: .utf8)
        }
        
        // Write origin metadata
        try writeClawdhubMCPOrigin(for: provider, slug: remoteMCP.slug)
    }

    @MainActor
    private func writeClawdhubMCPOrigin(for provider: Provider, slug: String) throws {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            return
        }
        
        let configDir = template.defaultMcpConfigPath.deletingLastPathComponent()
        let originFile = configDir.appendingPathComponent(".clawdhub_mcp_origins")
        
        var origins: [String] = []
        if let existingData = try? Data(contentsOf: originFile),
           let existingOrigins = try? JSONDecoder().decode([String].self, from: existingData) {
            origins = existingOrigins
        }
        
        if !origins.contains(slug) {
            origins.append(slug)
            let data = try JSONEncoder().encode(origins)
            try data.write(to: originFile)
        }
    }

    // MARK: - Helpers

}
