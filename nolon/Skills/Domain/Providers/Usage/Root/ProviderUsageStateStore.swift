import Observation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
@Observable
final class ProviderUsageStateStore {
    let provider: Provider
    let usageProvider: UsageProvider?
    let engine: any AnyUsageEngine
    var commonEngine: any ProviderUsageCommonEngineProtocol { engine.common }
    var codexEngine: any ProviderUsageCodexEngineProtocol { engine.codex }
    var claudeEngine: any ProviderUsageClaudeEngineProtocol { engine.claude }
    var geminiEngine: any ProviderUsageGeminiEngineProtocol { engine.gemini }

    init(provider: Provider, engine: any AnyUsageEngine) {
        self.provider = provider
        self.usageProvider = engine.usageProvider
        self.engine = engine
    }
}
