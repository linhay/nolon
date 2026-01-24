import Foundation

/// Central manager for .nolon directory structure
public final class NolonManager: Sendable {
    public static let shared = NolonManager()
    
    public let fileManager: FileManager
    
    // MARK: - Paths
    public let rootURL: URL
    public let skillsURL: URL
    public let generatedWorkflowsURL: URL
    public let userWorkflowsURL: URL
    public let repositoriesURL: URL
    public let providersConfigURL: URL
    
    // MARK: - Path Strings
    public var rootPath: String { rootURL.path }
    public var skillsPath: String { skillsURL.path }
    public var generatedWorkflowsPath: String { generatedWorkflowsURL.path }
    public var userWorkflowsPath: String { userWorkflowsURL.path }
    public var repositoriesPath: String { repositoriesURL.path }
    public var providersConfigPath: String { providersConfigURL.path }
    
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let home = fileManager.homeDirectoryForCurrentUser
        
        self.rootURL = home.appendingPathComponent(".nolon")
        self.skillsURL = rootURL.appendingPathComponent("skills")
        self.generatedWorkflowsURL = rootURL.appendingPathComponent("skills-workflows")
        self.userWorkflowsURL = rootURL.appendingPathComponent("workflows")
        self.repositoriesURL = rootURL.appendingPathComponent("repositories")
        self.providersConfigURL = rootURL.appendingPathComponent("providers.json")
        
        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        let directories = [
            rootURL,
            skillsURL,
            generatedWorkflowsURL,
            userWorkflowsURL,
            repositoriesURL
        ]
        
        for dir in directories {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
