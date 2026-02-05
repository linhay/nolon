import Foundation
import ProviderCatalog
import ProviderUsage

@MainActor
final class UsageMonitorSettingsStore {
    static let shared = UsageMonitorSettingsStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func settings(for provider: Provider) -> UsageMonitorProviderSettings {
        let key = storageKey(for: provider)
        guard let data = defaults.data(forKey: key),
              let settings = try? decoder.decode(UsageMonitorProviderSettings.self, from: data)
        else {
            return .init()
        }
        return settings
    }

    func update(settings: UsageMonitorProviderSettings, for provider: Provider) {
        let key = storageKey(for: provider)
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    func isMultiAccountEnabled(for provider: Provider) -> Bool {
        defaults.bool(forKey: multiAccountKey(for: provider))
    }

    func setMultiAccountEnabled(_ enabled: Bool, for provider: Provider) {
        defaults.set(enabled, forKey: multiAccountKey(for: provider))
    }

    private func storageKey(for provider: Provider) -> String {
        "nolon.usage.settings.\(provider.id)"
    }

    private func multiAccountKey(for provider: Provider) -> String {
        "nolon.usage.multi_accounts.\(provider.id)"
    }
}
