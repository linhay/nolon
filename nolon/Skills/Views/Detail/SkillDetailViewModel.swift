import SwiftUI
import MarkdownUI
import Observation

/// Model representing a file in the skill directory
struct SkillFile: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
    let type: SkillFileType
    
    enum SkillFileType {
        case markdown
        case code
        case image
        case other
    }
}

@MainActor
@Observable
final class SkillDetailViewModel {
    // MARK: - State
    var skill: Skill
    var files: [SkillFile] = []
    var selectedFile: SkillFile?
    
    // Provider ID -> Is Installed
    var providerInstallationStates: [String: Bool] = [:]
    
    // Current Provider Workflow State
    var isWorkflowLinked: Bool = false
    
    // MARK: - Dependencies
    private let repository = SkillRepository()
    private let installer: SkillInstaller
    
    init(skill: Skill, settings: ProviderSettings) {
        self.skill = skill
        self.installer = SkillInstaller(repository: repository, settings: settings)
    }
    
    // MARK: - Loading
    
    func loadData(checkProviders: [Provider], currentProvider: Provider?) async {
        loadFiles()
        await checkInstallationStatus(providers: checkProviders)
        if let provider = currentProvider {
            checkWorkflowStatus(for: provider)
        }
    }
    
    private func loadFiles() {
        let rootURL = URL(fileURLWithPath: skill.globalPath)
        var loadedFiles: [SkillFile] = []
        
        // 1. SKILL.md
        let skillMdURL = rootURL.appendingPathComponent("SKILL.md")
        if FileManager.default.fileExists(atPath: skillMdURL.path) {
            loadedFiles.append(SkillFile(name: "SKILL.md", url: skillMdURL, type: .markdown))
        }
        
        // 2. Scan subdirectory
        func scanSubdir(_ name: String) {
            let dirURL = rootURL.appendingPathComponent(name)
            guard let contents = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
            
            for url in contents {
                if url.hasDirectoryPath { continue }
                loadedFiles.append(SkillFile(name: "\(name)/\(url.lastPathComponent)", url: url, type: determineType(url)))
            }
        }
        
        scanSubdir("references")
        scanSubdir("scripts")
        
        self.files = loadedFiles
        if selectedFile == nil {
            selectedFile = loadedFiles.first
        }
    }
    
    private func determineType(_ url: URL) -> SkillFile.SkillFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return .markdown
        case "png", "jpg", "jpeg", "gif": return .image
        case "swift", "js", "py", "sh", "json", "yaml", "yml": return .code
        default: return .other
        }
    }
    
    // MARK: - Installation Logic
    
    func checkInstallationStatus(providers: [Provider]) async {
        // If reloading all (or just checking specific ones), we should probably merge or be careful.
        // But for loadData we want fresh.
        // Let's split this:
        // loadData -> reloadAll
        // toggle -> updateOne
        
        for provider in providers {
            let path = "\(provider.skillsPath)/\(skill.id)"
            let exists = FileManager.default.fileExists(atPath: path)
            providerInstallationStates[provider.id] = exists
        }
    }
    
    func toggleInstallation(for provider: Provider) async {
        let isInstalled = providerInstallationStates[provider.id] ?? false
        
        do {
            if isInstalled {
                try installer.uninstall(skill: skill, from: provider)
            } else {
                try installer.install(skill: skill, to: provider)
            }
            // Update state safely
            await checkInstallationStatus(providers: [provider])
        } catch {
            print("Failed to toggle installation for \(provider.name): \(error)")
        }
    }
    
    // MARK: - Workflow Logic
    
    func checkWorkflowStatus(for provider: Provider) {
        let workflowPath = provider.workflowPath + "/" + skill.id + ".md"
        isWorkflowLinked = FileManager.default.fileExists(atPath: workflowPath)
    }
    
    func toggleWorkflow(for provider: Provider) {
        if isWorkflowLinked {
            deleteWorkflow(for: provider)
        } else {
            createWorkflow(for: provider)
        }
        checkWorkflowStatus(for: provider)
    }
    
    private func createWorkflow(for provider: Provider) {
        do {
            try installer.installWorkflow(skill: skill, to: provider)
        } catch {
            print("Failed to create workflow: \(error)")
        }
    }
    
    private func deleteWorkflow(for provider: Provider) {
        do {
            try installer.uninstallWorkflow(skill: skill, from: provider)
        } catch {
            print("Failed to delete workflow: \(error)")
        }
    }
}
