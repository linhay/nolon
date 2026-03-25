import Observation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
@Observable
final class ProviderUsageStateStore {
    let provider: Provider
    let usageProvider: UsageProvider?
    let engine: ProviderUsageEngine

    init(provider: Provider, engine: ProviderUsageEngine) {
        self.provider = provider
        self.usageProvider = engine.usageProvider
        self.engine = engine
    }
}
