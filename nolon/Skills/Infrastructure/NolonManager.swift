import Foundation

/// Central manager for .nolon directory structure
public final class NolonManager: Sendable {
    public static let shared = NolonManager()
    
    public let fileManager: FileManager
    
    // MARK: - Paths
    public let rootURL: URL
    public let skillsURL: URL
    public let skillsWorkflowsURL: URL
    public let userWorkflowsURL: URL
    public let mcpWorkflowsURL: URL
    public let repositoriesURL: URL
    public let providersConfigURL: URL
    
    // MARK: - Path Strings
    public var rootPath: String { rootURL.path }
    public var skillsPath: String { skillsURL.path }
    public var skillsWorkflowsPath: String { skillsWorkflowsURL.path }
    public var userWorkflowsPath: String { userWorkflowsURL.path }
    public var mcpWorkflowsPath: String { mcpWorkflowsURL.path }
    public var repositoriesPath: String { repositoriesURL.path }
    public var providersConfigPath: String { providersConfigURL.path }
    
    public init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        
        if let rootURL = rootURL {
            self.rootURL = rootURL
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            self.rootURL = home.appendingPathComponent(".nolon")
        }
        
        self.skillsURL = self.rootURL.appendingPathComponent("skills")
        self.skillsWorkflowsURL = self.rootURL.appendingPathComponent("skills-workflows")
        self.userWorkflowsURL = self.rootURL.appendingPathComponent("workflows")
        self.mcpWorkflowsURL = self.rootURL.appendingPathComponent("mcp-workflows")
        self.repositoriesURL = self.rootURL.appendingPathComponent("repositories")
        self.providersConfigURL = self.rootURL.appendingPathComponent("providers.json")
        
        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        // Skip directory creation in Previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        let directories = [
            rootURL,
            skillsURL,
            skillsWorkflowsURL,
            userWorkflowsURL,
            mcpWorkflowsURL,
            repositoriesURL
        ]
        
        for dir in directories {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
