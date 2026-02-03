import Foundation
import ProviderUsage
import CodexBarProviderCatalog

actor UsageMonitorService {
    private let monitor: ProviderUsageMonitorService

    init() {
        let store = FileTokenAccountStore(fileURL: UsageTokenAccountStore.defaultFileURL())
        self.monitor = ProviderUsageMonitorService(tokenAccountStore: store)
    }

    func fetchOutcomes(provider: UsageProvider, settings: UsageMonitorProviderSettings) async -> [ProviderAccountUsageOutcome] {
        await monitor.fetchOutcomes(provider: provider, settings: settings)
    }
}

