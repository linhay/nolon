import Foundation
import CodexBarProviderCatalog
import CopilotProvider

public struct CopilotUsageDescriptor: ProviderUsageDescribing {
    public let provider: UsageProvider = .copilot
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .apiToken])

    public init() {}

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        let fetchKind: ProviderFetchKind = .apiToken

        do {
            let token = context.token ?? context.environment["COPILOT_API_TOKEN"]
            guard let token, !token.isEmpty else {
                throw ProviderUsageError.missingToken(.copilot)
            }

            let fetcher = CopilotUsageFetcher(token: token)
            let usageSnapshot = try await fetcher.fetch()

            let primary = usageSnapshot.chatQuota.map { quota in
                RateWindow(
                    usedPercent: quota.percentUsed,
                    resetDescription: String(
                        format: NSLocalizedString(
                            "usage.metric.resets_at_string",
                            value: "Resets %@",
                            comment: "Resets at label (string date)"
                        ),
                        usageSnapshot.quotaResetDate
                    )
                )
            }

            let secondary = usageSnapshot.premiumQuota.map { quota in
                RateWindow(
                    usedPercent: quota.percentUsed,
                    resetDescription: String(
                        format: NSLocalizedString(
                            "usage.metric.resets_at_string",
                            value: "Resets %@",
                            comment: "Resets at label (string date)"
                        ),
                        usageSnapshot.quotaResetDate
                    )
                )
            }

            let identity = UsageIdentity(
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "GitHub",
                plan: usageSnapshot.plan
            )

            let usage = UsageSnapshot(
                identity: identity,
                primary: primary,
                secondary: secondary,
                tertiary: nil,
                updatedAt: usageSnapshot.updatedAt
            )

            let result = ProviderFetchResult(
                usage: usage,
                credits: nil,
                cost: nil,
                sourceLabel: NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token"),
                fetchKind: fetchKind,
                strategyKind: .direct
            )

            return ProviderFetchOutcome(fetchKind: fetchKind, result: .success(result))
        } catch {
            return ProviderFetchOutcome(fetchKind: fetchKind, result: .failure(error))
        }
    }
}
