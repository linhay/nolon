import Foundation
import ProviderUsage
import CodexBarProviderCatalog

actor UsageMonitorService {
    private let tokenStore: FileTokenAccountStore
    private let monitor: ProviderUsageMonitorService

    init() {
        self.tokenStore = FileTokenAccountStore(fileURL: Self.defaultTokenAccountsFileURL())
        self.monitor = ProviderUsageMonitorService(tokenAccountStore: tokenStore)
    }

    func fetchOutcomes(
        provider: UsageProvider,
        settings: UsageMonitorProviderSettings,
        costWindowDays: Int? = 30
    ) async -> [ProviderAccountUsageOutcome] {
        let effectiveWindow = costWindowDays ?? settings.costWindowDays
        return await monitor.fetchOutcomes(provider: provider, settings: settings, costWindowDays: effectiveWindow)
    }

    static func defaultTokenAccountsFileURL() -> URL {
        ProviderUsagePaths.defaultTokenAccountsFileURL()
    }
}
