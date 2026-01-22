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
    @AppStorage("unified_providers") private var storedProvidersData: Data = Data()
    @AppStorage("remote_repositories") private var storedRemoteRepositoriesData: Data = Data()

    // Legacy storage keys for migration
    @AppStorage("provider_paths") private var legacyPathsData: Data = Data()
    @AppStorage("provider_methods") private var legacyMethodsData: Data = Data()
    @AppStorage("custom_providers") private var legacyCustomProvidersData: Data = Data()

    @Published public var providers: [Provider] = [] {
        didSet { saveProviders() }
    }

    @Published public var remoteRepositories: [RemoteRepository] = [] {
        didSet { saveRemoteRepositories() }
    }

    public init() {
        loadSettings()
    }

    // MARK: - Provider Management

    public func addProvider(_ provider: Provider) {
        providers.append(provider)
    }

    public func addProvider(
        name: String, path: String, iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink, templateId: String? = nil
    ) {
        let provider = Provider(
            name: name,
            path: path,
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
        URL(fileURLWithPath: provider.path)
    }

    public func method(for provider: Provider) -> SkillInstallationMethod {
        provider.installMethod
    }

    // MARK: - Persistence

    private func loadSettings() {
        // Load providers
        if let decodedProviders = try? JSONDecoder().decode(
            [Provider].self, from: storedProvidersData),
            !decodedProviders.isEmpty
        {
            self.providers = decodedProviders
        } else {
            // Migration from legacy format
            migrateFromLegacyFormat()
        }

        // Load remote repositories
        if let decodedRepos = try? JSONDecoder().decode(
            [RemoteRepository].self, from: storedRemoteRepositoriesData),
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
    }

    private func migrateFromLegacyFormat() {
        var migratedProviders: [Provider] = []

        // Migrate legacy built-in providers
        if let legacyPaths = try? JSONDecoder().decode([String: String].self, from: legacyPathsData)
        {
            let legacyMethods =
                (try? JSONDecoder().decode(
                    [String: SkillInstallationMethod].self, from: legacyMethodsData)) ?? [:]

            for template in ProviderTemplate.allCases {
                let path = legacyPaths[template.rawValue] ?? template.defaultPath.path
                let method = legacyMethods[template.rawValue] ?? .symlink

                let provider = Provider(
                    name: template.displayName,
                    path: path,
                    iconName: template.iconName,
                    installMethod: method,
                    templateId: template.rawValue
                )
                migratedProviders.append(provider)
            }
        } else {
            // No legacy data, create default providers from templates
            for template in ProviderTemplate.allCases {
                migratedProviders.append(template.createProvider())
            }
        }

        // Migrate legacy custom providers
        if let legacyCustom = try? JSONDecoder().decode(
            [LegacyCustomProvider].self, from: legacyCustomProvidersData)
        {
            for custom in legacyCustom {
                let provider = Provider(
                    id: custom.id,
                    name: custom.name,
                    path: custom.path,
                    iconName: custom.iconName,
                    installMethod: .symlink,
                    templateId: nil
                )
                migratedProviders.append(provider)
            }
        }

        self.providers = migratedProviders
        saveProviders()

        // Clear legacy data after migration
        legacyPathsData = Data()
        legacyMethodsData = Data()
        legacyCustomProvidersData = Data()
    }

    private func saveProviders() {
        if let encoded = try? JSONEncoder().encode(providers) {
            storedProvidersData = encoded
        }
    }

    private func saveRemoteRepositories() {
        if let encoded = try? JSONEncoder().encode(remoteRepositories) {
            storedRemoteRepositoriesData = encoded
        }
    }
}

// MARK: - Legacy Custom Provider for Migration

private struct LegacyCustomProvider: Codable {
    let id: String
    var name: String
    var path: String
    var iconName: String
}
