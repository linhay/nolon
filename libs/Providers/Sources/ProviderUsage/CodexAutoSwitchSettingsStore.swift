import Foundation
import ProviderCatalog

public final class CodexAutoSwitchSettingsStore: @unchecked Sendable {
    public static let shared = CodexAutoSwitchSettingsStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    public func settings(for provider: Provider) -> CodexAutoSwitchConfig {
        let key = storageKey(for: provider)
        guard let data = defaults.data(forKey: key),
              let settings = try? decoder.decode(CodexAutoSwitchConfig.self, from: data)
        else {
            return CodexAutoSwitchConfig()
        }
        return settings
    }

    public func update(settings: CodexAutoSwitchConfig, for provider: Provider) {
        let key = storageKey(for: provider)
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    private func storageKey(for provider: Provider) -> String {
        "nolon.codex.auto_switch.\(provider.id)"
    }
}
