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

    private func storageKey(for provider: Provider) -> String {
        "nolon.usage.settings.\(provider.id)"
    }
}
