import Foundation
import CodexBarProviderCatalog

public protocol ProviderUsageDescribing: Sendable {
    var provider: UsageProvider { get }
    var fetchPlan: ProviderFetchPlan { get }
    func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome
}

