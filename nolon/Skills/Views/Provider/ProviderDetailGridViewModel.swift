import SwiftUI
import ProviderCatalog
import Observation
import STJSON
import TOML
import STFilePath

// MARK: - Codex MCP Config Models (shared)
struct CodexMCPConfig: Codable, Sendable {
    var model: String?
    var modelReasoningEffort: String?
    var projects: [String: CodexProject]?
    var notice: CodexNotice?
    var mcpServers: [String: CodexMCPServer]?
    
    enum CodingKeys: String, CodingKey {
        case model
        case modelReasoningEffort = "model_reasoning_effort"
        case projects
        case notice
        case mcpServers = "mcp_servers"
    }

    nonisolated init(
        model: String? = nil,
        modelReasoningEffort: String? = nil,
        projects: [String: CodexProject]? = nil,
        notice: CodexNotice? = nil,
        mcpServers: [String: CodexMCPServer]? = nil
    ) {
        self.model = model
        self.modelReasoningEffort = modelReasoningEffort
        self.projects = projects
        self.notice = notice
        self.mcpServers = mcpServers
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.modelReasoningEffort = try container.decodeIfPresent(String.self, forKey: .modelReasoningEffort)
        self.projects = try container.decodeIfPresent([String: CodexProject].self, forKey: .projects)
        self.notice = try container.decodeIfPresent(CodexNotice.self, forKey: .notice)
        self.mcpServers = try container.decodeIfPresent([String: CodexMCPServer].self, forKey: .mcpServers)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(modelReasoningEffort, forKey: .modelReasoningEffort)
        try container.encodeIfPresent(projects, forKey: .projects)
        try container.encodeIfPresent(notice, forKey: .notice)
        try container.encodeIfPresent(mcpServers, forKey: .mcpServers)
    }
}

struct CodexProject: Codable, Sendable {
    var trustLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case trustLevel = "trust_level"
    }

    nonisolated init(trustLevel: String? = nil) {
        self.trustLevel = trustLevel
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trustLevel = try container.decodeIfPresent(String.self, forKey: .trustLevel)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(trustLevel, forKey: .trustLevel)
    }
}

struct CodexNotice: Codable, Sendable {
    var modelMigrations: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case modelMigrations = "model_migrations"
    }

    nonisolated init(modelMigrations: [String: String]? = nil) {
        self.modelMigrations = modelMigrations
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.modelMigrations = try container.decodeIfPresent([String: String].self, forKey: .modelMigrations)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(modelMigrations, forKey: .modelMigrations)
    }
}

struct CodexMCPServer: Codable, Sendable {
    var url: String?
    var command: String?
    var args: [String]?
    var env: [String: String]?
    var enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case url
        case command
        case args
        case env
        case enabled
    }

    nonisolated init(
        url: String? = nil,
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil,
        enabled: Bool? = nil
    ) {
        self.url = url
        self.command = command
        self.args = args
        self.env = env
        self.enabled = enabled
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.command = try container.decodeIfPresent(String.self, forKey: .command)
        self.args = try container.decodeIfPresent([String].self, forKey: .args)
        self.env = try container.decodeIfPresent([String: String].self, forKey: .env)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(enabled, forKey: .enabled)
    }
}

extension CodexMCPServer {
    init(from mcp: MCP) {
        let dict = mcp.json.value as? [String: Any] ?? [:]
        url = dict["url"] as? String
        command = dict["command"] as? String
        args = dict["args"] as? [String]
        env = dict["env"] as? [String: String]
        enabled = dict["enabled"] as? Bool
    }
}

/// Detail 区域 Grid 视图的 ViewModel
@MainActor
@Observable
final class ProviderDetailGridViewModel {
    var provider: Provider?
    let settings: ProviderSettings
    
    // Skills
    var installedSkills: [Skill] = []
    var selectedSkillForDetail: Skill?
    
    // Workflows
    var workflows: [WorkflowInfo] = []
    var selectedWorkflowForDetail: WorkflowInfo?
    var workflowIds: Set<String> = []

    // MCPs
    var mcps: [MCP] = []
    var mcpWorkflowIds: Set<String> = []
    var mcpCacheStates: [String: McpCacheState] = [:]
    
    // State
    var isLoading = false
    var errorMessage: String?
    var searchText: String = ""
    var showingRemoteBrowser: RemoteBrowserType? = nil
    
    enum RemoteBrowserType: Identifiable {
        case skill, workflow, mcp
        
        var id: Self { self }
    }
    
    // Internals
    var repository: SkillRepository
    var installer: SkillInstaller
    
    init(provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        let repo = SkillRepository()
        self.repository = repo
        self.installer = SkillInstaller(repository: repo, settings: settings)
    }
    
    func updateProvider(_ provider: Provider?) async {
        self.provider = provider
        await loadData()
    }
    
    func loadData() async {
        guard let provider = provider else {
            installedSkills = []
            workflows = []
            return
        }
        
        isLoading = true
        
        // Load skills - scan all skills in provider directories (not just installed from global)
        do {
            let states = try installer.scanProvider(provider: provider)
            
            // Parse all skills from provider directories (both installed and orphaned)
            // This ensures we show all skills managed by the provider, not just those linked from global
            var parsedSkills: [Skill] = []
            
            for state in states {
                // Skip broken symlinks
                guard state.state != .broken else { continue }
                
                // Try to parse skill from provider directory
                let skillMdPath = "\(state.path)/SKILL.md"
                guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
                      let skill = try? SkillParser.parse(
                          content: content,
                          id: state.skillName,
                          globalPath: state.path
                      ) else {
                    continue
                }
                
                var parsedSkill = Skill(
                    id: skill.id,
                    name: skill.name,
                    description: skill.description,
                    version: skill.version,
                    globalPath: skill.globalPath,
                    content: skill.content,
                    referenceCount: 0,
                    scriptCount: 0
                )
                parsedSkill.sourcePath = state.basePath
                parsedSkill.installationState = state.state
                parsedSkills.append(parsedSkill)
            }
            
            installedSkills = parsedSkills
        } catch {
            errorMessage = error.localizedDescription
        }
        
        // Load workflows
        loadWorkflows(for: provider)
        
        // Load MCPs
        loadMCPs(for: provider)
        
        isLoading = false
    }
    
    private let homeDirectory = NSHomeDirectory()
    
    func displayPath(for path: String) -> String {
        guard let provider = provider else { return path }
        
        if path == provider.defaultSkillsPath {
            return NSLocalizedString("skills.primary_path", value: "Primary Path", comment: "Primary installation path")
        }
        
        if path.hasPrefix(homeDirectory) {
            return "~" + path.dropFirst(homeDirectory.count)
        }
        return path
    }
    
    // MARK: - Filtered Data
    
    /// Generic filter helper using KeyPath
    private func filtered<T>(_ items: [T], searchIn keyPaths: KeyPath<T, String>...) -> [T] {
        guard !searchText.isEmpty else { return items }
        return items.filter { item in
            keyPaths.contains { keyPath in
                item[keyPath: keyPath].localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var filteredSkills: [Skill] {
        filtered(installedSkills, searchIn: \.name, \.description)
    }
    
    var filteredWorkflows: [WorkflowInfo] {
        filtered(workflows, searchIn: \.name, \.description)
    }
    
    var filteredMcps: [MCP] {
        filtered(mcps, searchIn: \.name)
    }
    
    /// Grouped skills for the view, sorted by path (defaultSkillsPath first)
    var groupedFilteredSkills: [(path: String, skills: [Skill])] {
        let skills = filteredSkills
        let grouped = Dictionary(grouping: skills) { $0.sourcePath ?? "" }
        
        guard let provider = provider else { return [] }
        
        let defaultPath = provider.defaultSkillsPath
        let additionalPaths = provider.additionalSkillsPaths ?? []
        
        var result: [(path: String, skills: [Skill])] = []
        
        // 1. Primary path first
        if let defaultSkills = grouped[defaultPath] {
            result.append((path: defaultPath, skills: defaultSkills.sorted { $0.name < $1.name }))
        } else if searchText.isEmpty {
            // Keep an empty section for UI consistency if no search? 
            // Better to only show if there are skills.
        }
        
        // 2. Others sorted
        let otherPaths = additionalPaths.filter { $0 != defaultPath }.sorted()
        for path in otherPaths {
            if let pathSkills = grouped[path] {
                result.append((path: path, skills: pathSkills.sorted { $0.name < $1.name }))
            }
        }
        
        return result
    }
    
    // MARK: - Async Error Handling Helper
    
    /// Generic async operation wrapper with automatic error handling and data reload
    private func performAsync(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadMCPs(for provider: Provider) {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            mcps = []
            return
        }
        
        let configPath = template.defaultMcpConfigPath
        guard STFile(configPath).isExists else {
            mcps = []
            return
        }

        if template.rawValue == "opencode" {
            do {
                let data = try Data(contentsOf: configPath)
                guard !data.isEmpty else {
                    mcps = []
                    refreshMcpCacheStates()
                    return
                }

                let json = try JSON(data: data)
                let servers = json["mcp"].dictionaryValue
                mcps = servers
                    .map { key, value in
                        MCP(name: key, json: AnyCodable(Self.convertOpenCodeMcpServerJson(value.object)))
                    }
                    .sorted { $0.name < $1.name }
                refreshMcpCacheStates()
                return
            } catch {
                mcps = []
                refreshMcpCacheStates()
                return
            }
        }
        
        if configPath.pathExtension.lowercased() == "toml" {
            // Codex uses TOML config
            guard let data = try? Data(contentsOf: configPath) else { mcps = []; return }
            
            // Empty file -> no servers
            if data.isEmpty {
                mcps = []
                return
            }
            
            guard let config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data),
                  let servers = config.mcpServers else {
                mcps = []
                return
            }
            
            mcps = servers
                .map { key, server in
                    var dict: [String: Any] = [:]
                    if let url = server.url { dict["url"] = url }
                    if let command = server.command { dict["command"] = command }
                    if let args = server.args { dict["args"] = args }
                    if let env = server.env { dict["env"] = env }
                    if let enabled = server.enabled { dict["enabled"] = enabled }
                    return MCP(name: key, json: AnyCodable(dict))
                }
                .sorted { $0.name < $1.name }
        } else {
            // Existing JSON workflow
            guard let data = try? Data(contentsOf: configPath),
                  let json = try? JSON(data: data) else {
                mcps = []
                return
            }
            
            // 1. Expand environment variables
            let expandedJson = MCPConfigExpander.expand(json)
            
            // 2. Load enabled servers
            let servers = expandedJson["mcpServers"].dictionary ?? expandedJson["mcp_servers"].dictionary
            if let servers {
                mcps = servers
                    .map { key, value in
                        MCP(name: key, json: AnyCodable(value.object))
                    }
                    .sorted { $0.name < $1.name }
            } else {
                mcps = []
            }
        }

        refreshMcpCacheStates()
    }

    func setMCPEnabled(_ mcp: MCP, enabled: Bool, for provider: Provider) async {
        await performAsync {
            try await updateMCPEnabled(mcp, enabled: enabled, for: provider)
        }
    }

    private func updateMCPEnabled(_ mcp: MCP, enabled: Bool, for provider: Provider) async throws {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            return
        }

        let configPath = template.defaultMcpConfigPath

        if template.rawValue == "opencode" {
            guard STFile(configPath).isExists else { return }
            let data = try Data(contentsOf: configPath)
            var root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            var mcpDict = root["mcp"] as? [String: Any] ?? [:]
            var server = mcpDict[mcp.name] as? [String: Any] ?? [:]
            server["enabled"] = enabled
            mcpDict[mcp.name] = server
            root["mcp"] = mcpDict

            let updated = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try updated.write(to: configPath, options: .atomic)
            loadMCPs(for: provider)
            return
        }

        if configPath.pathExtension.lowercased() == "toml" {
            guard
                STFile(configPath).isExists,
                let data = try? Data(contentsOf: configPath),
                var config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data)
            else {
                return
            }

            if config.mcpServers == nil { config.mcpServers = [:] }
            var server = config.mcpServers?[mcp.name] ?? .init(url: nil, command: nil, args: nil, env: nil, enabled: nil)
            server.enabled = enabled
            config.mcpServers?[mcp.name] = server

            let tomlData = try TOMLEncoder().encode(config)
            try tomlData.write(to: configPath)
        } else {
            var json: JSON
            if STFile(configPath).isExists,
               let data = try? Data(contentsOf: configPath),
               let fileJson = try? JSON(data: data) {
                json = fileJson
            } else {
                json = JSON([:])
            }

            // Normalize legacy key if present.
            if json["mcpServers"].dictionary == nil,
               json["mcp_servers"].dictionary != nil {
                let legacy = json["mcp_servers"]
                var root = json.dictionaryValue
                root["mcpServers"] = legacy
                root["mcp_servers"] = nil
                json = JSON(root)
            }

            if json["mcpServers"].dictionary == nil {
                json["mcpServers"] = JSON([:])
            }

            var servers = json["mcpServers"].dictionaryValue
            var server = servers[mcp.name]?.dictionaryObject ?? [:]

            if enabled {
                server["disabled"] = nil
            } else {
                server["disabled"] = true
            }

            servers[mcp.name] = JSON(server)
            json["mcpServers"] = JSON(servers)

            if let str = json.rawString() {
                try str.write(to: configPath, atomically: true, encoding: .utf8)
            }
        }

        loadMCPs(for: provider)
    }

    struct McpCacheMigrationResult: Sendable {
        let migrated: Int
        let skipped: Int
    }

    enum McpCacheState: String, Sendable {
        case notMigrated
        case migratedUpToDate
        case migratedNeedsUpdate
    }

    /// Export provider MCP servers into ~/.nolon/mcps as standard MCP JSON files.
    /// This does NOT modify the provider's MCP config file.
    func migrateMcpServersToGlobalCache(for provider: Provider) async throws -> McpCacheMigrationResult {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            return .init(migrated: 0, skipped: 0)
        }

        let configPath = template.defaultMcpConfigPath
        guard STFile(configPath).isExists else {
            return .init(migrated: 0, skipped: 0)
        }

        var serverConfigs: [String: [String: Any]] = [:]

        if configPath.pathExtension.lowercased() == "toml" {
            let data = try Data(contentsOf: configPath)
            guard !data.isEmpty else { return .init(migrated: 0, skipped: 0) }
            let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: data)
            let servers = config.mcpServers ?? [:]
            for (name, server) in servers {
                var dict: [String: Any] = [:]
                if let url = server.url { dict["url"] = url }
                if let command = server.command { dict["command"] = command }
                if let args = server.args { dict["args"] = args }
                if let env = server.env { dict["env"] = env }
                if let enabled = server.enabled, enabled == false { dict["disabled"] = true }

                // Claude MCP JSON uses `type` to describe transport.
                if dict["type"] == nil {
                    if dict["command"] != nil {
                        dict["type"] = "stdio"
                    } else if dict["url"] != nil {
                        dict["type"] = "http"
                    }
                }
                serverConfigs[name] = dict
            }
        } else {
            let data = try Data(contentsOf: configPath)
            guard !data.isEmpty else { return .init(migrated: 0, skipped: 0) }
            let json = try JSON(data: data)
            let servers = json["mcpServers"].dictionaryValue.isEmpty ? json["mcp_servers"].dictionaryValue : json["mcpServers"].dictionaryValue
            for (name, value) in servers {
                var dict = value.dictionaryObject ?? [:]

                if dict["type"] == nil {
                    if dict["command"] != nil {
                        dict["type"] = "stdio"
                    } else if dict["url"] != nil {
                        dict["type"] = "http"
                    }
                }
                serverConfigs[name] = dict
            }
        }

        guard !serverConfigs.isEmpty else {
            return .init(migrated: 0, skipped: 0)
        }

        let manager = NolonManager.shared
        STFolder(manager.mcpsURL).createIfNotExists()

        var migrated = 0
        var skipped = 0

        for (name, serverDict) in serverConfigs {
            let fileName = "\(safeMcpCacheFileStem(for: name)).json"
            let targetURL = manager.mcpsURL.appendingPathComponent(fileName)
            if STFile(targetURL).isExists {
                skipped += 1
                continue
            }

            let root: [String: Any] = ["mcpServers": [name: serverDict]]

            let data = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            try data.write(to: targetURL, options: .atomic)
            migrated += 1
        }

        return .init(migrated: migrated, skipped: skipped)
    }

    func migrateMcpToGlobalCache(_ mcp: MCP) async throws {
        let manager = NolonManager.shared
        STFolder(manager.mcpsURL).createIfNotExists()

        let targetURL = mcpCacheFileURL(for: mcp.name)
        guard !STFile(targetURL).isExists else {
            refreshMcpCacheStates()
            return
        }

        let server = normalizedProviderServerConfig(for: mcp)
        let root: [String: Any] = ["mcpServers": [mcp.name: server]]
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: targetURL, options: .atomic)
        refreshMcpCacheStates()
    }

    func updateCachedMcpIfNeeded(_ mcp: MCP) async throws {
        let manager = NolonManager.shared
        STFolder(manager.mcpsURL).createIfNotExists()

        let targetURL = mcpCacheFileURL(for: mcp.name)
        guard STFile(targetURL).isExists else {
            try await migrateMcpToGlobalCache(mcp)
            return
        }

        let desired = normalizedProviderServerConfig(for: mcp)
        let existingData = try Data(contentsOf: targetURL)
        let existingServer = (try? MCPJsonFile.serverConfig(from: existingData, slug: mcp.name)) ?? [:]
        let existing = normalizedServerConfigForComparison(existingServer, name: mcp.name)

        if canonicalJsonData(existing) == canonicalJsonData(desired) {
            refreshMcpCacheStates()
            return
        }

        let root: [String: Any] = ["mcpServers": [mcp.name: desired]]
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: targetURL, options: .atomic)
        refreshMcpCacheStates()
    }

    private func safeMcpCacheFileStem(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UUID().uuidString }

        // Avoid creating nested paths. Keep common filename-safe characters.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ ."))
        let mapped = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }

        var result = String(mapped)
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
        return result.isEmpty ? UUID().uuidString : result
    }

    private func mcpCacheFileURL(for name: String) -> URL {
        NolonManager.shared.mcpsURL.appendingPathComponent("\(safeMcpCacheFileStem(for: name)).json")
    }

    private func refreshMcpCacheStates() {
        var states: [String: McpCacheState] = [:]

        for mcp in mcps {
            let url = mcpCacheFileURL(for: mcp.name)
            guard STFile(url).isExists else {
                states[mcp.name] = .notMigrated
                continue
            }

            let desired = normalizedProviderServerConfig(for: mcp)
            if let data = try? Data(contentsOf: url),
               let server = try? MCPJsonFile.serverConfig(from: data, slug: mcp.name) {
                let existing = normalizedServerConfigForComparison(server, name: mcp.name)
                states[mcp.name] = (canonicalJsonData(existing) == canonicalJsonData(desired))
                    ? .migratedUpToDate
                    : .migratedNeedsUpdate
            } else {
                states[mcp.name] = .migratedNeedsUpdate
            }
        }

        mcpCacheStates = states
    }

    private func normalizedProviderServerConfig(for mcp: MCP) -> [String: Any] {
        normalizedServerConfigForComparison(mcp.dictionaryValue, name: mcp.name, isEnabled: mcp.isEnabled)
    }

    private func normalizedServerConfigForComparison(
        _ input: [String: Any],
        name: String,
        isEnabled: Bool? = nil
    ) -> [String: Any] {
        var dict = input

        // Normalize enable/disable representation for cache: prefer `disabled`.
        let enabled: Bool = isEnabled ?? MCPJsonFile.serverFields(from: dict).isEnabled
        dict.removeValue(forKey: "enabled")
        if enabled {
            dict.removeValue(forKey: "disabled")
        } else {
            dict["disabled"] = true
        }

        // Ensure Claude-style `type` exists.
        if dict["type"] == nil {
            if dict["command"] != nil {
                dict["type"] = "stdio"
            } else if dict["url"] != nil {
                dict["type"] = "http"
            }
        }

        // If the dict came from a provider JSON that had legacy key names, keep server payload untouched
        // besides normalization above.
        _ = name
        return dict
    }

    private func canonicalJsonData(_ object: Any) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private static func convertOpenCodeMcpServerJson(_ object: Any) -> [String: Any] {
        guard let dict = object as? [String: Any] else { return [:] }
        var result: [String: Any] = dict

        if let commandArray = dict["command"] as? [Any] {
            let parts = commandArray.compactMap { $0 as? String }
            if let first = parts.first {
                result["command"] = first
                let rest = Array(parts.dropFirst())
                if !rest.isEmpty { result["args"] = rest }
            }
        }

        if let env = dict["environment"] as? [String: Any] {
            result["env"] = env.compactMapValues { $0 as? String }
        }

        if let enabled = dict["enabled"] as? Bool {
            result["enabled"] = enabled
            result["disabled"] = enabled ? nil : true
        }

        if let type = dict["type"] as? String {
            if type == "local" { result["type"] = "stdio" }
            if type == "remote" { result["type"] = "http" }
        }

        return result
    }
    
    private func loadMcpWorkflows() {
        let path = NolonManager.shared.mcpsWorkflowsPath
        let folder = STFolder(path)
        guard folder.isExists else {
            mcpWorkflowIds = []
            return
        }
        
        do {
            let contents = try folder.files()
            mcpWorkflowIds = Set(
                contents
                    .filter { $0.url.pathExtension == "md" }
                    .map { $0.url.deletingPathExtension().lastPathComponent }
            )
        } catch {
            mcpWorkflowIds = []
        }
    }
    
    func updateMCP(_ mcp: MCP?, for provider: Provider) async {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            return
        }
        
        let configPath = template.defaultMcpConfigPath
        
        if configPath.pathExtension.lowercased() == "toml" {
            // For TOML config, we only support updating enabled flag and basic fields
            guard STFile(configPath).isExists,
                  let data = try? Data(contentsOf: configPath),
                  var config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data)
            else {
                return
            }
            
            if config.mcpServers == nil { config.mcpServers = [:] }
            if let mcp = mcp {
                config.mcpServers?[mcp.name] = CodexMCPServer(from: mcp)
            }
            
            if let tomlData = try? TOMLEncoder().encode(config) {
                try? tomlData.write(to: configPath)
            }
        } else {
            var json: JSON
            if STFile(configPath).isExists,
               let data = try? Data(contentsOf: configPath),
               let fileJson = try? JSON(data: data) {
                json = fileJson
            } else {
                json = JSON([:])
            }
            
            // 2. Ensure mcpServers object exists
            if json["mcpServers"].dictionary == nil,
               json["mcp_servers"].dictionary != nil {
                let legacy = json["mcp_servers"]
                var root = json.dictionaryValue
                root["mcpServers"] = legacy
                root["mcp_servers"] = nil
                json = JSON(root)
            }
            if json["mcpServers"].dictionary == nil {
                json["mcpServers"] = JSON([:])
            }
            
            // 3. Update or delete
            if let mcp = mcp {
                // Add or Update
                // Get mutable dictionary
                var servers = json["mcpServers"].dictionaryValue
                servers[mcp.name] = JSON(mcp.json.value)
                json["mcpServers"] = JSON(servers)
            } else {
                 // Handle delete logic here if extended
            }
            
            // 4. Write back
            if let str = json.rawString() {
                try? str.write(to: configPath, atomically: true, encoding: .utf8)
            }
        }
        
        // 5. Reload
        loadMCPs(for: provider)
    }
    
    func deleteMCP(named name: String, for provider: Provider) async {
         guard let templateId = provider.templateId,
               let template = ProviderTemplate(rawValue: templateId) else {
             return
         }
         
         let configPath = template.defaultMcpConfigPath
         
         if template.rawValue == "opencode" {
             do {
                 let data = try Data(contentsOf: configPath)
                 var root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                 var mcpDict = root["mcp"] as? [String: Any] ?? [:]
                 mcpDict[name] = nil
                 root["mcp"] = mcpDict
                 let updated = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
                 try updated.write(to: configPath, options: .atomic)
             } catch {
                 // ignore
             }
             
             loadMCPs(for: provider)
             return
         }
         
         if configPath.pathExtension.lowercased() == "toml" {
             guard
                 let data = try? Data(contentsOf: configPath),
                 var config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data),
                 var servers = config.mcpServers
             else { return }
             
             servers[name] = nil
             config.mcpServers = servers
             
             if let tomlData = try? TOMLEncoder().encode(config) {
                 try? tomlData.write(to: configPath)
             }
         } else {
             guard let data = try? Data(contentsOf: configPath),
                   var json = try? JSON(data: data) else { return }
             
             if json["mcpServers"].dictionary == nil,
                json["mcp_servers"].dictionary != nil {
                 let legacy = json["mcp_servers"]
                 var root = json.dictionaryValue
                 root["mcpServers"] = legacy
                 root["mcp_servers"] = nil
                 json = JSON(root)
             }

             var servers = json["mcpServers"].dictionaryValue
             servers[name] = nil
             json["mcpServers"] = JSON(servers)
             
             if let str = json.rawString() {
                 try? str.write(to: configPath, atomically: true, encoding: .utf8)
             }
         }
         
         loadMCPs(for: provider)
    }
    
    private func loadWorkflows(for provider: Provider) {
        let workflowPath = provider.workflowPath
        let folder = STFolder(workflowPath)
        guard folder.isExists else {
            workflows = []
            mcpWorkflowIds = []
            workflowIds = []
            return
        }
        
        do {
            let contents = try folder.files()
            workflows = contents
                .filter { $0.url.pathExtension == "md" }
                .compactMap { WorkflowInfo.parse(from: $0.url) }
                .sorted { $0.name < $1.name }
            
            workflowIds = Set(workflows.filter { $0.source == .skill }.map(\.id))
            mcpWorkflowIds = Set(workflows.filter { $0.source == .mcp }.map(\.id))
        } catch {
            workflows = []
            mcpWorkflowIds = []
            workflowIds = []
        }
    }
    
    // MARK: - Actions
    
    func revealSkillInFinder(_ skill: Skill) {
        guard let provider = provider else { return }
        let path = (provider.defaultSkillsPath as NSString).appendingPathComponent(skill.id)
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    
    func uninstallSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        await performAsync {
            try installer.uninstall(skill: skill, from: provider)
        }
    }
    
    func linkSkillToWorkflow(_ skill: Skill) {
        guard let provider = provider else { return }
        
        do {
            try installer.installWorkflow(skill: skill, to: provider)
            loadWorkflows(for: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func unlinkSkillFromWorkflow(_ skill: Skill) {
        guard let provider = provider else { return }
        
        do {
            try installer.uninstallWorkflow(skill: skill, from: provider)
            loadWorkflows(for: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func linkMcpToWorkflow(_ mcp: MCP) {
        guard let provider = provider else { return }
        
        do {
            try installer.installMcpWorkflow(mcp: mcp, to: provider)
            loadWorkflows(for: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func unlinkMcpFromWorkflow(_ mcp: MCP) {
        guard let provider = provider else { return }
        
        do {
            try installer.uninstallMcpWorkflow(mcp: mcp, from: provider)
            loadWorkflows(for: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        await performAsync {
            _ = try installer.migrate(skillName: skill.id, from: provider, overwriteExisting: false)
        }
    }
    
    func revealWorkflowInFinder(_ workflow: WorkflowInfo) {
        NSWorkspace.shared.selectFile(workflow.path, inFileViewerRootedAtPath: "")
    }
    
    func deleteWorkflow(_ workflow: WorkflowInfo) async {
        guard let provider = provider else { return }
        
        // Find skill ID from workflow ID or path
        // Currently WorkflowInfo.id is the filename without extension, which usually matches skill.id
        // However, we need a Skill object to call uninstallWorkflow.
        // But uninstallWorkflow mainly needs the ID.
        // We can create a dummy Skill or overload uninstallWorkflow.
        // Let's modify SkillInstaller to accept ID or make a temporary fix here.
        // Better: Fetch the skill from repository if possible, or construct one.
        // Since we only need ID for the path in `uninstallWorkflow`, let's construct a minimal Skill or extend Installer.
        // Extended Installer is better but requires changing infrastructure again.
        // For now, let's look at `uninstallWorkflow`:
        // public func uninstallWorkflow(skill: Skill, from provider: Provider)
        // It uses skill.id.
        
        // Let's check `WorkflowInfo` in `loadWorkflows`. It uses filename as ID.
        // Assuming workflow ID == skill ID.
        
        // To construct a Skill, we need a lot of params.
        // Let's just manually delete the symlink here using the logic from `SkillInstaller`, 
        // OR better: Update SkillInstaller to create an overload that takes ID.
        // But avoiding context switch, I will try to find the skill from `installedSkills` or `allSkills`.
        
        if let skill = try? repository.listSkills().first(where: { $0.id == workflow.id }) {
            try? installer.uninstallWorkflow(skill: skill, from: provider)
        } else {
             // Fallback: Manually remove file if skill not found (orphan workflow)
            try? STPath(workflow.path).deleteIncludingBrokenSymlink()
        }
        
        loadWorkflows(for: provider)
    }
    
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        await performAsync {
            if let localPath = skill.localPath {
                try installer.installLocal(from: localPath, slug: skill.slug, to: provider)
            } else {
                let clawdhubRepo = ClawdhubRepository(
                    repository: settings.remoteRepositories.first { $0.templateType == .clawdhub }
                        ?? RepositoryTemplate.clawdhub.createRepository()
                )

                let zipURL = try await clawdhubRepo.downloadSkill(
                    slug: skill.slug,
                    version: skill.latestVersion?.version
                )
                try installer.installRemote(zipURL: zipURL, slug: skill.slug, to: provider)
            }
        }
    }
    
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        await performAsync {
            if let localPath = workflow.localPath {
                try installer.installLocalWorkflow(
                    fileURL: URL(fileURLWithPath: localPath),
                    slug: workflow.slug,
                    to: provider
                )
            } else {
                let clawdhubRepo = ClawdhubRepository(
                    repository: settings.remoteRepositories.first { $0.templateType == .clawdhub }
                        ?? RepositoryTemplate.clawdhub.createRepository()
                )

                let fileURL = try await clawdhubRepo.downloadWorkflow(
                    slug: workflow.slug,
                    version: workflow.latestVersion?.version
                )
                try installer.installRemoteWorkflow(fileURL: fileURL, slug: workflow.slug, to: provider)
            }
        }
    }
    
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        await performAsync {
            let resourceInstaller = ResourceInstaller(globalCache: GlobalCacheRepository())

            if let localPath = mcp.localPath {
                try await resourceInstaller.installFromLocal(
                    resourceURL: URL(fileURLWithPath: localPath),
                    resourceSlug: mcp.slug,
                    resourceType: .mcp,
                    to: provider
                )
            } else {
                let clawdhubRepo = ClawdhubRepository(
                    repository: settings.remoteRepositories.first { $0.templateType == .clawdhub }
                        ?? RepositoryTemplate.clawdhub.createRepository()
                )

                try await resourceInstaller.installFromRemote(
                    repository: clawdhubRepo,
                    resourceSlug: mcp.slug,
                    resourceType: .mcp,
                    to: provider
                )
            }
        }
    }
}
