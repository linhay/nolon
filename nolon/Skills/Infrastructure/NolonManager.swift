import Foundation
import STFilePath

/// Central manager for .nolon directory structure
public final class NolonManager: Sendable {
    public nonisolated static let shared = NolonManager()
    
    // MARK: - Paths
    public nonisolated let rootURL: URL
    public nonisolated let skillsURL: URL
    public nonisolated let generatedWorkflowsURL: URL
    public nonisolated let userWorkflowsURL: URL
    public nonisolated let repositoriesURL: URL
    public nonisolated let providersConfigURL: URL
    public nonisolated let mcpsURL: URL
    public nonisolated let mcpsWorkflowsURL: URL
    
    // MARK: - Path Strings
    public nonisolated var rootPath: String { rootURL.path }
    public nonisolated var skillsPath: String { skillsURL.path }
    public nonisolated var generatedWorkflowsPath: String { generatedWorkflowsURL.path }
    public nonisolated var userWorkflowsPath: String { userWorkflowsURL.path }
    public nonisolated var repositoriesPath: String { repositoriesURL.path }
    public nonisolated var providersConfigPath: String { providersConfigURL.path }
    public nonisolated var mcpsPath: String { mcpsURL.path }
    public nonisolated var mcpsWorkflowsPath: String { mcpsWorkflowsURL.path }
    
    public init(rootURL: URL? = nil) {
        let rootFolder: STFolder
        if let rootURL {
            rootFolder = STFolder(rootURL)
        } else {
            rootFolder = STFolder("~").folder(".nolon")
        }
        
        self.rootURL = rootFolder.url
        self.skillsURL = rootFolder.folder("skills").url
        self.generatedWorkflowsURL = rootFolder.folder("skills-workflows").url
        self.userWorkflowsURL = rootFolder.folder("workflows").url
        self.repositoriesURL = rootFolder.folder("repositories").url
        self.providersConfigURL = rootFolder.file("providers.json").url
        self.mcpsURL = rootFolder.folder("mcps").url
        self.mcpsWorkflowsURL = rootFolder.folder("mcps-workflows").url
        
        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        let folders: [STFolder] = [
            STFolder(rootURL),
            STFolder(skillsURL),
            STFolder(generatedWorkflowsURL),
            STFolder(userWorkflowsURL),
            STFolder(repositoriesURL),
            STFolder(mcpsURL),
            STFolder(mcpsWorkflowsURL),
        ]

        folders.forEach { $0.createIfNotExists() }
    }
}
