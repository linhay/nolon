import Foundation
import STJSON
import STFilePath
import ProviderCatalog

/// Unified resource installer for Skills, Workflows, and MCPs
/// Replaces and extends SkillInstaller.swift functionality
public actor ResourceInstaller {
    
    private let globalCache: GlobalCacheRepository
    private let nolonManager: NolonManager
    
    public init(
        globalCache: GlobalCacheRepository,
        nolonManager: NolonManager = .shared
    ) {
        self.globalCache = globalCache
        self.nolonManager = nolonManager
    }
    
    // MARK: - Complete Installation Flow
    
    /// Install resource from remote repository
    /// 1. Download to temporary location
    /// 2. Cache in global storage
    /// 3. Install to provider
    public func installFromRemote(
        repository: any RemoteResourceRepository,
        resourceSlug: String,
        resourceType: RemoteContentType,
        to provider: Provider
    ) async throws {
        // 1. Download
        let downloadURL: URL
        switch resourceType {
        case .skill:
            downloadURL = try await repository.downloadSkill(slug: resourceSlug)
        case .workflow:
            downloadURL = try await repository.downloadWorkflow(slug: resourceSlug)
        case .mcp:
            downloadURL = try await repository.downloadMCP(slug: resourceSlug)
        }
        
        defer {
            try? STPath(downloadURL).deleteIncludingBrokenSymlink()
        }
        
        // 2. Cache to global storage
        let cachedURL = try await globalCache.cacheResource(
            from: downloadURL,
            slug: resourceSlug,
            type: resourceType
        )
        
        // 3. Install to provider
        try await installToProvider(
            resourcePath: cachedURL,
            slug: resourceSlug,
            type: resourceType,
            provider: provider
        )
    }
    
    /// Install resource from global cache to provider
    public func installFromCache(
        resourceSlug: String,
        resourceType: RemoteContentType,
        to provider: Provider
    ) async throws {
        let resourcePath = cacheResourcePath(for: resourceSlug, type: resourceType)
        var resolvedPath = resourcePath
        
        if !STPath(resolvedPath).isExists,
           let legacyPath = legacyCacheResourcePath(for: resourceSlug, type: resourceType),
           STPath(legacyPath).isExists {
            resolvedPath = legacyPath
        }
        
        guard STPath(resolvedPath).isExists else {
            throw RepositoryError.resourceNotFound(resourceSlug)
        }
        
        try await installToProvider(
            resourcePath: resolvedPath,
            slug: resourceSlug,
            type: resourceType,
            provider: provider
        )
    }

    /// Install resource from a local path (non-cached)
    public func installFromLocal(
        resourceURL: URL,
        resourceSlug: String,
        resourceType: RemoteContentType,
        to provider: Provider
    ) async throws {
        try await installToProvider(
            resourcePath: resourceURL,
            slug: resourceSlug,
            type: resourceType,
            provider: provider
        )
    }
    
    // MARK: - Provider Installation
    
    private func installToProvider(
        resourcePath: URL,
        slug: String,
        type: RemoteContentType,
        provider: Provider
    ) async throws {
        switch type {
        case .skill:
            try await installSkillToProvider(
                skillPath: resourcePath,
                slug: slug,
                provider: provider
            )
            
        case .workflow:
            try await installWorkflowToProvider(
                workflowPath: resourcePath,
                slug: slug,
                provider: provider
            )
            
        case .mcp:
            try await installMCPToProvider(
                mcpPath: resourcePath,
                slug: slug,
                provider: provider
            )
        }
    }
    
    // MARK: - Skill Installation
    
    private func installSkillToProvider(
        skillPath: URL,
        slug: String,
        provider: Provider
    ) async throws {
        let providerPath = provider.defaultSkillsPath
        let targetPath = "\(providerPath)/\(slug)"
        
        // Remove existing if present
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        // Ensure provider directory exists
        _ = STFolder(providerPath).createIfNotExists()        
        // Install based on provider method
        switch provider.installMethod {
        case .symlink:
            try STPath(targetPath).createSymbolicLink(to: STPath(skillPath))
        case .copy:
            try STPath(skillPath).copy(to: STPath(targetPath), isOverlay: true)
        }
    }
    
    // MARK: - Workflow Installation
    
    private func installWorkflowToProvider(
        workflowPath: URL,
        slug: String,
        provider: Provider
    ) async throws {
        let providerWorkflowPath = provider.workflowPath
        let targetPath = "\(providerWorkflowPath)/\(slug).md"
        let isOpenCode = provider.templateId == "opencode"
        
        // Remove existing if present
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        // Ensure provider workflow directory exists
        _ = STFolder(providerWorkflowPath).createIfNotExists()        
        // Install based on provider method
        switch provider.installMethod {
        case .symlink where !isOpenCode:
            try STPath(targetPath).createSymbolicLink(to: STPath(workflowPath))
        case .symlink, .copy:
            try STPath(workflowPath).copy(to: STPath(targetPath), isOverlay: true)
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

        let header = """
        ---
        name: \(yamlQuoted(slug))
        description: \(yamlQuoted("OpenCode command installed by Nolon."))
        \(agentLine)---
        
        """
        try STFile(path).overlay(with: header + content)
    }
    
    // MARK: - MCP Installation
    
    private func installMCPToProvider(
        mcpPath: URL,
        slug: String,
        provider: Provider
    ) async throws {
        // Get MCP config path from provider template or use default
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            throw RepositoryError.invalidConfiguration
        }
        
        let mcpConfigPath = template.defaultMcpConfigPath.path
        
        // Read MCP configuration
        let data = try STFile(mcpPath).data()
        let serverConfig: [String: Any]
        if let parsed = try? MCPJsonFile.serverConfig(from: data, slug: slug) {
            serverConfig = parsed
        } else {
            // Legacy: file may be a single server config object
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let config = try decoder.decode(RemoteMCP.MCPConfiguration.self, from: data)
            var legacy: [String: Any] = [:]
            if let command = config.command { legacy["command"] = command }
            if let args = config.args { legacy["args"] = args }
            if let env = config.env { legacy["env"] = env }
            serverConfig = legacy
        }
        let fields = MCPJsonFile.serverFields(from: serverConfig)
        
        // Ensure MCP config directory exists
        let configDir = (mcpConfigPath as NSString).deletingLastPathComponent
        _ = STFolder(configDir).createIfNotExists()

        // Use the shared MCP config writer for every provider so cache ownership,
        // provider-specific sanitization, and Codex TOML patching all stay consistent.
        var projectedConfig = serverConfig
        if projectedConfig["url"] == nil, let url = fields.url { projectedConfig["url"] = url }
        if projectedConfig["command"] == nil, let command = fields.command { projectedConfig["command"] = command }
        if projectedConfig["args"] == nil, let args = fields.args { projectedConfig["args"] = args }
        if projectedConfig["env"] == nil, let env = fields.env { projectedConfig["env"] = env }
        if fields.isEnabled {
            projectedConfig["enabled"] = true
            projectedConfig["disabled"] = nil
        } else {
            projectedConfig["enabled"] = nil
            projectedConfig["disabled"] = true
        }
        try MCPConfigManager.upsertServer(for: template, name: slug, serverConfig: projectedConfig)
    }
    
    // MARK: - Uninstallation
    
    /// Uninstall resource from provider
    public func uninstall(
        resourceSlug: String,
        resourceType: RemoteContentType,
        from provider: Provider,
        removeFromCache: Bool = false
    ) async throws {
        switch resourceType {
        case .skill:
            try await uninstallSkill(slug: resourceSlug, from: provider, removeFromCache: removeFromCache)
        case .workflow:
            try await uninstallWorkflow(slug: resourceSlug, from: provider, removeFromCache: removeFromCache)
        case .mcp:
            try await uninstallMCP(slug: resourceSlug, from: provider)
        }
    }
    
    private func uninstallSkill(slug: String, from provider: Provider, removeFromCache: Bool) async throws {
        // Remove from provider
        let providerPath = provider.defaultSkillsPath
        let targetPath = "\(providerPath)/\(slug)"
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        // Optionally remove from cache
        if removeFromCache {
            try await globalCache.removeFromCache(slug: slug, type: .skill)
        }
    }
    
    private func uninstallWorkflow(slug: String, from provider: Provider, removeFromCache: Bool) async throws {
        let providerWorkflowPath = provider.workflowPath
        let targetPath = "\(providerWorkflowPath)/\(slug).md"
        try STPath(targetPath).deleteIncludingBrokenSymlink()
        
        if removeFromCache {
            try await globalCache.removeFromCache(slug: slug, type: .workflow)
        }
    }
    
    private func uninstallMCP(slug: String, from provider: Provider) async throws {
        // Get MCP config path from provider template
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            return
        }
        
        try MCPConfigManager.removeServer(for: template, name: slug)
    }
    
    // MARK: - Helpers
    
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
}
