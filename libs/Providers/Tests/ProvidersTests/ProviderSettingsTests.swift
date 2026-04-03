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

    @Test("ProviderSettings keeps original vendor provider IDs stable across fresh boots")
    func originalVendorProviderIDsAreStable() throws {
        let suiteA = "provider-settings-stable-ids-a-\(UUID().uuidString)"
        let suiteB = "provider-settings-stable-ids-b-\(UUID().uuidString)"
        let defaultsA = UserDefaults(suiteName: suiteA)!
        let defaultsB = UserDefaults(suiteName: suiteB)!
        defaultsA.removePersistentDomain(forName: suiteA)
        defaultsB.removePersistentDomain(forName: suiteB)
        defer {
            defaultsA.removePersistentDomain(forName: suiteA)
            defaultsB.removePersistentDomain(forName: suiteB)
        }

        let rootA = STFolder("/tmp").folder("provider-settings-stable-a-\(UUID().uuidString)")
        let rootB = STFolder("/tmp").folder("provider-settings-stable-b-\(UUID().uuidString)")
        _ = rootA.createIfNotExists()
        _ = rootB.createIfNotExists()
        defer {
            try? rootA.deleteIncludingBrokenSymlink()
            try? rootB.deleteIncludingBrokenSymlink()
        }

        let settingsA = ProviderSettings(userDefaults: defaultsA, nolonManager: NolonManager(rootURL: rootA.url))
        let settingsB = ProviderSettings(userDefaults: defaultsB, nolonManager: NolonManager(rootURL: rootB.url))

        let codexA = try #require(settingsA.providers.first(where: { $0.templateId == ProviderTemplate.codex.rawValue }))
        let codexB = try #require(settingsB.providers.first(where: { $0.templateId == ProviderTemplate.codex.rawValue }))
        #expect(codexA.id == codexB.id)
        #expect(codexA.id == ProviderTemplate.codex.stableProviderUUID)
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

    @Test("ProviderSettings migrates legacy original vendor id to template stable id")
    func migratesLegacyOriginalVendorID() throws {
        let root = STFolder("/tmp").folder("provider-settings-id-migration-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let suite = "provider-settings-id-migration-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suite)!
        userDefaults.removePersistentDomain(forName: suite)
        defer { userDefaults.removePersistentDomain(forName: suite) }

        let manager = NolonManager(rootURL: root.url)
        let legacy = Provider(
            id: "E7D873DA-5E19-44D2-A389-E995A4C0A223",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/legacy/codex/skills",
            workflowPath: "/tmp/legacy/codex/workflows",
            iconName: "terminal",
            installMethod: .symlink,
            skillsLinkEnabled: false,
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        _ = try manager.providersConfigFile.overlay(with: JSONEncoder().encode([legacy]))

        let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)
        let migrated = try #require(settings.providers.first(where: { $0.templateId == ProviderTemplate.codex.rawValue }))
        #expect(migrated.id == ProviderTemplate.codex.stableProviderUUID)
    }

    @Test("Provider defaults skills link switch to disabled when legacy config omits field")
    func providerLegacyConfigDefaultsSkillsLinkDisabled() throws {
        let root = STFolder("/tmp").folder("provider-settings-skills-link-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.deleteIncludingBrokenSymlink() }

        let defaultsSuite = "provider-settings-skills-link-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsSuite)!
        userDefaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            userDefaults.removePersistentDomain(forName: defaultsSuite)
        }

        let manager = NolonManager(rootURL: root.url)
        let legacyJSON = """
        [
          {
            "id": "legacy-provider",
            "kind": "project",
            "name": "Legacy Project",
            "defaultSkillsPath": "/tmp/legacy-project/skills",
            "workflowPath": "/tmp/legacy-project/workflows",
            "iconName": "folder",
            "installMethod": "symlink"
          }
        ]
        """
        _ = try manager.providersConfigFile.overlay(with: Data(legacyJSON.utf8))

        let settings = ProviderSettings(userDefaults: userDefaults, nolonManager: manager)
        let provider = try #require(settings.providers.first(where: { $0.id == "legacy-provider" }))
        #expect(provider.skillsLinkEnabled == false)
        #expect(provider.mcpLinkEnabled == false)
    }
}
