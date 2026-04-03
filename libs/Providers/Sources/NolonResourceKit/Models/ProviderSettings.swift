import Foundation
import Observation
import STFilePath
import ProviderCatalog
import OSLog

@MainActor
@Observable
public class ProviderSettings {
    public static let shared = ProviderSettings()
    private static let logger = Logger(subsystem: "com.nolon", category: "ProviderSettings")
    
    private let userDefaults: UserDefaults
    private let nolonManager: NolonManager

    public var providers: [Provider] = [] {
        didSet { saveProviders() }
    }

    public var remoteRepositories: [RemoteRepository] = [] {
        didSet { saveRemoteRepositories() }
    }
    
    /// URL to import from nolon:// scheme
    public var pendingImportURL: String?


    public init(userDefaults: UserDefaults = .standard, nolonManager: NolonManager = .shared) {
        self.userDefaults = userDefaults
        self.nolonManager = nolonManager
        loadSettings()
    }

    // MARK: - Provider Management

    /// Backward-compatible path accessors used by legacy callers/tests.
    /// Prefer reading `provider.defaultSkillsPath` directly in new code.
    public func pathFolder(for provider: Provider) -> STFolder {
        STFolder(provider.defaultSkillsPath)
    }

    /// Backward-compatible URL accessor for provider skills root.
    public func path(for provider: Provider) -> URL {
        pathFolder(for: provider).url
    }

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
            repos = migrateRemoteRepositories(repos)
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

        if let clawhubRepo = remoteRepositories.first(where: { $0.templateType == .clawdhub }) {
            Self.logger.info(
                "Loaded clawhub repository config. id=\(clawhubRepo.id, privacy: .public) baseURL=\(clawhubRepo.baseURL, privacy: .public)"
            )
        }
        
        // Sync with templates to ensure new fields (like additionalSkillsPaths) are populated
        syncWithTemplates()
    }

    private func migrateRemoteRepositories(_ repositories: [RemoteRepository]) -> [RemoteRepository] {
        var migratedCount = 0
        let migrated = repositories.map { repository in
            var updated = repository
            if repository.templateType == .clawdhub {
                let expectedBaseURL = RepositoryTemplate.clawdhub.defaultBaseURL
                if updated.baseURL != expectedBaseURL {
                    updated.baseURL = expectedBaseURL
                    migratedCount += 1
                }

                let expectedLogoName = RepositoryTemplate.clawdhub.logoName
                if updated.logoName != expectedLogoName {
                    updated.logoName = expectedLogoName
                    migratedCount += 1
                }
            }

            if repository.templateType == .git, !repository.skillsPaths.isEmpty {
                let normalizedSkillsPaths = Self.normalizedSkillsPaths(repository.skillsPaths)
                if normalizedSkillsPaths != repository.skillsPaths {
                    updated.skillsPaths = normalizedSkillsPaths
                    migratedCount += 1
                }
            }

            return updated
        }
        if migratedCount > 0 {
            Self.logger.info("Migrated remote repository config fields. changes=\(migratedCount, privacy: .public)")
        }
        return migrated
    }

    private static func normalizedSkillsPaths(_ rawPaths: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        for raw in rawPaths {
            let normalized = SkillsRepositoryFacade.normalizeSkillsPath(raw) ?? raw
            if seen.insert(normalized).inserted {
                results.append(normalized)
            }
        }
        return results
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
            if expected.vendorCategory == .original,
               updatedProviders[index].id != expected.id
            {
                let current = updatedProviders[index]
                updatedProviders[index] = Provider(
                    id: expected.id,
                    kind: current.kind,
                    name: current.name,
                    projectRootPath: current.projectRootPath,
                    defaultSkillsPath: current.defaultSkillsPath,
                    workflowPath: current.workflowPath,
                    commandPath: current.commandPath,
                    iconName: current.iconName,
                    installMethod: current.installMethod,
                    skillsLinkEnabled: current.skillsLinkEnabled,
                    mcpLinkEnabled: current.mcpLinkEnabled,
                    vendorCategory: expected.vendorCategory,
                    templateId: current.templateId,
                    additionalSkillsPaths: current.additionalSkillsPaths,
                    documentationURL: current.documentationURL
                )
                hasChanges = true
            }
            if updatedProviders[index].defaultSkillsPath != expected.defaultSkillsPath
                || updatedProviders[index].workflowPath != expected.workflowPath
                || updatedProviders[index].commandPath != expected.commandPath
                || updatedProviders[index].vendorCategory != expected.vendorCategory
                || updatedProviders[index].additionalSkillsPaths != expected.additionalSkillsPaths
                || updatedProviders[index].documentationURL != expected.documentationURL
            {
                updatedProviders[index].defaultSkillsPath = expected.defaultSkillsPath
                updatedProviders[index].workflowPath = expected.workflowPath
                updatedProviders[index].commandPath = expected.commandPath
                updatedProviders[index].vendorCategory = expected.vendorCategory
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
