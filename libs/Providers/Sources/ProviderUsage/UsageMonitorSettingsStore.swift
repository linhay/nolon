import Foundation
import ProviderCatalog

@MainActor
public final class UsageMonitorSettingsStore {
    public static let shared = UsageMonitorSettingsStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func settings(for provider: Provider) -> UsageMonitorProviderSettings {
        let key = storageKey(for: provider)
        if let settings = decodeSettings(forKey: key) {
            return settings
        }

        for legacyKey in legacyStorageKeys(for: provider) {
            guard let settings = decodeSettings(forKey: legacyKey) else { continue }
            if let data = defaults.data(forKey: legacyKey) {
                defaults.set(data, forKey: key)
            }
            defaults.removeObject(forKey: legacyKey)
            return settings
        }

        return .init()
    }

    public func update(settings: UsageMonitorProviderSettings, for provider: Provider) {
        let key = storageKey(for: provider)
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func isMultiAccountEnabled(for provider: Provider) -> Bool {
        let key = multiAccountKey(for: provider)
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }

        for legacyKey in legacyMultiAccountKeys(for: provider) {
            guard defaults.object(forKey: legacyKey) != nil else { continue }
            let enabled = defaults.bool(forKey: legacyKey)
            defaults.set(enabled, forKey: key)
            defaults.removeObject(forKey: legacyKey)
            return enabled
        }

        return false
    }

    public func setMultiAccountEnabled(_ enabled: Bool, for provider: Provider) {
        defaults.set(enabled, forKey: multiAccountKey(for: provider))
    }

    private func storageKey(for provider: Provider) -> String {
        if let templateScoped = templateScopedSettingsKey(for: provider) {
            return templateScoped
        }
        return "nolon.usage.settings.\(provider.id)"
    }

    private func multiAccountKey(for provider: Provider) -> String {
        if let templateScoped = templateScopedMultiAccountKey(for: provider) {
            return templateScoped
        }
        return "nolon.usage.multi_accounts.\(provider.id)"
    }

    private func decodeSettings(forKey key: String) -> UsageMonitorProviderSettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(UsageMonitorProviderSettings.self, from: data)
    }

    private func legacyStorageKeys(for provider: Provider) -> [String] {
        guard let templateId = provider.templateId,
              provider.kind == .vendor,
              provider.vendorCategory == .original
        else {
            return []
        }

        var keys: [String] = []
        keys.append("nolon.usage.settings.\(provider.id)")
        for legacyID in legacyProviderIDs(forTemplateID: templateId) where legacyID != provider.id {
            keys.append("nolon.usage.settings.\(legacyID)")
        }
        return keys
    }

    private func legacyMultiAccountKeys(for provider: Provider) -> [String] {
        guard let templateId = provider.templateId,
              provider.kind == .vendor,
              provider.vendorCategory == .original
        else {
            return []
        }

        var keys: [String] = []
        keys.append("nolon.usage.multi_accounts.\(provider.id)")
        for legacyID in legacyProviderIDs(forTemplateID: templateId) where legacyID != provider.id {
            keys.append("nolon.usage.multi_accounts.\(legacyID)")
        }
        return keys
    }

    private func templateScopedSettingsKey(for provider: Provider) -> String? {
        guard let templateId = provider.templateId,
              provider.kind == .vendor,
              provider.vendorCategory == .original
        else {
            return nil
        }
        return "nolon.usage.settings.template.\(templateId)"
    }

    private func templateScopedMultiAccountKey(for provider: Provider) -> String? {
        guard let templateId = provider.templateId,
              provider.kind == .vendor,
              provider.vendorCategory == .original
        else {
            return nil
        }
        return "nolon.usage.multi_accounts.template.\(templateId)"
    }

    private func legacyProviderIDs(forTemplateID templateId: String) -> [String] {
        switch templateId {
        case ProviderTemplate.codex.rawValue:
            return ["E7D873DA-5E19-44D2-A389-E995A4C0A223"]
        case ProviderTemplate.codexXcode.rawValue:
            return ["981B5574-13FC-442C-A775-0AD5F158F3A4"]
        default:
            return []
        }
    }
}
