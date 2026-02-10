import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct CodexUsageDescriptor: ProviderUsageDescribing {
    public let provider: UsageProvider = .codex
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .cli])

    public init() {}

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        let fetchKind: ProviderFetchKind = .cli

        do {
            let helper = CodexHelper(codexBinary: nil, environment: context.environment)
            async let rateLimitsTask = helper.fetchRateLimits()
            async let accountInfoTask: CodexHelper.AccountInfo? = try? helper.fetchAccountInfo()
            async let costTask: CodexCostSnapshot? = context.includeCredits ? (try? CodexCostFetcher().fetchCostSnapshot()) : nil

            let rateLimits = try await rateLimitsTask
            let accountInfo = await accountInfoTask
            let costInfo = await costTask
            let statusSnapshot: CodexStatusSnapshot?
            if rateLimits.primary?.resetsAt == nil || rateLimits.secondary?.resetsAt == nil {
                statusSnapshot = try? await CodexStatusProbe().fetch()
            } else {
                statusSnapshot = nil
            }

            let primary = rateLimits.primary.map { window in
                let resetDescription = window.resetsAt.map {
                    String(
                        format: NSLocalizedString("usage.metric.resets_at", value: "Resets %@", comment: "Resets label"),
                        $0.formatted(date: .abbreviated, time: .shortened)
                    )
                } ?? statusSnapshot?.fiveHourResetDescription.map(Self.formatStatusResetDescription)
                return RateWindow(
                    usedPercent: window.usedPercent,
                    resetDescription: resetDescription,
                    resetsAt: window.resetsAt,
                    windowMinutes: window.windowDurationMins
                )
            }

            let secondary = rateLimits.secondary.map { window in
                let resetDescription = window.resetsAt.map {
                    String(
                        format: NSLocalizedString("usage.metric.resets_at", value: "Resets %@", comment: "Resets label"),
                        $0.formatted(date: .abbreviated, time: .shortened)
                    )
                } ?? statusSnapshot?.weeklyResetDescription.map(Self.formatStatusResetDescription)
                return RateWindow(
                    usedPercent: window.usedPercent,
                    resetDescription: resetDescription,
                    resetsAt: window.resetsAt,
                    windowMinutes: window.windowDurationMins
                )
            }

            let identity: UsageIdentity? = accountInfo.map { info in
                UsageIdentity(
                    accountEmail: info.email,
                    accountOrganization: nil,
                    loginMethod: info.plan == "api_key" ? "api_key" : "oauth",
                    plan: info.plan
                )
            }

            let usage = UsageSnapshot(
                identity: identity,
                primary: primary,
                secondary: secondary,
                tertiary: nil,
                updatedAt: rateLimits.updatedAt
            )

            let credits: CreditsSnapshot? = await self.fetchCreditsIfNeeded(
                includeCredits: context.includeCredits,
                environment: context.environment,
                fallbackCredits: nil
            )

            let cost: CostSnapshot? = costInfo.map { snapshot in
                CostSnapshot(
                    todayCostUSD: snapshot.todayCostUSD,
                    todayTokens: snapshot.todayTokens,
                    todayInputTokens: snapshot.todayInputTokens,
                    todayOutputTokens: snapshot.todayOutputTokens,
                    todayCachedInputTokens: snapshot.todayCachedInputTokens,
                    rangeDays: snapshot.rangeDays,
                    rangeCostUSD: snapshot.rangeCostUSD,
                    rangeTokens: snapshot.rangeTokens,
                    rangeInputTokens: snapshot.rangeInputTokens,
                    rangeOutputTokens: snapshot.rangeOutputTokens,
                    rangeCachedInputTokens: snapshot.rangeCachedInputTokens,
                    updatedAt: snapshot.updatedAt
                )
            }

            let result = ProviderFetchResult(
                usage: usage,
                credits: credits,
                cost: cost,
                sourceLabel: NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI"),
                fetchKind: fetchKind,
                strategyKind: .direct
            )
            return ProviderFetchOutcome(fetchKind: fetchKind, result: .success(result))
        } catch {
            return ProviderFetchOutcome(fetchKind: fetchKind, result: .failure(error))
        }
    }

    private func fetchCreditsIfNeeded(
        includeCredits: Bool,
        environment: [String: String],
        fallbackCredits: Double?
    ) async -> CreditsSnapshot? {
        guard includeCredits else { return nil }

        do {
            let fetcher = CodexCreditsFetcher(environment: environment)
            let snapshot = try await fetcher.fetchCredits(keepCLISessionsAlive: false)
            return CreditsSnapshot(remaining: snapshot.remaining, updatedAt: snapshot.updatedAt)
        } catch {
            if let fallbackCredits {
                return CreditsSnapshot(remaining: fallbackCredits, updatedAt: Date())
            }
            return nil
        }
    }

    static func formatStatusResetDescription(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return raw }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("in ") {
            let tail = trimmed.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                return String(
                    format: NSLocalizedString(
                        "usage.metric.resets_in",
                        value: "Resets in %@",
                        comment: "Resets countdown label"
                    ),
                    String(tail)
                )
            }
        }
        if lower.hasPrefix("at ") {
            let tail = trimmed.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                return String(
                    format: NSLocalizedString("usage.metric.resets_at", value: "Resets %@", comment: "Resets label"),
                    String(tail)
                )
            }
        }

        return String(
            format: NSLocalizedString("usage.metric.resets_at", value: "Resets %@", comment: "Resets label"),
            trimmed
        )
    }
}
