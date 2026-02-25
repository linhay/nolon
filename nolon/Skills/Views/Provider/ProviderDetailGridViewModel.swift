import SwiftUI
import ProviderCatalog
import CodexProvider
import Observation
import STJSON
import TOML
import STFilePath
import NolonResourceKit

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
    
    // Rules
    var rules: [RuleInfo] = []
    
    // AGENTS.md docs
    var agentsFiles: [AgentDocInfo] = []

    // MCPs
    var mcps: [MCP] = []
    var mcpWorkflowIds: Set<String> = []
    var mcpCacheStates: [String: McpCacheState] = [:]
    
    // State
    var isLoading = false
    var errorMessage: String?
    var searchText: String = ""
    var showingRemoteBrowser: RemoteBrowserType? = nil
    var codexModelOptions: [String] = []
    var selectedCodexModel: String?
    var isSavingCodexModel = false
    var codexModelStatusMessage: String?
    
    enum RemoteBrowserType: Identifiable {
        case skill, workflow, mcp
        
        var id: Self { self }
    }
    
    // Internals
    var repository: SkillRepository
    var installer: SkillInstaller
    private let resourceService: ProviderResourceService
    private let mcpMaintenanceService = ProviderMCPMaintenanceService()
    private let remoteInstallOrchestrator = RemoteInstallOrchestrator()
    
    init(provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        let repo = SkillRepository()
        self.repository = repo
        self.installer = SkillInstaller(repository: repo, settings: settings)
        self.resourceService = ProviderResourceService()
    }
    
    func updateProvider(_ provider: Provider?) async {
        self.provider = provider
        await loadData()
    }
    
    func loadData() async {
        guard let provider = provider else {
            installedSkills = []
            workflows = []
            rules = []
            agentsFiles = []
            mcps = []
            codexModelOptions = []
            selectedCodexModel = nil
            codexModelStatusMessage = nil
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
        
        // Load rules
        loadRules(for: provider)
        
        // Load AGENTS docs
        loadAgentsFiles(for: provider)
        
        // Load MCPs
        loadMCPs(for: provider)
        loadCodexBinaryModels(for: provider)
        
        isLoading = false
    }

    var hasCodexBinarySupport: Bool {
        guard let templateId = provider?.templateId else { return false }
        return templateId == "codex" || templateId == "codexXcode"
    }

    func saveSelectedCodexModel(_ model: String?) async {
        guard let provider else { return }
        guard hasCodexBinarySupport else { return }
        guard let templateId = provider.templateId, let template = ProviderTemplate(rawValue: templateId) else { return }

        isSavingCodexModel = true
        defer { isSavingCodexModel = false }

        do {
            let configFile = STFile(template.defaultMcpConfigPath)
            let trimmed = model?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = (trimmed?.isEmpty == false) ? trimmed : nil
            if let normalized {
                try await CodexBinaryManager.shared.applyModelToConfig(normalized, configFile: configFile)
            } else {
                try await CodexBinaryManager.shared.clearPreferredModel(configFile: configFile)
            }
            selectedCodexModel = normalized
            codexModelStatusMessage = NSLocalizedString(
                "provider.binary.codex.model.saved",
                value: "Model preference saved.",
                comment: "Codex model saved status"
            )
        } catch {
            codexModelStatusMessage = error.localizedDescription
        }
    }

    private func loadCodexBinaryModels(for provider: Provider) {
        guard hasCodexBinarySupport else {
            codexModelOptions = []
            selectedCodexModel = nil
            codexModelStatusMessage = nil
            return
        }

        let configuredModel = loadCurrentConfiguredModel(for: provider)
        selectedCodexModel = configuredModel

        var options: [String] = []
        var seen = Set<String>()
        for url in modelsCacheURLs(for: provider) {
            for slug in loadVisibleModelSlugs(url) where seen.insert(slug).inserted {
                options.append(slug)
            }
        }

        if let configuredModel, !configuredModel.isEmpty, seen.insert(configuredModel).inserted {
            options.insert(configuredModel, at: 0)
        }
        codexModelOptions = options
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
    
    var filteredRules: [RuleInfo] {
        filtered(rules, searchIn: \.name, \.preview, \.relativePath)
    }
    
    var filteredAgentsFiles: [AgentDocInfo] {
        filtered(agentsFiles, searchIn: \.fileName, \.preview)
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
            mcpCacheStates = [:]
            return
        }
        do {
            let snapshot = try mcpMaintenanceService.listSnapshot(template: template)
            mcps = snapshot.mcps
            mcpCacheStates = snapshot.cacheStates.reduce(into: [:]) { partialResult, item in
                partialResult[item.key] = McpCacheState(rawValue: item.value.rawValue) ?? .notMigrated
            }
        } catch {
            mcps = []
            mcpCacheStates = [:]
        }
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
        try mcpMaintenanceService.setEnabled(template: template, name: mcp.name, enabled: enabled)

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
        let result = try mcpMaintenanceService.migrateServersToGlobalCache(template: template, overwrite: false)
        return .init(migrated: result.migrated, skipped: result.skipped)
    }

    func migrateMcpToGlobalCache(_ mcp: MCP) async throws {
        try mcpMaintenanceService.migrateMcpToGlobalCache(mcp)
        refreshMcpCacheStates()
    }

    func updateCachedMcpIfNeeded(_ mcp: MCP) async throws {
        try mcpMaintenanceService.updateCachedMcpIfNeeded(mcp)
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
        guard let provider,
              let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            mcpCacheStates = [:]
            return
        }
        do {
            let states = try mcpMaintenanceService.cacheStatus(template: template)
            mcpCacheStates = Dictionary(
                uniqueKeysWithValues: states.map { ($0.name, McpCacheState(rawValue: $0.state.rawValue) ?? .notMigrated) }
            )
        } catch {
            mcpCacheStates = [:]
        }
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

        if let mcp {
            try? mcpMaintenanceService.upsertMCP(template: template, mcp: mcp)
        }
        
        // 5. Reload
        loadMCPs(for: provider)
    }
    
    func deleteMCP(named name: String, for provider: Provider) async {
         guard let templateId = provider.templateId,
               let template = ProviderTemplate(rawValue: templateId) else {
             return
         }
         try? mcpMaintenanceService.removeServer(template: template, name: name)
         
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
    
    private func loadRules(for provider: Provider) {
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else {
            rules = []
            return
        }

        let baseFolder = STFolder(provider.codexRulesURL)
        guard baseFolder.isExists else {
            rules = []
            return
        }

        func collectRuleFiles(in folder: STFolder) -> [URL] {
            var result: [URL] = []
            let files = (try? folder.files()) ?? []
            for file in files where !file.url.lastPathComponent.hasPrefix(".") {
                if file.url.pathExtension.lowercased() == "rules" {
                    result.append(file.url)
                }
            }

            let childFolders = (try? folder.folders()) ?? []
            for child in childFolders where !child.url.lastPathComponent.hasPrefix(".") {
                result.append(contentsOf: collectRuleFiles(in: child))
            }
            return result
        }

        var parsedRules: [RuleInfo] = []
        for fileURL in collectRuleFiles(in: baseFolder) {
            if let rule = RuleInfo.parse(from: fileURL, baseDirectory: baseFolder.url) {
                parsedRules.append(rule)
            }
        }

        rules = parsedRules.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private func loadAgentsFiles(for provider: Provider) {
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else {
            agentsFiles = []
            return
        }

        let overridePath = STFile(provider.codexAgentsOverrideFileURL)
        let basePath = STFile(provider.codexAgentsFileURL)
        var docs: [AgentDocInfo] = []

        if overridePath.isExists,
           let doc = AgentDocInfo.parse(url: overridePath.url, kind: .override) {
            docs.append(doc)
        }

        if basePath.isExists,
           let doc = AgentDocInfo.parse(url: basePath.url, kind: .base) {
            docs.append(doc)
        }

        agentsFiles = docs
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
    
    func revealRuleInFinder(_ rule: RuleInfo) {
        NSWorkspace.shared.selectFile(rule.path, inFileViewerRootedAtPath: "")
    }
    
    func deleteWorkflow(_ workflow: WorkflowInfo) async {
        guard let provider = provider else { return }
        do {
            try resourceService.deleteWorkflow(workflowID: workflow.id, provider: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
        loadWorkflows(for: provider)
    }
    
    func deleteRule(_ rule: RuleInfo) async {
        guard let provider else { return }
        do {
            try resourceService.deleteResource(atPath: rule.path)
        } catch {
            errorMessage = error.localizedDescription
        }
        loadRules(for: provider)
    }

    func revealAgentDocInFinder(_ doc: AgentDocInfo) {
        NSWorkspace.shared.selectFile(doc.path, inFileViewerRootedAtPath: "")
    }

    func deleteAgentDoc(_ doc: AgentDocInfo) async {
        guard let provider else { return }
        do {
            try resourceService.deleteResource(atPath: doc.path)
        } catch {
            errorMessage = error.localizedDescription
        }
        loadAgentsFiles(for: provider)
    }

    func createAgentDocDraft() -> URL? {
        guard let provider else { return nil }
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else { return nil }
        do {
            let basePath = STPath(provider.codexAgentsFileURL)
            let draftKind: ProviderResourceDraftKind = basePath.isExists ? .agentOverride : .agentBase
            let targetURL = try resourceService.createDraft(provider: provider, kind: draftKind)
            loadAgentsFiles(for: provider)
            return targetURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createRuleDraft() -> URL? {
        guard let provider else { return nil }
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else { return nil }

        do {
            let draftURL = try resourceService.createDraft(provider: provider, kind: .rule)
            loadRules(for: provider)
            return draftURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        await performAsync {
            try await remoteInstallOrchestrator.installSkill(
                skill,
                to: provider,
                installer: installer,
                remoteBaseURL: currentRemoteBaseURL()
            )
        }
    }
    
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        await performAsync {
            try await remoteInstallOrchestrator.installWorkflow(
                workflow,
                to: provider,
                installer: installer,
                remoteBaseURL: currentRemoteBaseURL()
            )
        }
    }
    
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        await performAsync {
            try await remoteInstallOrchestrator.installMCP(
                mcp,
                to: provider,
                remoteBaseURL: currentRemoteBaseURL()
            )
        }
    }

    private func currentRemoteBaseURL() -> String {
        settings.remoteRepositories.first { $0.templateType == .clawdhub }?.baseURL
            ?? RepositoryTemplate.clawdhub.createRepository().baseURL
    }

    private func modelsCacheURLs(for provider: Provider) -> [URL] {
        var urls: [URL] = []
        let providerSkillsFolder = STFolder(provider.defaultSkillsPath)
        let providerHome = STFolder(providerSkillsFolder.url.deletingLastPathComponent())
        let providerCache = STFile(providerHome.url.appendingPathComponent("models_cache.json"))
        urls.append(providerCache.url)

        let userCodexHome = STFolder("\(NSHomeDirectory())/.codex")
        let userCache = STFile(userCodexHome.url.appendingPathComponent("models_cache.json"))
        if userCache.url.path != providerCache.url.path {
            urls.append(userCache.url)
        }
        return urls
    }

    private func loadVisibleModelSlugs(_ cacheURL: URL) -> [String] {
        let cacheFile = STFile(cacheURL)
        guard cacheFile.isExists,
              let data = try? Data(contentsOf: cacheFile.url),
              let cache = try? JSONDecoder().decode(CodexModelsCacheLite.self, from: data)
        else {
            return []
        }

        var seen = Set<String>()
        var models: [String] = []
        for item in cache.models {
            guard !item.slug.isEmpty else { continue }
            if item.visibility?.lowercased() == "hide" { continue }
            if seen.insert(item.slug).inserted {
                models.append(item.slug)
            }
        }
        return models
    }

    private func loadCurrentConfiguredModel(for provider: Provider) -> String? {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId)
        else {
            return nil
        }

        let configPath = template.defaultMcpConfigPath
        let configFile = STFile(configPath)
        guard configPath.pathExtension.lowercased() == "toml",
              configFile.isExists,
              let data = try? Data(contentsOf: configFile.url),
              !data.isEmpty,
              let config = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data)
        else {
            return nil
        }

        let trimmed = config.model?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

private struct CodexModelsCacheLite: Decodable {
    let models: [Model]

    struct Model: Decodable {
        let slug: String
        let visibility: String?
    }
}
