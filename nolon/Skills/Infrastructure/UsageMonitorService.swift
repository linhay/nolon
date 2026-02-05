import Foundation
import ProviderUsage
import CodexBarProviderCatalog

actor UsageMonitorService {
    private let monitor: ProviderUsageMonitorService

    init() {
        let store = FileTokenAccountStore(fileURL: Self.defaultTokenAccountsFileURL())
        self.monitor = ProviderUsageMonitorService(tokenAccountStore: store)
    }

    func fetchOutcomes(provider: UsageProvider, settings: UsageMonitorProviderSettings) async -> [ProviderAccountUsageOutcome] {
        await monitor.fetchOutcomes(provider: provider, settings: settings)
    }

    static func defaultTokenAccountsFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Nolon", isDirectory: true)
            .appendingPathComponent("token-accounts.json")
    }
}
