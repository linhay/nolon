import Foundation
import STFilePath

/// Global cache repository for managing downloaded resources
/// Manages ~/.nolon/skills, ~/.nolon/workflows, ~/.nolon/mcps
/// Also serves as a RemoteResourceRepository to expose cached resources
public actor GlobalCacheRepository: RemoteResourceRepository {
    
    // MARK: - RemoteResourceRepository Protocol
    
    nonisolated public let id: String = "global-cache"
    nonisolated public let name: String = "Local Cache"
    nonisolated public let supportedTypes: Set<RemoteContentType> = [.skill, .workflow, .mcp]
    nonisolated public var lastSyncDate: Date? { nil }
    
    // MARK: - Private Properties
    
    private let nolonManager: NolonManager
    
    public init(
        nolonManager: NolonManager = .shared
    ) {
        self.nolonManager = nolonManager
    }
    
    // MARK: - Cache Management
    
    /// Save downloaded resource to global cache
    /// - Parameters:
    ///   - downloadURL: URL of downloaded file/directory
    ///   - slug: Resource identifier
    ///   - type: Resource type
    /// - Returns: Cached resource path
    public func cacheResource(
        from downloadURL: URL,
        slug: String,
        type: RemoteContentType
    ) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        let targetPath = cacheResourcePath(for: slug, type: type)
        
        // Remove existing if present
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        if let legacyPath = legacyCacheResourcePath(for: slug, type: type),
           STPath(legacyPath).isExists || STPath(legacyPath).isSymbolicLink {
            try STPath(legacyPath).deleteIncludingBrokenSymlink()
        }
        
        switch type {
        case .skill:
            // Skills are zip files that need extraction
            try await extractSkill(from: downloadURL, to: targetPath)
            
        case .workflow:
            // Workflows are markdown files
            try STPath(downloadURL).copy(to: STPath(targetPath), isOverlay: true)
            
        case .mcp:
            // MCPs are JSON configuration files
            try STPath(downloadURL).copy(to: STPath(targetPath), isOverlay: true)
        }
        
        return targetPath
    }
    
    /// Check if resource exists in cache
    public func isCached(slug: String, type: RemoteContentType) -> Bool {
        let resourcePath = cacheResourcePath(for: slug, type: type)
        if STPath(resourcePath).isExists {
            return true
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: type) {
            return STPath(legacyPath).isExists
        }
        return false
    }
    
    /// Remove resource from cache
    public func removeFromCache(slug: String, type: RemoteContentType) throws {
        let resourcePath = cacheResourcePath(for: slug, type: type)
        
        try STPath(resourcePath).deleteIncludingBrokenSymlink()
        
        if let legacyPath = legacyCacheResourcePath(for: slug, type: type),
           STPath(legacyPath).isExists || STPath(legacyPath).isSymbolicLink {
            try STPath(legacyPath).deleteIncludingBrokenSymlink()
        }
    }
    
    /// List all cached resources of a type
    public func listCachedResources(type: RemoteContentType) async throws -> [String] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        let cachePath = getCachePath(for: type)
        
        guard let contents = try? STFolder(cachePath).subFilePaths().map({ $0.url.lastPathComponent }) else {
            return []
        }
        
        return contents.compactMap { item in
            guard !item.hasPrefix(".") else { return nil }
            
            switch type {
            case .skill:
                return item
            case .workflow:
                if item.hasSuffix(".md") {
                    return (item as NSString).deletingPathExtension
                }
                return (item as NSString).pathExtension.isEmpty ? item : nil
            case .mcp:
                if item.hasSuffix(".json") {
                    return (item as NSString).deletingPathExtension
                }
                return (item as NSString).pathExtension.isEmpty ? item : nil
            }
        }
    }
    
    // MARK: - RemoteResourceRepository Implementation
    
    /// Fetch skills from cache
    public func fetchSkills(query: String? = nil, limit: Int = 100) async throws -> [RemoteSkill] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        let skills = try await listCachedSkills()
        
        var results = skills.map { skill -> RemoteSkill in
            RemoteSkill(
                slug: skill.id,
                displayName: skill.name,
                summary: skill.description,
                latestVersion: skill.version,
                updatedAt: nil,
                downloads: nil,
                stars: nil,
                localPath: skill.globalPath
            )
        }
        
        // Filter by query if provided
        if let query = query?.lowercased(), !query.isEmpty {
            results = results.filter {
                $0.displayName.lowercased().contains(query) ||
                ($0.summary?.lowercased().contains(query) ?? false)
            }
        }
        
        return Array(results.prefix(limit))
    }
    
    /// Fetch workflows from cache
    public func fetchWorkflows(query: String? = nil, limit: Int = 100) async throws -> [RemoteWorkflow] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        var results = try await listCachedWorkflows()
        
        // Filter by query if provided
        if let query = query?.lowercased(), !query.isEmpty {
            results = results.filter {
                $0.displayName.lowercased().contains(query) ||
                ($0.summary?.lowercased().contains(query) ?? false)
            }
        }
        
        return Array(results.prefix(limit))
    }
    
    /// Fetch MCPs from cache
    public func fetchMCPs(query: String? = nil, limit: Int = 100) async throws -> [RemoteMCP] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        var results = try await listCachedMCPs()
        
        // Filter by query if provided
        if let query = query?.lowercased(), !query.isEmpty {
            results = results.filter {
                $0.displayName.lowercased().contains(query) ||
                ($0.summary?.lowercased().contains(query) ?? false)
            }
        }
        
        return Array(results.prefix(limit))
    }
    
    /// Download skill - returns existing cached path
    public func downloadSkill(slug: String) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        let skillPath = nolonManager.skillsURL.appendingPathComponent(slug)
        guard STPath(skillPath).isExists else {
            throw RepositoryError.resourceNotFound(slug)
        }
        return skillPath
    }
    
    /// Download workflow - returns existing cached path
    public func downloadWorkflow(slug: String) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        let workflowPath = cacheResourcePath(for: slug, type: .workflow)
        if STPath(workflowPath).isExists {
            return workflowPath
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: .workflow),
           STPath(legacyPath).isExists {
            return legacyPath
        }
        throw RepositoryError.resourceNotFound(slug)
    }
    
    /// Download MCP - returns existing cached path
    public func downloadMCP(slug: String) async throws -> URL {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        let mcpPath = cacheResourcePath(for: slug, type: .mcp)
        if STPath(mcpPath).isExists {
            return mcpPath
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: .mcp),
           STPath(legacyPath).isExists {
            return legacyPath
        }
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - Skills
    
    /// List all skills in global cache
    public func listCachedSkills() async throws -> [Skill] {
        await RemoteRepositoryWatchCenter.shared.ensureWatchingGlobalCache()
        var skills: [Skill] = []
        
        guard let folders = try? STFolder(nolonManager.skillsPath).folders() else {
            return []
        }
        
        for folder in folders {
            let item = folder.url.lastPathComponent
            if item.hasPrefix(".") { continue }
            
            let skillPath = folder.url.path
            
            let skillMdPath = "\(skillPath)/SKILL.md"
            guard let content = try? STFile(skillMdPath).read() else {
                continue
            }
            
            let referenceCount = countFiles(in: "\(skillPath)/references")
            let scriptCount = countFiles(in: "\(skillPath)/scripts")
            
            guard let parsedSkill = try? SkillParser.parse(
                content: content,
                id: item,
                globalPath: skillPath
            ) else {
                continue
            }
            
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
    
    /// Get skill detail from cache
    public func getCachedSkill(slug: String) async throws -> Skill {
        let skillPath = "\(nolonManager.skillsPath)/\(slug)"
        let skillMdPath = "\(skillPath)/SKILL.md"
        
        guard STFile(skillMdPath).isExists else {
            throw RepositoryError.resourceNotFound(slug)
        }
        
        let content = try STFile(skillMdPath).read()
        let referenceCount = countFiles(in: "\(skillPath)/references")
        let scriptCount = countFiles(in: "\(skillPath)/scripts")
        
        let parsedSkill = try SkillParser.parse(
            content: content,
            id: slug,
            globalPath: skillPath
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
    
    // MARK: - Workflows
    
    // Workflows are independent resources, not linked to Skills
    
    /// List all workflows in global cache
    public func listCachedWorkflows() async throws -> [RemoteWorkflow] {
        var workflows: [RemoteWorkflow] = []
        var seenSlugs = Set<String>()
        
        guard let contents = try? STFolder(nolonManager.userWorkflowsPath).subFilePaths() else {
            return []
        }
        
        for item in contents {
            let name = item.url.lastPathComponent
            if name.hasPrefix(".") { continue }
            guard !item.isFolderExists else { continue }
            
            let pathExtension = (name as NSString).pathExtension
            var workflowPath = item.url.path
            let slug: String
            
            if pathExtension == "md" {
                slug = (name as NSString).deletingPathExtension
            } else if pathExtension.isEmpty {
                // Migrate legacy cache files without extensions
                slug = name
                let migratedPath = "\(nolonManager.userWorkflowsPath)/\(slug).md"
                if STPath(migratedPath).isExists {
                    continue
                }
                try? STPath(workflowPath).move(to: STPath(migratedPath), isOverlay: false)
                workflowPath = migratedPath
            } else {
                continue
            }
            
            guard !seenSlugs.contains(slug) else { continue }
            seenSlugs.insert(slug)
            
            let modifiedDate: Date? = STFile(workflowPath).isExists ? STFile(workflowPath).attributes.modificationDate : nil
            
            // Workflows require YAML frontmatter (see SkillParser); prefer that for name/description.
            let content = try? STFile(workflowPath).read()
            let metadata = content.map { FrontmatterParser.parseMetadata(from: $0) } ?? [:]
            guard let displayName = metadata["name"], !displayName.isEmpty,
                  let summary = metadata["description"], !summary.isEmpty
            else {
                continue
            }
            
            let workflow = RemoteWorkflow(
                slug: slug,
                displayName: displayName,
                summary: summary,
                latestVersion: nil,
                updatedAt: modifiedDate,
                downloads: nil,
                stars: nil,
                localPath: workflowPath
            )
            
            workflows.append(workflow)
        }
        
        return workflows
    }
    
    // MARK: - MCPs
    
    /// List all MCPs in global cache
    public func listCachedMCPs() async throws -> [RemoteMCP] {
        var mcps: [RemoteMCP] = []
        var seenSlugs = Set<String>()
        
        guard let contents = try? STFolder(nolonManager.mcpsPath).subFilePaths() else {
            return []
        }
        
        for item in contents {
            let name = item.url.lastPathComponent
            if name.hasPrefix(".") { continue }
            guard !item.isFolderExists else { continue }
            
            let pathExtension = (name as NSString).pathExtension
            var mcpPath = item.url.path
            let slug: String
            
            if pathExtension == "json" {
                slug = (name as NSString).deletingPathExtension
            } else if pathExtension.isEmpty {
                // Migrate legacy cache files without extensions
                slug = name
                let migratedPath = "\(nolonManager.mcpsPath)/\(slug).json"
                if STPath(migratedPath).isExists {
                    continue
                }
                try? STPath(mcpPath).move(to: STPath(migratedPath), isOverlay: false)
                mcpPath = migratedPath
            } else {
                continue
            }
            
            guard !seenSlugs.contains(slug) else { continue }
            seenSlugs.insert(slug)
            
            let modifiedDate: Date? = STFile(mcpPath).isExists ? STFile(mcpPath).attributes.modificationDate : nil
            
            // Try to parse MCP configuration
            var configuration: RemoteMCP.MCPConfiguration?
            var displayName = slug
            var summary: String?
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: mcpPath)) {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                configuration = try? decoder.decode(RemoteMCP.MCPConfiguration.self, from: data)
                
                // Try to get metadata from JSON
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    displayName = json["name"] as? String ?? slug
                    summary = json["description"] as? String
                }
            }
            
            let mcp = RemoteMCP(
                slug: slug,
                displayName: displayName,
                summary: summary,
                latestVersion: nil,
                updatedAt: modifiedDate,
                downloads: nil,
                stars: nil,
                installs: nil,
                configuration: configuration,
                localPath: mcpPath
            )
            
            mcps.append(mcp)
        }
        
        return mcps
    }
    
    // MARK: - Private Helpers
    
    private func getCachePath(for type: RemoteContentType) -> URL {
        switch type {
        case .skill:
            return nolonManager.skillsURL
        case .workflow:
            return nolonManager.userWorkflowsURL
        case .mcp:
            return nolonManager.mcpsURL
        }
    }

    private func cacheResourcePath(for slug: String, type: RemoteContentType) -> URL {
        let cachePath = getCachePath(for: type)
        switch type {
        case .skill:
            return cachePath.appendingPathComponent(slug)
        case .workflow:
            return cachePath.appendingPathComponent("\(slug).md")
        case .mcp:
            return cachePath.appendingPathComponent("\(slug).json")
        }
    }

    private func legacyCacheResourcePath(for slug: String, type: RemoteContentType) -> URL? {
        switch type {
        case .skill:
            return nil
        case .workflow, .mcp:
            return getCachePath(for: type).appendingPathComponent(slug)
        }
    }
    
    private func extractSkill(from zipURL: URL, to destination: URL) async throws {
        // Create temporary directory
        let tempDir = try STFolder(sanbox: .temporary).folder(UUID().uuidString).create()
        
        defer {
            try? tempDir.deleteIncludingBrokenSymlink()
        }
        
        // Extract using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, tempDir.url.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw RepositoryError.extractionFailed
        }
        
        // Find skill root (directory containing SKILL.md)
        guard let skillRoot = findSkillRoot(in: tempDir.url) else {
            throw RepositoryError.invalidPackage
        }
        
        // Move to destination
        try STPath(skillRoot).move(to: STPath(destination), isOverlay: true)
    }
    
    private func findSkillRoot(in directory: URL) -> URL? {
        // Check if SKILL.md is in root
        let directSkill = directory.appendingPathComponent("SKILL.md")
        if STFile(directSkill).isExists {
            return directory
        }
        
        // Search in subdirectories
        guard let folders = try? STFolder(directory).folders() else { return nil }
        let candidateDirs = folders.compactMap { folder -> URL? in
            folder.fileIfExist(name: "SKILL.md") == nil ? nil : folder.url
        }
        
        return candidateDirs.count == 1 ? candidateDirs[0] : nil
    }
    
    private func countFiles(in directory: String) -> Int {
        guard let contents = try? STFolder(directory).subFilePaths() else {
            return 0
        }
        return contents.filter { !$0.url.lastPathComponent.hasPrefix(".") }.count
    }
}
