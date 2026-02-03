import Foundation
import STFilePath

/// Local folder repository implementation
/// Scans local directories for skills, workflows, and MCPs
/// Replaces LocalFolderService.swift
public struct LocalFolderRepository: RemoteResourceRepository {
    
    // MARK: - RemoteResourceRepository Protocol
    
    public let id: String
    public let name: String
    public let supportedTypes: Set<RemoteContentType> = [.skill, .workflow, .mcp]
    public var lastSyncDate: Date? { nil }
    
    // MARK: - Private Properties
    
    private let basePaths: [String]
    
    // MARK: - Initialization
    
    public init(id: String, name: String, basePaths: [String]) {
        self.id = id
        self.name = name
        self.basePaths = basePaths
    }
    
    public init(id: String, name: String, basePath: String) {
        self.id = id
        self.name = name
        self.basePaths = [basePath]
    }
    
    // MARK: - Skills
    
    public func fetchSkills(query: String? = nil, limit: Int = 100) async throws -> [RemoteSkill] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingLocalFolder(repoId: id, basePaths: basePaths)
        var allSkills: [RemoteSkill] = []
        
        for path in basePaths {
            do {
                let skills = try await scanSkills(from: path)
                allSkills.append(contentsOf: skills)
            } catch {
                continue
            }
        }
        
        // Remove duplicates
        var seenSlugs = Set<String>()
        var uniqueSkills = allSkills.filter { skill in
            if seenSlugs.contains(skill.slug) {
                return false
            }
            seenSlugs.insert(skill.slug)
            return true
        }
        
        // Filter by query
        if let query = query, !query.isEmpty {
            let lower = query.lowercased()
            uniqueSkills = uniqueSkills.filter { skill in
                skill.displayName.lowercased().contains(lower) ||
                (skill.summary?.lowercased().contains(lower) ?? false)
            }
        }
        
        // Sort and limit
        uniqueSkills.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return Array(uniqueSkills.prefix(limit))
    }
    
    /// Scans a directory for skill folders (directories containing SKILL.md)
    private func scanSkills(from path: String) async throws -> [RemoteSkill] {
        guard STPath(path).isExists else {
            throw RepositoryError.resourceNotFound(path)
        }
        
        guard STPath(path).isFolderExists else {
            throw RepositoryError.fileOperationFailed("Not a directory: \(path)")
        }
        
        let rootFolder = STFolder(path)
        guard let folders = try? rootFolder.folders() else {
            throw RepositoryError.fileOperationFailed("Cannot read directory: \(path)")
        }
        
        var skills: [RemoteSkill] = []
        
        // Check for SKILL.md in the root path
        let rootSkillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        if STFile(rootSkillMdPath).isExists {
            let rootSlug = (path as NSString).lastPathComponent
            if let skill = try? parseSkill(at: path, skillMdPath: rootSkillMdPath, slug: rootSlug) {
                // If the directory itself is a skill, do not scan subdirectories
                return [skill]
            }
        }
        
        for folder in folders {
            let item = folder.url.lastPathComponent
            let itemPath = folder.url.path
            
            // Check if this directory contains SKILL.md
            let skillMdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
            guard STFile(skillMdPath).isExists else {
                continue
            }
            
            // Parse SKILL.md to get skill info
            if let skill = try? parseSkill(at: itemPath, skillMdPath: skillMdPath, slug: item) {
                skills.append(skill)
            }
        }
        
        return skills
    }
    
    /// Parses a skill from its SKILL.md file
    private func parseSkill(at path: String, skillMdPath: String, slug: String) throws -> RemoteSkill {
        let content = try STFile(skillMdPath).read()
        let parsed = try SkillParser.parse(content: content, id: slug, globalPath: path)
        
        // Get file modification date
        let modificationDate: Date? = STFile(skillMdPath).isExists ? STFile(skillMdPath).attributes.modificationDate : nil
        
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
    
    public func downloadSkill(slug: String) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingLocalFolder(repoId: id, basePaths: basePaths)
        // For local folders, "download" means returning the existing path
        for path in basePaths {
            let skillPath = (path as NSString).appendingPathComponent(slug)
            let skillMdPath = (skillPath as NSString).appendingPathComponent("SKILL.md")
            
            if STFile(skillMdPath).isExists {
                return URL(fileURLWithPath: skillPath)
            }
        }
        
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - Workflows
    
    public func fetchWorkflows(query: String? = nil, limit: Int = 100) async throws -> [RemoteWorkflow] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingLocalFolder(repoId: id, basePaths: basePaths)
        var allWorkflows: [RemoteWorkflow] = []
        
        for path in basePaths {
            do {
                let workflows = try await scanWorkflows(from: path)
                allWorkflows.append(contentsOf: workflows)
            } catch {
                continue
            }
        }
        
        // Remove duplicates
        var seenSlugs = Set<String>()
        var uniqueWorkflows = allWorkflows.filter { workflow in
            if seenSlugs.contains(workflow.slug) {
                return false
            }
            seenSlugs.insert(workflow.slug)
            return true
        }
        
        // Filter by query
        if let query = query, !query.isEmpty {
            let lower = query.lowercased()
            uniqueWorkflows = uniqueWorkflows.filter { workflow in
                workflow.displayName.lowercased().contains(lower) ||
                (workflow.summary?.lowercased().contains(lower) ?? false)
            }
        }
        
        // Sort and limit
        uniqueWorkflows.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return Array(uniqueWorkflows.prefix(limit))
    }
    
    /// Scans a directory for workflow markdown files
    private func scanWorkflows(from path: String) async throws -> [RemoteWorkflow] {
        guard STPath(path).isExists else {
            throw RepositoryError.resourceNotFound(path)
        }
        
        guard STPath(path).isFolderExists else {
            throw RepositoryError.fileOperationFailed("Not a directory: \(path)")
        }
        
        guard let files = try? STFolder(path).files() else {
            throw RepositoryError.fileOperationFailed("Cannot read directory: \(path)")
        }
        
        var workflows: [RemoteWorkflow] = []
        
        for file in files {
            let itemPath = file.url.path
            let item = file.url.lastPathComponent
            
            // Check if this is a markdown file
            guard item.hasSuffix(".md") else {
                continue
            }
            
            if let workflow = try? parseWorkflow(at: itemPath) {
                workflows.append(workflow)
            }
        }
        
        return workflows
    }
    
    /// Parses a workflow from markdown file
    private func parseWorkflow(at path: String) throws -> RemoteWorkflow {
        let content = try STFile(path).read()
        let slug = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "unknown"

        // Workflows require YAML frontmatter (see SkillParser); prefer that for name/description.
        let metadata = FrontmatterParser.parseMetadata(from: content)
        guard let displayName = metadata["name"], !displayName.isEmpty,
              let summary = metadata["description"], !summary.isEmpty
        else {
            throw RepositoryError.parsingFailed("Invalid workflow: missing frontmatter name/description")
        }
        
        // Get file modification date
        let modificationDate: Date? = STFile(path).isExists ? STFile(path).attributes.modificationDate : nil
        
        return RemoteWorkflow(
            slug: slug,
            displayName: displayName,
            summary: summary,
            latestVersion: nil,
            updatedAt: modificationDate,
            downloads: nil,
            stars: nil,
            usages: nil,
            localPath: path
        )
    }
    
    public func downloadWorkflow(slug: String) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingLocalFolder(repoId: id, basePaths: basePaths)
        // For local folders, "download" means returning the existing path
        for path in basePaths {
            let workflowPath = (path as NSString).appendingPathComponent("\(slug).md")
            
            if STFile(workflowPath).isExists {
                return URL(fileURLWithPath: workflowPath)
            }
        }
        
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - MCPs
    
    public func fetchMCPs(query: String? = nil, limit: Int = 100) async throws -> [RemoteMCP] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingLocalFolder(repoId: id, basePaths: basePaths)
        var allMCPs: [RemoteMCP] = []
        
        for path in basePaths {
            do {
                let mcps = try await scanMCPs(from: path)
                allMCPs.append(contentsOf: mcps)
            } catch {
                continue
            }
        }
        
        // Remove duplicates
        var seenSlugs = Set<String>()
        var uniqueMCPs = allMCPs.filter { mcp in
            if seenSlugs.contains(mcp.slug) {
                return false
            }
            seenSlugs.insert(mcp.slug)
            return true
        }
        
        // Filter by query
        if let query = query, !query.isEmpty {
            let lower = query.lowercased()
            uniqueMCPs = uniqueMCPs.filter { mcp in
                mcp.displayName.lowercased().contains(lower) ||
                (mcp.summary?.lowercased().contains(lower) ?? false)
            }
        }
        
        // Sort and limit
        uniqueMCPs.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return Array(uniqueMCPs.prefix(limit))
    }
    
    /// Scans a directory for MCP configuration files
    private func scanMCPs(from path: String) async throws -> [RemoteMCP] {
        guard STPath(path).isExists else {
            throw RepositoryError.resourceNotFound(path)
        }
        
        guard STPath(path).isFolderExists else {
            throw RepositoryError.fileOperationFailed("Not a directory: \(path)")
        }
        
        guard let files = try? STFolder(path).files() else {
            throw RepositoryError.fileOperationFailed("Cannot read directory: \(path)")
        }
        
        var mcps: [RemoteMCP] = []
        
        for file in files {
            let itemPath = file.url.path
            let item = file.url.lastPathComponent
            
            // Check if this is a JSON file
            guard item.hasSuffix(".json") else {
                continue
            }
            
            if let mcp = try? parseMCP(at: itemPath) {
                mcps.append(mcp)
            }
        }
        
        return mcps
    }
    
    /// Parses an MCP from JSON file
    private func parseMCP(at path: String) throws -> RemoteMCP {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let slug = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "unknown"

        let metadata = MCPJsonFile.metadata(from: data)
        let server = (try? MCPJsonFile.serverConfig(from: data, slug: slug)) ?? [:]
        let fields = MCPJsonFile.serverFields(from: server)
        let config = RemoteMCP.MCPConfiguration(command: fields.command, args: fields.args, env: fields.env)
        
        // Get file modification date
        let modificationDate: Date? = STFile(path).isExists ? STFile(path).attributes.modificationDate : nil
        
        return RemoteMCP(
            slug: slug,
            displayName: metadata.name ?? slug,
            summary: metadata.description ?? config.command,
            latestVersion: nil,
            updatedAt: modificationDate,
            downloads: nil,
            stars: nil,
            installs: nil,
            configuration: config,
            localPath: path
        )
    }
    
    public func downloadMCP(slug: String) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingLocalFolder(repoId: id, basePaths: basePaths)
        // For local folders, "download" means returning the existing path
        for path in basePaths {
            let mcpPath = (path as NSString).appendingPathComponent("\(slug).json")
            
            if STFile(mcpPath).isExists {
                return URL(fileURLWithPath: mcpPath)
            }
        }
        
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - Sync
    
    public func sync() async throws -> Bool {
        // Local folders don't need sync
        return true
    }
}
