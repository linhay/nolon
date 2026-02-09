import Foundation
import ProviderUsage
import CodexBarProviderCatalog

actor UsageMonitorService {
    private let tokenStore: FileTokenAccountStore

    init() {
        self.tokenStore = FileTokenAccountStore(fileURL: Self.defaultTokenAccountsFileURL())
    }

    func fetchOutcomes(
        provider: UsageProvider,
        settings: UsageMonitorProviderSettings,
        costWindowDays: Int? = 30
    ) async -> [ProviderAccountUsageOutcome] {
        var environment = ProcessInfo.processInfo.environment
        if provider == .codex {
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                environment.merge(managedEnv) { _, new in new }
            }
            if let codexCLIPath = await CodexBinaryManager.shared.activeCLIPathIfAvailable() {
                environment["CODEX_CLI_PATH"] = codexCLIPath
            }
        }
        let monitor = ProviderUsageMonitorService(tokenAccountStore: tokenStore, baseEnvironment: environment)
        let effectiveWindow = costWindowDays ?? settings.costWindowDays
        return await monitor.fetchOutcomes(provider: provider, settings: settings, costWindowDays: effectiveWindow)
    }

    static func defaultTokenAccountsFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Nolon", isDirectory: true)
            .appendingPathComponent("token-accounts.json")
    }
}
