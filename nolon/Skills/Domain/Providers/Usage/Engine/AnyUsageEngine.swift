import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
protocol AnyUsageEngine: AnyObject {
    var provider: Provider { get }
    var usageProvider: UsageProvider? { get }
    var common: any ProviderUsageCommonEngineProtocol { get }
    var codex: any ProviderUsageCodexEngineProtocol { get }
    var claude: any ProviderUsageClaudeEngineProtocol { get }
    var gemini: any ProviderUsageGeminiEngineProtocol { get }
}

extension ProviderUsageEngine: AnyUsageEngine {
    var common: any ProviderUsageCommonEngineProtocol { self }
    var codex: any ProviderUsageCodexEngineProtocol { self }
    var claude: any ProviderUsageClaudeEngineProtocol { self }
    var gemini: any ProviderUsageGeminiEngineProtocol { self }
}
