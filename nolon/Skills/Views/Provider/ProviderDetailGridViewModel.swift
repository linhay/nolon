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
    var showingRemoteBrowser = false
    
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
    
    var filteredSkills: [Skill] {
        let skills: [Skill]
        if searchText.isEmpty {
            skills = installedSkills
        } else {
            skills = installedSkills.filter { skill in
                skill.name.localizedCaseInsensitiveContains(searchText) ||
                skill.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort within each path, but we'll return a flat list if the view handles grouping,
        // OR better return a structured dictionary.
        // Given the request "support grouping by path", let's provide a grouped computed property.
        return skills
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
        let path = (provider.defaultSkillsPath as NSString).appendingPathComponent(skill.id)
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
    
    func unlinkSkillFromWorkflow(_ skill: Skill) {
        guard let provider = provider else { return }
        
        do {
            try installer.uninstallWorkflow(skill: skill, from: provider)
            loadWorkflows(for: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        
        do {
            _ = try installer.migrate(skillName: skill.id, from: provider, overwriteExisting: false)
            await loadData()
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
    
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        do {
            if let localPath = skill.localPath {
                try installer.installLocal(from: localPath, slug: skill.slug, to: provider)
            } else {
                let zipURL = try await ClawdhubService.shared.downloadSkill(
                    slug: skill.slug, version: skill.latestVersion?.version)
                try installer.installRemote(zipURL: zipURL, slug: skill.slug, to: provider)
            }
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
