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
    public let mcpsWorkflowsURL: URL
    
    // MARK: - Path Strings
    public var rootPath: String { rootURL.path }
    public var skillsPath: String { skillsURL.path }
    public var generatedWorkflowsPath: String { generatedWorkflowsURL.path }
    public var userWorkflowsPath: String { userWorkflowsURL.path }
    public var repositoriesPath: String { repositoriesURL.path }
    public var providersConfigPath: String { providersConfigURL.path }
    public var mcpsWorkflowsPath: String { mcpsWorkflowsURL.path }
    
    public init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        
        if let rootURL = rootURL {
            self.rootURL = rootURL
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            self.rootURL = home.appendingPathComponent(".nolon")
        }
        
        self.skillsURL = self.rootURL.appendingPathComponent("skills")
        self.generatedWorkflowsURL = self.rootURL.appendingPathComponent("skills-workflows")
        self.userWorkflowsURL = self.rootURL.appendingPathComponent("workflows")
        self.repositoriesURL = self.rootURL.appendingPathComponent("repositories")
        self.providersConfigURL = self.rootURL.appendingPathComponent("providers.json")
        self.mcpsWorkflowsURL = self.rootURL.appendingPathComponent("mcps-workflows")
        
        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        let directories = [
            rootURL,
            skillsURL,
            generatedWorkflowsURL,
            userWorkflowsURL,
            repositoriesURL,
            mcpsWorkflowsURL
        ]
        
        for dir in directories {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
