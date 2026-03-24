import Foundation
import STFilePath
import Testing
import ProviderCatalog
@testable import NolonResourceKit

@Suite("ProviderSettings")
@MainActor
struct ProviderSettingsTests {
    @Test("ProviderSettings exposes STFolder path view while keeping URL compatibility")
    func providerPathViews() throws {
        let root = STFolder("/tmp").folder("provider-settings-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let defaultsSuite = "provider-settings-tests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsSuite)!
        userDefaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            userDefaults.removePersistentDomain(forName: defaultsSuite)
        }

        let manager = NolonManager(rootURL: root.url)
        let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)

        let provider = Provider(
            kind: .project,
            name: "Custom",
            defaultSkillsPath: "/tmp/custom-provider/skills",
            workflowPath: "/tmp/custom-provider/workflows"
        )
        settings.providers = [provider]

        let folder = settings.pathFolder(for: provider)
        let url = settings.path(for: provider)
        #expect(folder.url.standardizedFileURL.path == "/tmp/custom-provider/skills")
        #expect(url.standardizedFileURL.path == folder.url.standardizedFileURL.path)
    }

    @Test("ProviderSettings migrates legacy clawdhub base URL to clawhub.ai")
    func migratesLegacyClawdhubBaseURL() throws {
        let root = STFolder("/tmp").folder("provider-settings-migrate-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let defaultsSuite = "provider-settings-migrate-tests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsSuite)!
        userDefaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            userDefaults.removePersistentDomain(forName: defaultsSuite)
        }

        var legacyClawdhub = RemoteRepository.clawdhub
        legacyClawdhub.baseURL = "https://clawdhub.com"
        let encoded = try JSONEncoder().encode([legacyClawdhub])
        userDefaults.set(encoded, forKey: "remote_repositories")

        let manager = NolonManager(rootURL: root.url)
        let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)

        let clawdhub = try #require(settings.remoteRepositories.first(where: { $0.templateType == .clawdhub }))
        #expect(clawdhub.baseURL == "https://clawhub.ai")

        let storedData = try #require(userDefaults.data(forKey: "remote_repositories"))
        let storedRepos = try JSONDecoder().decode([RemoteRepository].self, from: storedData)
        let storedClawdhub = try #require(storedRepos.first(where: { $0.templateType == .clawdhub }))
        #expect(storedClawdhub.baseURL == "https://clawhub.ai")
    }

    @Test("ProviderSettings migrates git skills paths from file path to directory path")
    func migratesGitSkillsPaths() throws {
        let root = STFolder("/tmp").folder("provider-settings-git-skills-path-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let defaultsSuite = "provider-settings-git-skills-path-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsSuite)!
        userDefaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            userDefaults.removePersistentDomain(forName: defaultsSuite)
        }

        let gitRepo = RemoteRepository(
            name: "axure-skill-group",
            templateType: .git,
            gitURL: "https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group.git",
            provider: .gitlab,
            skillsPaths: ["axure-skill/SKILL.md", "tree/main/skills"]
        )
        let encoded = try JSONEncoder().encode([gitRepo])
        userDefaults.set(encoded, forKey: "remote_repositories")

        let manager = NolonManager(rootURL: root.url)
        let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)
        let migrated = try #require(settings.remoteRepositories.first(where: { $0.id == gitRepo.id }))
        #expect(migrated.skillsPaths == ["axure-skill", "skills"])

        let storedData = try #require(userDefaults.data(forKey: "remote_repositories"))
        let storedRepos = try JSONDecoder().decode([RemoteRepository].self, from: storedData)
        let storedRepo = try #require(storedRepos.first(where: { $0.id == gitRepo.id }))
        #expect(storedRepo.skillsPaths == ["axure-skill", "skills"])
    }

    @Test("ProviderSettings syncs missing vendor category from template defaults")
    func syncsMissingVendorCategoryFromTemplates() throws {
        let root = STFolder("/tmp").folder("provider-settings-vendor-category-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let defaultsSuite = "provider-settings-vendor-category-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsSuite)!
        userDefaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            userDefaults.removePersistentDomain(forName: defaultsSuite)
        }

        let manager = NolonManager(rootURL: root.url)
        let legacyProvider = Provider(
            id: "codex-provider",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/legacy/codex/skills",
            workflowPath: "/tmp/legacy/codex/prompts",
            iconName: "terminal",
            installMethod: .symlink,
            templateId: ProviderTemplate.codex.rawValue
        )
        let data = try JSONEncoder().encode([legacyProvider])
        _ = try manager.providersConfigFile.overlay(with: data)

        let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)
        let provider = try #require(settings.providers.first)
        #expect(provider.vendorCategory == .original)
        #expect(provider.defaultSkillsPath.hasSuffix(".codex/skills"))
    }
}
