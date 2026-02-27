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
}
