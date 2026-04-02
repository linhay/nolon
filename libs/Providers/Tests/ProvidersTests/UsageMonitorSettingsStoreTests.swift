import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("UsageMonitorSettingsStore")
@MainActor
struct UsageMonitorSettingsStoreTests {
    @Test("Migrates legacy id-scoped usage settings to template-scoped key for original vendors")
    func migratesLegacyIDScopedSettingsToTemplateScopedKey() throws {
        let suite = "usage-monitor-settings-store-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UsageMonitorSettingsStore(defaults: defaults)
        let legacyProviderID = "981B5574-13FC-442C-A775-0AD5F158F3A4"
        let provider = Provider(
            id: ProviderTemplate.codexXcode.stableProviderUUID,
            kind: .vendor,
            name: "Codex (Xcode)",
            defaultSkillsPath: "/tmp/codex-xcode/skills",
            workflowPath: "/tmp/codex-xcode/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codexXcode.rawValue
        )

        let legacyKey = "nolon.usage.settings.\(legacyProviderID)"
        let scopedKey = "nolon.usage.settings.template.\(ProviderTemplate.codexXcode.rawValue)"
        let legacySettings = ProviderUsageMonitorSettings(codexAccountGroupingOptionRawValue: "customSQLiteGroup")
        let legacyData = try JSONEncoder().encode(legacySettings)
        defaults.set(legacyData, forKey: legacyKey)

        let loaded = store.settings(for: provider)

        #expect(loaded.codexAccountGroupingOptionRawValue == "customSQLiteGroup")
        #expect(defaults.data(forKey: scopedKey) != nil)
        #expect(defaults.object(forKey: legacyKey) == nil)
    }

    @Test("Migrates legacy id-scoped multi-account flag to template-scoped key for original vendors")
    func migratesLegacyIDScopedMultiAccountFlagToTemplateScopedKey() throws {
        let suite = "usage-monitor-multi-account-store-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UsageMonitorSettingsStore(defaults: defaults)
        let legacyProviderID = "981B5574-13FC-442C-A775-0AD5F158F3A4"
        let provider = Provider(
            id: ProviderTemplate.codexXcode.stableProviderUUID,
            kind: .vendor,
            name: "Codex (Xcode)",
            defaultSkillsPath: "/tmp/codex-xcode/skills",
            workflowPath: "/tmp/codex-xcode/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codexXcode.rawValue
        )

        let legacyKey = "nolon.usage.multi_accounts.\(legacyProviderID)"
        let scopedKey = "nolon.usage.multi_accounts.template.\(ProviderTemplate.codexXcode.rawValue)"
        defaults.set(true, forKey: legacyKey)

        let enabled = store.isMultiAccountEnabled(for: provider)

        #expect(enabled == true)
        #expect(defaults.object(forKey: scopedKey) as? Bool == true)
        #expect(defaults.object(forKey: legacyKey) == nil)
    }
}
