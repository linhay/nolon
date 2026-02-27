import SwiftUI
import ProviderCatalog
import MarkdownUI
import Observation
import STFilePath
import OSLog
import NolonResourceKit

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
    private static let logger = Logger(subsystem: "nolon", category: "SkillDetail")

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
        if STFile(skillMdURL).isExists {
            loadedFiles.append(SkillFile(name: "SKILL.md", url: skillMdURL, type: .markdown))
        }
        
        // 2. Scan subdirectory
        func scanSubdir(_ name: String) {
            let dirURL = rootURL.appendingPathComponent(name)
            let folder = STFolder(dirURL)
            guard let contents = try? folder.files() else { return }
            
            for file in contents {
                let url = file.url
                if url.lastPathComponent.hasPrefix(".") { continue }
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
            let paths = [provider.defaultSkillsPath] + (provider.additionalSkillsPaths ?? [])
            let exists = paths.contains { path in
                STPath("\(path)/\(skill.id)").isExists || STPath("\(path)/\(skill.id)").isSymbolicLink
            }
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
            Self.logger.error("Failed to toggle installation for \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Workflow Logic
    
    func checkWorkflowStatus(for provider: Provider) {
        let workflowPath = provider.workflowPath + "/" + skill.id + ".md"
        isWorkflowLinked = STFile(workflowPath).isExists
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
            Self.logger.error("Failed to create workflow for \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func deleteWorkflow(for provider: Provider) {
        do {
            try installer.uninstallWorkflow(skill: skill, from: provider)
        } catch {
            Self.logger.error("Failed to delete workflow for \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
