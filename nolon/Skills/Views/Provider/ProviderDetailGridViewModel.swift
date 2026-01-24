import SwiftUI
import Observation
import STJSON

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
    
    // State
    var isLoading = false
    var errorMessage: String?
    var searchText: String = ""
    
    // Internals
    private var repository: SkillRepository
    private var installer: SkillInstaller
    
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
        
        // Load skills
        do {
            let allSkills = try repository.listSkills()
            let states = try installer.scanProvider(provider: provider)
            let installedIds = Set(states.filter { $0.state == .installed }.map(\.skillName))
            installedSkills = allSkills.filter { installedIds.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        // Load workflows
        loadWorkflows(for: provider)
        
        // Load MCPs
        loadMCPs(for: provider)
        
        isLoading = false
    }
    
    // MARK: - Filtered Data
    
    var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return installedSkills }
        return installedSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchText) ||
            skill.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredWorkflows: [WorkflowInfo] {
        guard !searchText.isEmpty else { return workflows }
        return workflows.filter { workflow in
            workflow.name.localizedCaseInsensitiveContains(searchText) ||
            workflow.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredMcps: [MCP] {
        guard !searchText.isEmpty else { return mcps }
        return mcps.filter { mcp in
            mcp.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func loadMCPs(for provider: Provider) {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            mcps = []
            return
        }
        
        let configPath = template.defaultMcpConfigPath
        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
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
    
    func updateMCP(_ mcp: MCP?, for provider: Provider) async {
        guard let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId) else {
            return
        }
        
        let configPath = template.defaultMcpConfigPath
        
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
        
        // 5. Reload
        loadMCPs(for: provider)
    }
    
    func deleteMCP(named name: String, for provider: Provider) async {
         guard let templateId = provider.templateId,
               let template = ProviderTemplate(rawValue: templateId) else {
             return
         }
         
         let configPath = template.defaultMcpConfigPath
         guard let data = try? Data(contentsOf: configPath),
               var json = try? JSON(data: data) else { return }
         
         var servers = json["mcpServers"].dictionaryValue
         servers[name] = nil
         json["mcpServers"] = JSON(servers)
         
         if let str = json.rawString() {
             try? str.write(to: configPath, atomically: true, encoding: .utf8)
         }
         
         loadMCPs(for: provider)
    }
    
    private func loadWorkflows(for provider: Provider) {
        let workflowPath = provider.workflowPath
        let url = URL(fileURLWithPath: workflowPath)
        
        guard FileManager.default.fileExists(atPath: workflowPath) else {
            workflows = []
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
            
            workflowIds = Set(workflows.map(\.id))
        } catch {
            workflows = []
        }
    }
    
    // MARK: - Actions
    
    func revealSkillInFinder(_ skill: Skill) {
        guard let provider = provider else { return }
        let path = (provider.skillsPath as NSString).appendingPathComponent(skill.id)
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    
    func uninstallSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        do {
            try installer.uninstall(skill: skill, from: provider)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
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
}
