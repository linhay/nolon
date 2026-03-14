import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("CodexAutoSwitchSettingsStore")
@MainActor
struct CodexAutoSwitchSettingsStoreTests {
    @Test("persists auto switch config per provider")
    func persistsConfig() throws {
        let suiteName = "codex-auto-switch-settings-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let provider = Provider(
            id: "codex-provider",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let store = CodexAutoSwitchSettingsStore(userDefaults: userDefaults)
        let config = CodexAutoSwitchConfig(
            enabled: true,
            thresholdPercent: 15,
            minimumCandidateRemainingPercent: 30,
            skipRelayAccounts: false,
            cooldown: 1200
        )

        store.update(settings: config, for: provider)

        #expect(store.settings(for: provider) == config)
    }
}
