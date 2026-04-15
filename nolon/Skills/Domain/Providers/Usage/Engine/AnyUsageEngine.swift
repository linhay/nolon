import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
protocol AnyUsageEngine: AnyObject {
    var provider: Provider { get }
    var usageProvider: UsageProvider? { get }
    var accounts: any ProviderUsageAccountsEngineProtocol { get }
    var metrics: any ProviderUsageMetricsEngineProtocol { get }
    var codex: any ProviderUsageCodexEngineProtocol { get }
    var claude: any ProviderUsageClaudeEngineProtocol { get }
    var gemini: any ProviderUsageGeminiEngineProtocol { get }
}

extension ProviderUsageEngine: AnyUsageEngine {
    var accounts: any ProviderUsageAccountsEngineProtocol { self }
    var metrics: any ProviderUsageMetricsEngineProtocol { self }
    var codex: any ProviderUsageCodexEngineProtocol { self }
    var claude: any ProviderUsageClaudeEngineProtocol { self }
    var gemini: any ProviderUsageGeminiEngineProtocol { self }
}
