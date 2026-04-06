import Foundation
import STFilePath
import ProvidersShared

/// Central manager for .nolon directory structure
public final class NolonManager: Sendable {
    public nonisolated static let shared = NolonManager()
    
    // MARK: - Paths
    public nonisolated let rootFolder: STFolder
    public nonisolated let skillsFolder: STFolder
    public nonisolated let generatedWorkflowsFolder: STFolder
    public nonisolated let userWorkflowsFolder: STFolder
    public nonisolated let repositoriesFolder: STFolder
    public nonisolated let providersConfigFile: STFile
    public nonisolated let mcpsFolder: STFolder
    public nonisolated let mcpsWorkflowsFolder: STFolder
    public nonisolated let agentsFolder: STFolder

    public nonisolated let rootURL: URL
    public nonisolated let skillsURL: URL
    public nonisolated let generatedWorkflowsURL: URL
    public nonisolated let userWorkflowsURL: URL
    public nonisolated let repositoriesURL: URL
    public nonisolated let providersConfigURL: URL
    public nonisolated let mcpsURL: URL
    public nonisolated let mcpsWorkflowsURL: URL
    public nonisolated let agentsURL: URL
    
    // MARK: - Path Strings
    public nonisolated var rootPath: String { rootURL.path }
    public nonisolated var skillsPath: String { skillsURL.path }
    public nonisolated var generatedWorkflowsPath: String { generatedWorkflowsURL.path }
    public nonisolated var userWorkflowsPath: String { userWorkflowsURL.path }
    public nonisolated var repositoriesPath: String { repositoriesURL.path }
    public nonisolated var providersConfigPath: String { providersConfigURL.path }
    public nonisolated var mcpsPath: String { mcpsURL.path }
    public nonisolated var mcpsWorkflowsPath: String { mcpsWorkflowsURL.path }
    public nonisolated var agentsPath: String { agentsURL.path }
    
    public init(
        rootURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userHomeURL: URL = STFolder(NSHomeDirectory()).url
    ) {
        let rootFolder: STFolder
        if let rootURL {
            rootFolder = STFolder(rootURL)
        } else {
            rootFolder = NolonHomeEnvironment.resolveNolonHomeFolder(
                environment: environment,
                userHomeURL: userHomeURL
            )
        }

        self.rootFolder = rootFolder
        self.skillsFolder = rootFolder.folder("skills")
        self.generatedWorkflowsFolder = rootFolder.folder("skills-workflows")
        self.userWorkflowsFolder = rootFolder.folder("workflows")
        self.repositoriesFolder = rootFolder.folder("repositories")
        self.providersConfigFile = rootFolder.file("providers.json")
        self.mcpsFolder = rootFolder.folder("mcps")
        self.mcpsWorkflowsFolder = rootFolder.folder("mcps-workflows")
        self.agentsFolder = rootFolder.folder("agents")

        self.rootURL = self.rootFolder.url
        self.skillsURL = self.skillsFolder.url
        self.generatedWorkflowsURL = self.generatedWorkflowsFolder.url
        self.userWorkflowsURL = self.userWorkflowsFolder.url
        self.repositoriesURL = self.repositoriesFolder.url
        self.providersConfigURL = self.providersConfigFile.url
        self.mcpsURL = self.mcpsFolder.url
        self.mcpsWorkflowsURL = self.mcpsWorkflowsFolder.url
        self.agentsURL = self.agentsFolder.url

        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        let folders: [STFolder] = [
            rootFolder,
            skillsFolder,
            generatedWorkflowsFolder,
            userWorkflowsFolder,
            repositoriesFolder,
            mcpsFolder,
            mcpsWorkflowsFolder,
            agentsFolder,
        ]

        folders.forEach { _ = $0.createIfNotExists() }
    }
}
