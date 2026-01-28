import Foundation

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
    private let fileManager: FileManager
    
    public init(
        nolonManager: NolonManager = .shared,
        fileManager: FileManager = .default
    ) {
        self.nolonManager = nolonManager
        self.fileManager = fileManager
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
        let targetPath = cacheResourcePath(for: slug, type: type)
        
        // Remove existing if present
        if fileManager.fileExists(atPath: targetPath.path) {
            try fileManager.removeItem(at: targetPath)
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: type),
           fileManager.fileExists(atPath: legacyPath.path) {
            try fileManager.removeItem(at: legacyPath)
        }
        
        switch type {
        case .skill:
            // Skills are zip files that need extraction
            try await extractSkill(from: downloadURL, to: targetPath)
            
        case .workflow:
            // Workflows are markdown files
            try fileManager.copyItem(at: downloadURL, to: targetPath)
            
        case .mcp:
            // MCPs are JSON configuration files
            try fileManager.copyItem(at: downloadURL, to: targetPath)
        }
        
        return targetPath
    }
    
    /// Check if resource exists in cache
    public func isCached(slug: String, type: RemoteContentType) -> Bool {
        let resourcePath = cacheResourcePath(for: slug, type: type)
        if fileManager.fileExists(atPath: resourcePath.path) {
            return true
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: type) {
            return fileManager.fileExists(atPath: legacyPath.path)
        }
        return false
    }
    
    /// Remove resource from cache
    public func removeFromCache(slug: String, type: RemoteContentType) throws {
        let resourcePath = cacheResourcePath(for: slug, type: type)
        
        if fileManager.fileExists(atPath: resourcePath.path) {
            try fileManager.removeItem(at: resourcePath)
        }
        
        if let legacyPath = legacyCacheResourcePath(for: slug, type: type),
           fileManager.fileExists(atPath: legacyPath.path) {
            try fileManager.removeItem(at: legacyPath)
        }
    }
    
    /// List all cached resources of a type
    public func listCachedResources(type: RemoteContentType) async throws -> [String] {
        let cachePath = getCachePath(for: type)
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: cachePath.path) else {
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
        let skillPath = nolonManager.skillsURL.appendingPathComponent(slug)
        guard fileManager.fileExists(atPath: skillPath.path) else {
            throw RepositoryError.resourceNotFound(slug)
        }
        return skillPath
    }
    
    /// Download workflow - returns existing cached path
    public func downloadWorkflow(slug: String) async throws -> URL {
        let workflowPath = cacheResourcePath(for: slug, type: .workflow)
        if fileManager.fileExists(atPath: workflowPath.path) {
            return workflowPath
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: .workflow),
           fileManager.fileExists(atPath: legacyPath.path) {
            return legacyPath
        }
        throw RepositoryError.resourceNotFound(slug)
    }
    
    /// Download MCP - returns existing cached path
    public func downloadMCP(slug: String) async throws -> URL {
        let mcpPath = cacheResourcePath(for: slug, type: .mcp)
        if fileManager.fileExists(atPath: mcpPath.path) {
            return mcpPath
        }
        if let legacyPath = legacyCacheResourcePath(for: slug, type: .mcp),
           fileManager.fileExists(atPath: legacyPath.path) {
            return legacyPath
        }
        throw RepositoryError.resourceNotFound(slug)
    }
    
    // MARK: - Skills
    
    /// List all skills in global cache
    public func listCachedSkills() async throws -> [Skill] {
        var skills: [Skill] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: nolonManager.skillsPath) else {
            return []
        }
        
        for item in contents {
            if item.hasPrefix(".") { continue }
            
            let skillPath = "\(nolonManager.skillsPath)/\(item)"
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: skillPath, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                continue
            }
            
            let skillMdPath = "\(skillPath)/SKILL.md"
            guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8) else {
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
        
        guard fileManager.fileExists(atPath: skillMdPath) else {
            throw RepositoryError.resourceNotFound(slug)
        }
        
        let content = try String(contentsOfFile: skillMdPath, encoding: .utf8)
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
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: nolonManager.userWorkflowsPath) else {
            return []
        }
        
        for item in contents {
            if item.hasPrefix(".") { continue }
            
            let itemPath = "\(nolonManager.userWorkflowsPath)/\(item)"
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                continue
            }
            
            let pathExtension = (item as NSString).pathExtension
            var workflowPath = itemPath
            let slug: String
            
            if pathExtension == "md" {
                slug = (item as NSString).deletingPathExtension
            } else if pathExtension.isEmpty {
                // Migrate legacy cache files without extensions
                slug = item
                let migratedPath = "\(nolonManager.userWorkflowsPath)/\(slug).md"
                if fileManager.fileExists(atPath: migratedPath) {
                    continue
                }
                try? fileManager.moveItem(atPath: workflowPath, toPath: migratedPath)
                workflowPath = migratedPath
            } else {
                continue
            }
            
            guard !seenSlugs.contains(slug) else { continue }
            seenSlugs.insert(slug)
            
            let attributes = try? fileManager.attributesOfItem(atPath: workflowPath)
            let modifiedDate = attributes?[.modificationDate] as? Date
            
            // Read first few lines for display name and summary
            let content = try? String(contentsOfFile: workflowPath, encoding: .utf8)
            let lines = content?.components(separatedBy: .newlines) ?? []
            
            var displayName = slug
            var summary: String?
            
            // Try to extract title from first # heading
            for line in lines.prefix(10) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    displayName = String(trimmed.dropFirst(2))
                    break
                }
            }
            
            // Try to find first paragraph as summary
            for line in lines.prefix(20) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    summary = trimmed
                    break
                }
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
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: nolonManager.mcpsPath) else {
            return []
        }
        
        for item in contents {
            if item.hasPrefix(".") { continue }
            
            let itemPath = "\(nolonManager.mcpsPath)/\(item)"
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                continue
            }
            
            let pathExtension = (item as NSString).pathExtension
            var mcpPath = itemPath
            let slug: String
            
            if pathExtension == "json" {
                slug = (item as NSString).deletingPathExtension
            } else if pathExtension.isEmpty {
                // Migrate legacy cache files without extensions
                slug = item
                let migratedPath = "\(nolonManager.mcpsPath)/\(slug).json"
                if fileManager.fileExists(atPath: migratedPath) {
                    continue
                }
                try? fileManager.moveItem(atPath: mcpPath, toPath: migratedPath)
                mcpPath = migratedPath
            } else {
                continue
            }
            
            guard !seenSlugs.contains(slug) else { continue }
            seenSlugs.insert(slug)
            
            let attributes = try? fileManager.attributesOfItem(atPath: mcpPath)
            let modifiedDate = attributes?[.modificationDate] as? Date
            
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
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Extract using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, tempDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw RepositoryError.extractionFailed
        }
        
        // Find skill root (directory containing SKILL.md)
        guard let skillRoot = findSkillRoot(in: tempDir) else {
            throw RepositoryError.invalidPackage
        }
        
        // Move to destination
        try fileManager.moveItem(at: skillRoot, to: destination)
    }
    
    private func findSkillRoot(in directory: URL) -> URL? {
        // Check if SKILL.md is in root
        let directSkill = directory.appendingPathComponent("SKILL.md")
        if fileManager.fileExists(atPath: directSkill.path) {
            return directory
        }
        
        // Search in subdirectories
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        let candidateDirs = contents.compactMap { url -> URL? in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }
            let skillFile = url.appendingPathComponent("SKILL.md")
            return fileManager.fileExists(atPath: skillFile.path) ? url : nil
        }
        
        return candidateDirs.count == 1 ? candidateDirs[0] : nil
    }
    
    private func countFiles(in directory: String) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return 0
        }
        return contents.filter { !$0.hasPrefix(".") }.count
    }
}
