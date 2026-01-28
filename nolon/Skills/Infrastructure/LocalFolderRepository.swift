import Foundation

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
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    public init(id: String, name: String, basePaths: [String], fileManager: FileManager = .default) {
        self.id = id
        self.name = name
        self.basePaths = basePaths
        self.fileManager = fileManager
    }
    
    public init(id: String, name: String, basePath: String, fileManager: FileManager = .default) {
        self.id = id
        self.name = name
        self.basePaths = [basePath]
        self.fileManager = fileManager
    }
    
    // MARK: - Skills
    
    public func fetchSkills(query: String? = nil, limit: Int = 100) async throws -> [RemoteSkill] {
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
        guard fileManager.fileExists(atPath: path) else {
            throw RepositoryError.resourceNotFound(path)
        }
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RepositoryError.fileOperationFailed("Not a directory: \(path)")
        }
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            throw RepositoryError.fileOperationFailed("Cannot read directory: \(path)")
        }
        
        var skills: [RemoteSkill] = []
        
        // Check for SKILL.md in the root path
        let rootSkillMdPath = (path as NSString).appendingPathComponent("SKILL.md")
        if fileManager.fileExists(atPath: rootSkillMdPath) {
            let rootSlug = (path as NSString).lastPathComponent
            if let skill = try? parseSkill(at: path, skillMdPath: rootSkillMdPath, slug: rootSlug) {
                // If the directory itself is a skill, do not scan subdirectories
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
        
        return skills
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
    
    public func downloadSkill(slug: String) async throws -> URL {
        // For local folders, "download" means returning the existing path
        for path in basePaths {
            let skillPath = (path as NSString).appendingPathComponent(slug)
            let skillMdPath = (skillPath as NSString).appendingPathComponent("SKILL.md")
            
            if fileManager.fileExists(atPath: skillMdPath) {
                return URL(fileURLWithPath: skillPath)
            }
        }
        
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - Workflows
    
    public func fetchWorkflows(query: String? = nil, limit: Int = 100) async throws -> [RemoteWorkflow] {
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
        guard fileManager.fileExists(atPath: path) else {
            throw RepositoryError.resourceNotFound(path)
        }
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RepositoryError.fileOperationFailed("Not a directory: \(path)")
        }
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            throw RepositoryError.fileOperationFailed("Cannot read directory: \(path)")
        }
        
        var workflows: [RemoteWorkflow] = []
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            
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
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let slug = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "unknown"
        
        // Extract display name from first line or filename
        let lines = content.components(separatedBy: .newlines)
        let displayName = lines.first?.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) ?? slug
        
        // Get first paragraph as summary
        let summary = lines.dropFirst().first(where: { !$0.isEmpty })
        
        // Get file modification date
        let attributes = try? fileManager.attributesOfItem(atPath: path)
        let modificationDate = attributes?[.modificationDate] as? Date
        
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
        // For local folders, "download" means returning the existing path
        for path in basePaths {
            let workflowPath = (path as NSString).appendingPathComponent("\(slug).md")
            
            if fileManager.fileExists(atPath: workflowPath) {
                return URL(fileURLWithPath: workflowPath)
            }
        }
        
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - MCPs
    
    public func fetchMCPs(query: String? = nil, limit: Int = 100) async throws -> [RemoteMCP] {
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
        guard fileManager.fileExists(atPath: path) else {
            throw RepositoryError.resourceNotFound(path)
        }
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RepositoryError.fileOperationFailed("Not a directory: \(path)")
        }
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            throw RepositoryError.fileOperationFailed("Cannot read directory: \(path)")
        }
        
        var mcps: [RemoteMCP] = []
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            
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
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let config = try decoder.decode(RemoteMCP.MCPConfiguration.self, from: data)
        let slug = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "unknown"
        
        // Get file modification date
        let attributes = try? fileManager.attributesOfItem(atPath: path)
        let modificationDate = attributes?[.modificationDate] as? Date
        
        return RemoteMCP(
            slug: slug,
            displayName: slug,
            summary: config.command,
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
        // For local folders, "download" means returning the existing path
        for path in basePaths {
            let mcpPath = (path as NSString).appendingPathComponent("\(slug).json")
            
            if fileManager.fileExists(atPath: mcpPath) {
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
