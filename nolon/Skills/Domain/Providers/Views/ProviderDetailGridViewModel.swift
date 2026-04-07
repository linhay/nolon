import SwiftUI
import AppKit
import ProviderCatalog
import Observation
import STJSON
import STFilePath
import NolonResourceKit
import NolonUIFoundation

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
    var workflows: [NolonUIFoundation.WorkflowInfo] = []
    var selectedWorkflowForDetail: NolonUIFoundation.WorkflowInfo?
    var workflowIds: Set<String> = []
    
    // Rules
    var rules: [NolonUIFoundation.RuleInfo] = []
    
    // AGENTS.md docs
    var agentsFiles: [NolonUIFoundation.AgentDocInfo] = []

    // MCPs
    var mcps: [MCP] = []
    var mcpWorkflowIds: Set<String> = []
    var mcpCacheStates: [String: McpCacheState] = [:]
    
    // State
    var isLoading = false
    var skillsErrorMessage: String?
    var workflowsErrorMessage: String?
    var rulesErrorMessage: String?
    var agentsErrorMessage: String?
    var mcpErrorMessage: String?
    var searchText: String = ""
    var showingRemoteBrowser: RemoteBrowserType? = nil
    var codexModelOptions: [String] = []
    var selectedCodexModel: String?
    var isSavingCodexModel = false
    var codexModelStatusMessage: String?
    var skillsLinkEnabled = false
    var mcpLinkEnabled = false
    var agentsLinkEnabled = false
    var isApplyingSkillsLink = false
    var showingSkillsLinkEnableConfirmation = false
    var skillsLinkBackupPath: String?
    
    enum RemoteBrowserType: Identifiable, Equatable {
        case skill, workflow, mcp
        
        var id: Self { self }
    }

    enum ResourceErrorScope: Sendable {
        case skills
        case workflows
        case rules
        case agents
        case mcp
    }
    
    // Internals
    var repository: SkillRepository
    var installer: SkillInstaller
    private let resourceService: ProviderResourceService
    private let mcpMaintenanceService = ProviderMCPMaintenanceService()
    private let remoteInstallOrchestrator = RemoteInstallOrchestrator()
    private let codexModelPreferenceService = CodexModelPreferenceService()
    private let skillSnapshotService = ProviderSkillSnapshotService()
    private let snapshotService = ProviderResourceSnapshotService()
    private let resourceViewMapper = ProviderResourceViewMapper()
    private let providerSkillsLinkService = ProviderSkillsLinkService()
    private let providerAgentsLinkService = ProviderAgentsLinkService()
    
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
        clearScopedErrors()
        guard let provider = provider else {
            installedSkills = []
            workflows = []
            rules = []
            agentsFiles = []
            mcps = []
            codexModelOptions = []
            selectedCodexModel = nil
            codexModelStatusMessage = nil
            skillsLinkEnabled = false
            mcpLinkEnabled = false
            agentsLinkEnabled = false
            showingSkillsLinkEnableConfirmation = false
            skillsLinkBackupPath = nil
            return
        }
        skillsLinkEnabled = provider.skillsLinkEnabled
        mcpLinkEnabled = provider.mcpLinkEnabled
        agentsLinkEnabled = provider.agentsLinkEnabled
        syncLinkedMcpProjectionIfNeeded(for: provider)
        
        isLoading = true
        
        do {
            installedSkills = try skillSnapshotService.load(provider: provider)
        } catch {
            installedSkills = []
            setError(error.localizedDescription, scope: .skills)
        }
        
        applyResourceSnapshot(for: provider)
        loadCodexBinaryModels(for: provider)
        
        isLoading = false
    }

    func requestSetSkillsLinkEnabled(_ enabled: Bool) async {
        guard let provider else { return }
        guard enabled != provider.skillsLinkEnabled else {
            skillsLinkEnabled = provider.skillsLinkEnabled
            return
        }

        if enabled {
            do {
                let preflight = try providerSkillsLinkService.preflightEnable(provider: provider)
                if preflight.requiresConfirmation {
                    skillsLinkEnabled = provider.skillsLinkEnabled
                    skillsLinkBackupPath = preflight.backupPath
                    showingSkillsLinkEnableConfirmation = true
                    return
                }
                await setSkillsLinkEnabled(true, backupExisting: false)
            } catch {
                skillsLinkEnabled = provider.skillsLinkEnabled
                setError(error.localizedDescription, scope: .skills)
            }
            return
        }

        await setSkillsLinkEnabled(false, backupExisting: false)
    }

    func cancelSkillsLinkEnableConfirmation() {
        showingSkillsLinkEnableConfirmation = false
        skillsLinkBackupPath = nil
        skillsLinkEnabled = provider?.skillsLinkEnabled ?? false
    }

    func confirmSkillsLinkEnable(backupExisting: Bool) async {
        showingSkillsLinkEnableConfirmation = false
        skillsLinkBackupPath = nil
        await setSkillsLinkEnabled(true, backupExisting: backupExisting)
    }

    func requestSetMcpLinkEnabled(_ enabled: Bool) async {
        guard var provider else { return }
        guard enabled != provider.mcpLinkEnabled else {
            mcpLinkEnabled = provider.mcpLinkEnabled
            return
        }
        provider.mcpLinkEnabled = enabled
        settings.updateProvider(provider)
        self.provider = provider
        mcpLinkEnabled = enabled
        syncLinkedMcpProjectionIfNeeded(for: provider)
        await loadData()
    }

    func requestSetAgentsLinkEnabled(_ enabled: Bool) async {
        guard var provider else { return }
        guard enabled != provider.agentsLinkEnabled else {
            agentsLinkEnabled = provider.agentsLinkEnabled
            return
        }
        do {
            if enabled {
                try providerAgentsLinkService.applyEnable(provider: provider)
            } else {
                try providerAgentsLinkService.applyDisable(provider: provider)
            }
            provider.agentsLinkEnabled = enabled
            settings.updateProvider(provider)
            self.provider = provider
            agentsLinkEnabled = enabled
            clearError(scope: .agents)
            await loadData()
        } catch {
            agentsLinkEnabled = provider.agentsLinkEnabled
            setError(error.localizedDescription, scope: .agents)
        }
    }

    private func setSkillsLinkEnabled(_ enabled: Bool, backupExisting: Bool) async {
        guard var provider else { return }
        isApplyingSkillsLink = true
        defer { isApplyingSkillsLink = false }

        do {
            if enabled {
                try providerSkillsLinkService.applyEnable(provider: provider, backupExisting: backupExisting)
            } else {
                try providerSkillsLinkService.applyDisable(provider: provider)
            }
            provider.skillsLinkEnabled = enabled
            settings.updateProvider(provider)
            self.provider = provider
            skillsLinkEnabled = enabled
            clearError(scope: .skills)
            await loadData()
        } catch {
            skillsLinkEnabled = provider.skillsLinkEnabled
            setError(error.localizedDescription, scope: .skills)
        }
    }

    private func applyResourceSnapshot(for provider: Provider) {
        let snapshot = snapshotService.load(provider: provider)
        let mapped = resourceViewMapper.map(snapshot: snapshot)
        workflows = mapped.workflows.map {
            let source: NolonUIFoundation.WorkflowSource
            switch $0.source {
            case .skill:
                source = .skill
            case .user:
                source = .user
            case .mcp:
                source = .mcp
            case .unknown:
                source = .unknown
            }
            return NolonUIFoundation.WorkflowInfo(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                path: $0.path,
                source: source
            )
        }
        workflowIds = Set(workflows.filter { $0.source == .skill }.map(\.id))
        mcpWorkflowIds = Set(workflows.filter { $0.source == .mcp }.map(\.id))

        rules = mapped.rules.map {
            NolonUIFoundation.RuleInfo(
                id: $0.id,
                name: $0.name,
                preview: $0.preview,
                relativePath: $0.relativePath,
                path: $0.path
            )
        }

        agentsFiles = mapped.agents.map { item in
            let kind: NolonUIFoundation.AgentDocKind
            switch item.kind {
            case .override:
                kind = .override
            case .base:
                kind = .base
            }
            return NolonUIFoundation.AgentDocInfo(
                id: item.path,
                fileName: item.fileName,
                path: item.path,
                preview: item.preview,
                kind: kind
            )
        }

        mcps = snapshot.mcps
        mcpCacheStates = snapshot.mcpCacheStates.reduce(into: [:]) { partialResult, item in
            partialResult[item.key] = McpCacheState(rawValue: item.value.rawValue) ?? .notMigrated
        }
    }

    var hasCodexBinarySupport: Bool {
        guard let templateId = provider?.templateId else { return false }
        return templateId == "codex" || templateId == "codexXcode"
    }

    func saveSelectedCodexModel(_ model: String?) async {
        guard let provider else { return }
        guard hasCodexBinarySupport else { return }
        guard codexModelPreferenceService.supports(provider: provider) else { return }

        isSavingCodexModel = true
        defer { isSavingCodexModel = false }

        do {
            let normalized = try await codexModelPreferenceService.saveSelectedModel(model, for: provider)
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
        guard hasCodexBinarySupport,
              codexModelPreferenceService.supports(provider: provider)
        else {
            codexModelOptions = []
            selectedCodexModel = nil
            codexModelStatusMessage = nil
            return
        }

        let configuredModel = codexModelPreferenceService.loadConfiguredModel(for: provider)
        selectedCodexModel = configuredModel

        var options = codexModelPreferenceService.loadVisibleModelSlugs(for: provider)
        var seen = Set(options)
        if let configuredModel, !configuredModel.isEmpty, seen.insert(configuredModel).inserted {
            options.insert(configuredModel, at: 0)
        }
        codexModelOptions = options
    }
    
    private let homeDirectory = NSHomeDirectory()

    private func syncLinkedMcpProjectionIfNeeded(for provider: Provider) {
        guard provider.mcpLinkEnabled else { return }
        guard
            let templateId = provider.templateId,
            let template = ProviderTemplate(rawValue: templateId),
            template.supportsNativeMcpConfig
        else {
            return
        }
        do {
            _ = try MCPConfigManager.syncAllCacheServersToProvider(for: template)
        } catch {
            setError(error.localizedDescription, scope: .mcp)
        }
    }

    func revealMcpConfigInFinder() {
        guard let provider else {
            NSWorkspace.shared.activateFileViewerSelecting([NolonManager.shared.mcpsURL])
            return
        }

        guard
            let templateId = provider.templateId,
            let template = ProviderTemplate(rawValue: templateId),
            template.supportsNativeMcpConfig
        else {
            NSWorkspace.shared.activateFileViewerSelecting([NolonManager.shared.mcpsURL])
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([template.defaultMcpConfigPath])
    }

    func revealAgentsFolderInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([NolonManager.shared.agentsURL])
    }
    
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
    
    var filteredWorkflows: [NolonUIFoundation.WorkflowInfo] {
        filtered(workflows, searchIn: \.name, \.description)
    }
    
    var filteredRules: [NolonUIFoundation.RuleInfo] {
        filtered(rules, searchIn: \.name, \.preview, \.relativePath)
    }
    
    var filteredAgentsFiles: [NolonUIFoundation.AgentDocInfo] {
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
    private func performAsync(scope: ResourceErrorScope, _ operation: () async throws -> Void) async {
        do {
            try await operation()
            clearError(scope: scope)
            await loadData()
        } catch {
            setError(error.localizedDescription, scope: scope)
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
        await performAsync(scope: .mcp) {
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
    
    // MARK: - Actions
    
    func revealSkillInFinder(_ skill: Skill) {
        guard let provider = provider else { return }
        let path = (provider.defaultSkillsPath as NSString).appendingPathComponent(skill.id)
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    func revealSkillsFolderInFinder() {
        guard let provider else { return }
        NSWorkspace.shared.selectFile(provider.defaultSkillsPath, inFileViewerRootedAtPath: "")
    }
    
    func uninstallSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        await performAsync(scope: .skills) {
            try installer.uninstall(skill: skill, from: provider)
        }
    }
    
    func linkSkillToWorkflow(_ skill: Skill) {
        guard let provider = provider else { return }
        
        do {
            try installer.installWorkflow(skill: skill, to: provider)
            clearError(scope: .workflows)
            applyResourceSnapshot(for: provider)
        } catch {
            setError(error.localizedDescription, scope: .workflows)
        }
    }
    
    func unlinkSkillFromWorkflow(_ skill: Skill) {
        guard let provider = provider else { return }
        
        do {
            try installer.uninstallWorkflow(skill: skill, from: provider)
            clearError(scope: .workflows)
            applyResourceSnapshot(for: provider)
        } catch {
            setError(error.localizedDescription, scope: .workflows)
        }
    }
    
    func linkMcpToWorkflow(_ mcp: MCP) {
        guard let provider = provider else { return }
        
        do {
            try installer.installMcpWorkflow(mcp: mcp, to: provider)
            clearError(scope: .mcp)
            applyResourceSnapshot(for: provider)
        } catch {
            setError(error.localizedDescription, scope: .mcp)
        }
    }
    
    func unlinkMcpFromWorkflow(_ mcp: MCP) {
        guard let provider = provider else { return }
        
        do {
            try installer.uninstallMcpWorkflow(mcp: mcp, from: provider)
            clearError(scope: .mcp)
            applyResourceSnapshot(for: provider)
        } catch {
            setError(error.localizedDescription, scope: .mcp)
        }
    }
    
    func migrateSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        await performAsync(scope: .skills) {
            _ = try installer.migrate(skillName: skill.id, from: provider, overwriteExisting: false)
        }
    }
    
    func revealWorkflowInFinder(_ workflow: NolonUIFoundation.WorkflowInfo) {
        NSWorkspace.shared.selectFile(workflow.path, inFileViewerRootedAtPath: "")
    }
    
    func revealRuleInFinder(_ rule: NolonUIFoundation.RuleInfo) {
        NSWorkspace.shared.selectFile(rule.path, inFileViewerRootedAtPath: "")
    }
    
    func deleteWorkflow(_ workflow: NolonUIFoundation.WorkflowInfo) async {
        guard let provider = provider else { return }
        do {
            try resourceService.deleteWorkflow(workflowID: workflow.id, provider: provider)
            clearError(scope: .workflows)
        } catch {
            setError(error.localizedDescription, scope: .workflows)
        }
        applyResourceSnapshot(for: provider)
    }
    
    func deleteRule(_ rule: NolonUIFoundation.RuleInfo) async {
        guard let provider else { return }
        do {
            try resourceService.deleteResource(atPath: rule.path)
            clearError(scope: .rules)
        } catch {
            setError(error.localizedDescription, scope: .rules)
        }
        applyResourceSnapshot(for: provider)
    }

    func revealAgentDocInFinder(_ doc: NolonUIFoundation.AgentDocInfo) {
        NSWorkspace.shared.selectFile(doc.path, inFileViewerRootedAtPath: "")
    }

    func deleteAgentDoc(_ doc: NolonUIFoundation.AgentDocInfo) async {
        guard let provider else { return }
        do {
            try resourceService.deleteResource(atPath: doc.path)
            clearError(scope: .agents)
        } catch {
            setError(error.localizedDescription, scope: .agents)
        }
        applyResourceSnapshot(for: provider)
    }

    func copyAgentDocToNolon(_ doc: NolonUIFoundation.AgentDocInfo) {
        guard provider != nil else { return }
        do {
            _ = try resourceService.copyAgentDocToNolon(atPath: doc.path)
            clearError(scope: .agents)
        } catch {
            setError(error.localizedDescription, scope: .agents)
        }
    }

    func moveAgentDocToNolon(_ doc: NolonUIFoundation.AgentDocInfo) {
        guard let provider else { return }
        do {
            _ = try resourceService.moveAgentDocToNolon(atPath: doc.path)
            clearError(scope: .agents)
        } catch {
            setError(error.localizedDescription, scope: .agents)
        }
        applyResourceSnapshot(for: provider)
    }

    func createAgentDocDraft() -> URL? {
        guard let provider else { return nil }
        guard supportsAgentDocsProvider(provider) else { return nil }
        do {
            let draftKind: ProviderResourceDraftKind
            if provider.templateId == "codex" || provider.templateId == "codexXcode" {
                let basePath = STPath(provider.codexAgentsFileURL)
                draftKind = basePath.isExists ? .agentOverride : .agentBase
            } else {
                draftKind = .agentBase
            }
            let targetURL = try resourceService.createDraft(provider: provider, kind: draftKind)
            clearError(scope: .agents)
            applyResourceSnapshot(for: provider)
            return targetURL
        } catch {
            setError(error.localizedDescription, scope: .agents)
            return nil
        }
    }

    func createRuleDraft() -> URL? {
        guard let provider else { return nil }
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else { return nil }

        do {
            let draftURL = try resourceService.createDraft(provider: provider, kind: .rule)
            clearError(scope: .rules)
            applyResourceSnapshot(for: provider)
            return draftURL
        } catch {
            setError(error.localizedDescription, scope: .rules)
            return nil
        }
    }

    private func supportsAgentDocsProvider(_ provider: Provider) -> Bool {
        guard let templateId = provider.templateId else { return false }
        return templateId == "codex"
            || templateId == "codexXcode"
            || templateId == "opencode"
            || templateId == "copilot"
    }
    
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        await performAsync(scope: .skills) {
            try await remoteInstallOrchestrator.installSkill(
                skill,
                to: provider,
                installer: installer,
                remoteBaseURL: currentRemoteBaseURL()
            )
        }
    }
    
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        await performAsync(scope: .workflows) {
            try await remoteInstallOrchestrator.installWorkflow(
                workflow,
                to: provider,
                installer: installer,
                remoteBaseURL: currentRemoteBaseURL()
            )
        }
    }
    
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        await performAsync(scope: .mcp) {
            try await remoteInstallOrchestrator.installMCP(
                mcp,
                to: provider,
                remoteBaseURL: currentRemoteBaseURL()
            )
        }
    }

    private func clearScopedErrors() {
        skillsErrorMessage = nil
        workflowsErrorMessage = nil
        rulesErrorMessage = nil
        agentsErrorMessage = nil
        mcpErrorMessage = nil
    }

    private func clearError(scope: ResourceErrorScope) {
        switch scope {
        case .skills:
            skillsErrorMessage = nil
        case .workflows:
            workflowsErrorMessage = nil
        case .rules:
            rulesErrorMessage = nil
        case .agents:
            agentsErrorMessage = nil
        case .mcp:
            mcpErrorMessage = nil
        }
    }

    private func setError(_ message: String, scope: ResourceErrorScope) {
        switch scope {
        case .skills:
            skillsErrorMessage = message
        case .workflows:
            workflowsErrorMessage = message
        case .rules:
            rulesErrorMessage = message
        case .agents:
            agentsErrorMessage = message
        case .mcp:
            mcpErrorMessage = message
        }
    }

    private func currentRemoteBaseURL() -> String {
        settings.remoteRepositories.first { $0.templateType == .clawdhub }?.baseURL
            ?? RepositoryTemplate.clawdhub.createRepository().baseURL
    }

}
