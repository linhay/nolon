import Combine
import Foundation
import STFilePath
import ProviderCatalog

@MainActor
public class ProviderSettings: ObservableObject {
    public static let shared = ProviderSettings()
    
    private let userDefaults: UserDefaults
    private let nolonManager: NolonManager

    @Published public var providers: [Provider] = [] {
        didSet { saveProviders() }
    }

    @Published public var remoteRepositories: [RemoteRepository] = [] {
        didSet { saveRemoteRepositories() }
    }
    
    /// URL to import from nolon:// scheme
    @Published public var pendingImportURL: String?


    public init(userDefaults: UserDefaults = .standard, nolonManager: NolonManager = .shared) {
        self.userDefaults = userDefaults
        self.nolonManager = nolonManager
        loadSettings()
    }

    // MARK: - Provider Management

    public func addProvider(_ provider: Provider) {
        providers.append(provider)
    }

    public func addProvider(
        name: String,
        defaultSkillsPath: String,
        workflowPath: String,
        commandPath: String? = nil,
        iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink, templateId: String? = nil
    ) {
        let provider = Provider(
            name: name,
            defaultSkillsPath: defaultSkillsPath,
            workflowPath: workflowPath,
            commandPath: commandPath,
            iconName: iconName,
            installMethod: installMethod,
            templateId: templateId
        )
        providers.append(provider)
    }

    public func updateProvider(_ provider: Provider) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
        }
    }

    public func removeProvider(_ provider: Provider) {
        providers.removeAll { $0.id == provider.id }
    }

    public func removeProvider(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        providers = providers.enumerated().compactMap { index, provider in
            offsets.contains(index) ? nil : provider
        }
    }

    public func moveProvider(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else { return }
        var updated = providers

        let moving = source.sorted().map { updated[$0] }
        for index in source.sorted(by: >) {
            updated.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        let clampedDestination = max(0, min(adjustedDestination, updated.count))
        updated.insert(contentsOf: moving, at: clampedDestination)

        providers = updated
    }

    // MARK: - Remote Repository Management

    public func addRemoteRepository(_ repository: RemoteRepository) {
        remoteRepositories.append(repository)
    }

    public func updateRemoteRepository(_ repository: RemoteRepository) {
        if let index = remoteRepositories.firstIndex(where: { $0.id == repository.id }) {
            remoteRepositories[index] = repository
        }
    }

    public func upsertRemoteRepository(_ repository: RemoteRepository) {
        if remoteRepositories.contains(where: { $0.id == repository.id }) {
            updateRemoteRepository(repository)
        } else {
            addRemoteRepository(repository)
        }
    }

    public func removeRemoteRepository(_ repository: RemoteRepository) {
        // Don't allow removing built-in repositories
        guard !repository.isBuiltIn else { return }
        remoteRepositories.removeAll { $0.id == repository.id }
    }

    // MARK: - Provider Accessors

    public func path(for provider: Provider) -> URL {
        pathFolder(for: provider).url
    }

    public func pathFolder(for provider: Provider) -> STFolder {
        STFolder(provider.defaultSkillsPath)
    }

    public func method(for provider: Provider) -> SkillInstallationMethod {
        provider.installMethod
    }

    // MARK: - Persistence

    private var providersFile: STFile {
        nolonManager.providersConfigFile
    }

    private func loadSettings() {
        // Load providers
        if providersFile.isExists,
           let data = try? providersFile.data(),
           let decodedProviders = try? JSONDecoder().decode([Provider].self, from: data),
           !decodedProviders.isEmpty
        {
            self.providers = decodedProviders
        } else {
             loadDefaultProviders()
        }

        // Load remote repositories
        if let data = userDefaults.data(forKey: "remote_repositories"),
           let decodedRepos = try? JSONDecoder().decode(
            [RemoteRepository].self, from: data),
            !decodedRepos.isEmpty
        {
            var repos = decodedRepos
            // Ensure globalSkills is present
            if !repos.contains(where: { $0.templateType == .globalSkills }) {
                repos.insert(.globalSkills, at: 0)
            }
            // Ensure clawdhub is present
             if !repos.contains(where: { $0.templateType == .clawdhub }) {
                repos.insert(.clawdhub, at: 0)
            }
            
            // Keep built-in Clawdhub logo in sync with asset catalog name (clawhub.imageset)
            if let index = repos.firstIndex(where: { $0.templateType == .clawdhub }) {
                let desiredLogoName = RepositoryTemplate.clawdhub.logoName
                if repos[index].logoName != desiredLogoName {
                    repos[index].logoName = desiredLogoName
                }
            }
            self.remoteRepositories = repos
        } else {
            // Default with Global Skills and Clawdhub
            self.remoteRepositories = [.globalSkills, .clawdhub]
        }
        
        // Sync with templates to ensure new fields (like additionalSkillsPaths) are populated
        syncWithTemplates()
    }
    
    private func syncWithTemplates() {
        var hasChanges = false
        var updatedProviders = providers
        
        for (index, provider) in updatedProviders.enumerated() {
            guard provider.kind == .vendor else { continue }
            guard let templateId = provider.templateId,
                  let template = ProviderTemplate(rawValue: templateId) else {
                continue
            }

            // Keep vendor paths in sync with template (vendor paths are predefined and not user-editable).
            let expected = template.createProvider()
            if updatedProviders[index].defaultSkillsPath != expected.defaultSkillsPath
                || updatedProviders[index].workflowPath != expected.workflowPath
                || updatedProviders[index].commandPath != expected.commandPath
                || updatedProviders[index].additionalSkillsPaths != expected.additionalSkillsPaths
                || updatedProviders[index].documentationURL != expected.documentationURL
            {
                updatedProviders[index].defaultSkillsPath = expected.defaultSkillsPath
                updatedProviders[index].workflowPath = expected.workflowPath
                updatedProviders[index].commandPath = expected.commandPath
                updatedProviders[index].additionalSkillsPaths = expected.additionalSkillsPaths
                updatedProviders[index].documentationURL = expected.documentationURL
                hasChanges = true
            }

            // OpenCode migration: keep `commandPath` populated and `workflowPath` pointing to commands for legacy callers.
            if template.usesCommandFiles {
                let commandPath = provider.commandPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if commandPath.isEmpty {
                    updatedProviders[index].commandPath = provider.workflowPath
                    hasChanges = true
                } else if provider.workflowPath != commandPath {
                    updatedProviders[index].workflowPath = commandPath
                    hasChanges = true
                }
            }
            
            // Merge template paths with existing paths - ensure all template defaults are present
            let templatePaths = Set(template.defaultSkillsPaths.map { $0.path })
            guard !templatePaths.isEmpty else { continue }
            
            let currentPaths = Set(provider.additionalSkillsPaths ?? [])
            let missingPaths = templatePaths.subtracting(currentPaths)
            
            if !missingPaths.isEmpty {
                let mergedPaths = Array(currentPaths.union(templatePaths)).sorted()
                updatedProviders[index].additionalSkillsPaths = mergedPaths
                hasChanges = true
            }
        }
        
        if hasChanges {
            self.providers = updatedProviders
        }
    }

    private func loadDefaultProviders() {
        let defaults = ProviderTemplate.allCases.map { $0.createProvider() }
        self.providers = defaults
        saveProviders()
    }

    private func saveProviders() {
        if let encoded = try? JSONEncoder().encode(providers) {
            _ = try? providersFile.overlay(with: encoded)
        }
    }

    private func saveRemoteRepositories() {
        if let encoded = try? JSONEncoder().encode(remoteRepositories) {
            userDefaults.set(encoded, forKey: "remote_repositories")
        }
    }
}
