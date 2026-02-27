import Foundation
import ProviderCatalog

@MainActor
public final class UsageMonitorSettingsStore {
    public static let shared = UsageMonitorSettingsStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    public func settings(for provider: Provider) -> UsageMonitorProviderSettings {
        let key = storageKey(for: provider)
        guard let data = defaults.data(forKey: key),
              let settings = try? decoder.decode(UsageMonitorProviderSettings.self, from: data)
        else {
            return .init()
        }
        return settings
    }

    public func update(settings: UsageMonitorProviderSettings, for provider: Provider) {
        let key = storageKey(for: provider)
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func isMultiAccountEnabled(for provider: Provider) -> Bool {
        defaults.bool(forKey: multiAccountKey(for: provider))
    }

    public func setMultiAccountEnabled(_ enabled: Bool, for provider: Provider) {
        defaults.set(enabled, forKey: multiAccountKey(for: provider))
    }

    private func storageKey(for provider: Provider) -> String {
        "nolon.usage.settings.\(provider.id)"
    }

    private func multiAccountKey(for provider: Provider) -> String {
        "nolon.usage.multi_accounts.\(provider.id)"
    }
}
