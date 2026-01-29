import Foundation
import STFilePath

/// Central manager for .nolon directory structure
public final class NolonManager: Sendable {
    public static let shared = NolonManager()
    
    // MARK: - Paths
    public let rootURL: URL
    public let skillsURL: URL
    public let generatedWorkflowsURL: URL
    public let userWorkflowsURL: URL
    public let repositoriesURL: URL
    public let providersConfigURL: URL
    public let mcpsURL: URL
    public let mcpsWorkflowsURL: URL
    
    // MARK: - Path Strings
    public var rootPath: String { rootURL.path }
    public var skillsPath: String { skillsURL.path }
    public var generatedWorkflowsPath: String { generatedWorkflowsURL.path }
    public var userWorkflowsPath: String { userWorkflowsURL.path }
    public var repositoriesPath: String { repositoriesURL.path }
    public var providersConfigPath: String { providersConfigURL.path }
    public var mcpsPath: String { mcpsURL.path }
    public var mcpsWorkflowsPath: String { mcpsWorkflowsURL.path }
    
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
