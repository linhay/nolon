import Foundation
import STJSON
import TOML

/// Unified resource installer for Skills, Workflows, and MCPs
/// Replaces and extends SkillInstaller.swift functionality
public actor ResourceInstaller {
    
    private let globalCache: GlobalCacheRepository
    private let fileManager: FileManager
    private let nolonManager: NolonManager
    
    public init(
        globalCache: GlobalCacheRepository,
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.globalCache = globalCache
        self.fileManager = fileManager
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
            try? fileManager.removeItem(at: downloadURL)
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
        
        if !fileManager.fileExists(atPath: resolvedPath.path),
           let legacyPath = legacyCacheResourcePath(for: resourceSlug, type: resourceType),
           fileManager.fileExists(atPath: legacyPath.path) {
            resolvedPath = legacyPath
        }
        
        guard fileManager.fileExists(atPath: resolvedPath.path) else {
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
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }
        
        // Ensure provider directory exists
        try createDirectory(at: providerPath)
        
        // Install based on provider method
        switch provider.installMethod {
        case .symlink:
            try fileManager.createSymbolicLink(
                atPath: targetPath,
                withDestinationPath: skillPath.path
            )
        case .copy:
            try fileManager.copyItem(atPath: skillPath.path, toPath: targetPath)
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
        
        // Remove existing if present
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }
        
        // Ensure provider workflow directory exists
        try createDirectory(at: providerWorkflowPath)
        
        // Install based on provider method
        switch provider.installMethod {
        case .symlink:
            try fileManager.createSymbolicLink(
                atPath: targetPath,
                withDestinationPath: workflowPath.path
            )
        case .copy:
            try fileManager.copyItem(atPath: workflowPath.path, toPath: targetPath)
        }
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
        
        let mcpConfigPath = await template.defaultMcpConfigPath.path
        
        // Read MCP configuration
        let data = try Data(contentsOf: mcpPath)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(RemoteMCP.MCPConfiguration.self, from: data)
        
        // Ensure MCP config directory exists
        let configDir = (mcpConfigPath as NSString).deletingLastPathComponent
        try createDirectory(at: configDir)
        
        if mcpConfigPath.lowercased().hasSuffix(".toml") {
            var configTable: CodexMCPConfig
            if let existingData = try? Data(contentsOf: URL(fileURLWithPath: mcpConfigPath)),
               let decoded = try? TOMLDecoder().decode(CodexMCPConfig.self, from: existingData) {
                configTable = decoded
            } else {
                configTable = CodexMCPConfig(model: nil, modelReasoningEffort: nil, projects: nil, notice: nil, mcpServers: [:])
            }
            
            var servers = configTable.mcpServers ?? [:]
            servers[slug] = CodexMCPServer(
                url: nil,
                command: config.command,
                args: config.args,
                env: config.env,
                enabled: true
            )
            configTable.mcpServers = servers
            
            let tomlData = try TOMLEncoder().encode(configTable)
            try tomlData.write(to: URL(fileURLWithPath: mcpConfigPath))
        } else {
            // Read existing mcp_settings.json or create new
            var existingConfig: [String: Any] = [:]
            if fileManager.fileExists(atPath: mcpConfigPath) {
                let existingData = try Data(contentsOf: URL(fileURLWithPath: mcpConfigPath))
                if let json = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                    existingConfig = json
                }
            }
            
            // Get or create mcpServers section
            var mcpServers = existingConfig["mcpServers"] as? [String: Any] ?? [:]
            
            // Add/update this MCP
            var serverConfig: [String: Any] = [:]
            if let command = config.command {
                serverConfig["command"] = command
            }
            if let args = config.args {
                serverConfig["args"] = args
            }
            if let env = config.env {
                serverConfig["env"] = env
            }
            
            mcpServers[slug] = serverConfig
            existingConfig["mcpServers"] = mcpServers
            
            // Write back to file
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let updatedData = try JSONSerialization.data(
                withJSONObject: existingConfig,
                options: [.prettyPrinted, .sortedKeys]
            )
            try updatedData.write(to: URL(fileURLWithPath: mcpConfigPath))
        }
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
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }
        
        // Optionally remove from cache
        if removeFromCache {
            try await globalCache.removeFromCache(slug: slug, type: .skill)
        }
    }
    
    private func uninstallWorkflow(slug: String, from provider: Provider, removeFromCache: Bool) async throws {
        let providerWorkflowPath = provider.workflowPath
        let targetPath = "\(providerWorkflowPath)/\(slug).md"
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }
        
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
        
        let mcpConfigPath = await template.defaultMcpConfigPath.path
        
        guard fileManager.fileExists(atPath: mcpConfigPath) else {
            return
        }
        
        if mcpConfigPath.lowercased().hasSuffix(".toml") {
            guard
                let data = try? Data(contentsOf: URL(fileURLWithPath: mcpConfigPath)),
                var config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data),
                var servers = config.mcpServers
            else { return }
            
            servers.removeValue(forKey: slug)
            config.mcpServers = servers
            
            if let tomlData = try? TOMLEncoder().encode(config) {
                try tomlData.write(to: URL(fileURLWithPath: mcpConfigPath))
            }
        } else {
            // Read existing config
            let data = try Data(contentsOf: URL(fileURLWithPath: mcpConfigPath))
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // Remove from mcpServers
            if var mcpServers = json["mcpServers"] as? [String: Any] {
                mcpServers.removeValue(forKey: slug)
                json["mcpServers"] = mcpServers
                
                // Write back
                let updatedData = try JSONSerialization.data(
                    withJSONObject: json,
                    options: [.prettyPrinted, .sortedKeys]
                )
                try updatedData.write(to: URL(fileURLWithPath: mcpConfigPath))
            }
        }
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
