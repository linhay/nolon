import Combine
import Foundation
import SwiftUI

public enum SkillInstallationMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case symlink
    case copy

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .symlink: return NSLocalizedString("install_method.symlink", comment: "Symbolic Link")
        case .copy: return NSLocalizedString("install_method.copy", comment: "Copy")
        }
    }
}

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
        name: String, defaultSkillsPath: String, workflowPath: String, iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink, templateId: String? = nil
    ) {
        let provider = Provider(
            name: name,
            defaultSkillsPath: defaultSkillsPath,
            workflowPath: workflowPath,
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
        providers.remove(atOffsets: offsets)
    }

    public func moveProvider(from source: IndexSet, to destination: Int) {
        providers.move(fromOffsets: source, toOffset: destination)
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

    public func removeRemoteRepository(_ repository: RemoteRepository) {
        // Don't allow removing built-in repositories
        guard !repository.isBuiltIn else { return }
        remoteRepositories.removeAll { $0.id == repository.id }
    }

    // MARK: - Provider Accessors

    public func path(for provider: Provider) -> URL {
        URL(fileURLWithPath: provider.defaultSkillsPath)
    }

    public func method(for provider: Provider) -> SkillInstallationMethod {
        provider.installMethod
    }

    // MARK: - Persistence

    private var providersFileURL: URL {
        nolonManager.providersConfigURL
    }

    private func loadSettings() {
        // Load providers
        if FileManager.default.fileExists(atPath: providersFileURL.path),
           let data = try? Data(contentsOf: providersFileURL),
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
            guard let templateId = provider.templateId,
                  let template = ProviderTemplate(rawValue: templateId) else {
                continue
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
            try? encoded.write(to: providersFileURL)
        }
    }

    private func saveRemoteRepositories() {
        if let encoded = try? JSONEncoder().encode(remoteRepositories) {
            userDefaults.set(encoded, forKey: "remote_repositories")
        }
    }
}
