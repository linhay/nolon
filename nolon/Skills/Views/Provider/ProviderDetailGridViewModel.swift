import SwiftUI
import Observation
import STJSON
import TOML

// MARK: - Codex MCP Config Models (shared)
struct CodexMCPConfig: Codable {
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
}

struct CodexProject: Codable {
    var trustLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case trustLevel = "trust_level"
    }
}

struct CodexNotice: Codable {
    var modelMigrations: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case modelMigrations = "model_migrations"
    }
}

struct CodexMCPServer: Codable {
    var url: String?
    var command: String?
    var args: [String]?
    var env: [String: String]?
    var enabled: Bool?
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
    
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    
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
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            mcps = []
            return
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
                .filter { _, server in server.enabled ?? true }
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
            if let servers = expandedJson["mcpServers"].dictionary {
                mcps = servers
                    .filter { key, value in
                        // Skip disabled servers
                        !(value["disabled"].bool ?? false)
                    }
                    .map { key, value in
                        MCP(name: key, json: AnyCodable(value.object))
                    }
                    .sorted { $0.name < $1.name }
            } else {
                mcps = []
            }
        }
    }
    
    private func loadMcpWorkflows() {
        let path = NolonManager.shared.mcpsWorkflowsPath
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            mcpWorkflowIds = []
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            mcpWorkflowIds = Set(contents
                .filter { $0.pathExtension == "md" }
                .map { $0.deletingPathExtension().lastPathComponent })
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
            guard FileManager.default.fileExists(atPath: configPath.path),
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
            if FileManager.default.fileExists(atPath: configPath.path),
               let data = try? Data(contentsOf: configPath),
               let fileJson = try? JSON(data: data) {
                json = fileJson
            } else {
                json = JSON([:])
            }
            
            // 2. Ensure mcpServers object exists
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
        let url = URL(fileURLWithPath: workflowPath)
        
        guard FileManager.default.fileExists(atPath: workflowPath) else {
            workflows = []
            mcpWorkflowIds = []
            workflowIds = []
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            workflows = contents
                .filter { $0.pathExtension == "md" }
                .compactMap { WorkflowInfo.parse(from: $0) }
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
            try? FileManager.default.removeItem(atPath: workflow.path)
        }
        
        loadWorkflows(for: provider)
    }
    
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        await performAsync {
            if let localPath = skill.localPath {
                try installer.installLocal(from: localPath, slug: skill.slug, to: provider)
            } else {
                let zipURL = try await ClawdhubService.shared.downloadSkill(
                    slug: skill.slug, version: skill.latestVersion?.version)
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
                let fileURL = try await ClawdhubService.shared.downloadWorkflow(
                    slug: workflow.slug,
                    version: workflow.latestVersion?.version
                )
                try installer.installRemoteWorkflow(fileURL: fileURL, slug: workflow.slug, to: provider)
            }
        }
    }
    
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        await performAsync {
            try installer.installRemoteMCP(mcp, to: provider)
        }
    }
}
