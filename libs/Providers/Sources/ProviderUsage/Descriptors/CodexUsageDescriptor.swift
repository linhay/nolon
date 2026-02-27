import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct CodexUsageDescriptor: ProviderUsageDescribing {
    public let provider: UsageProvider = .codex
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .cli])
    private let fetchRateLimitsAndAccountInfo: @Sendable (_ context: ProviderFetchContext) async throws -> (CodexHelper.RateLimitsSnapshot, CodexHelper.AccountInfo?)
    private let fetchStatusSnapshot: @Sendable (_ environment: [String: String]) async throws -> CodexStatusSnapshot

    public init() {
        self.fetchRateLimitsAndAccountInfo = { context in
            let helper = CodexHelper(codexBinary: nil, environment: context.environment)
            async let rateLimitsTask = helper.fetchRateLimits()
            async let accountInfoTask: CodexHelper.AccountInfo? = try? helper.fetchAccountInfo()
            let rateLimits = try await rateLimitsTask
            let accountInfo = await accountInfoTask
            return (rateLimits, accountInfo)
        }
        self.fetchStatusSnapshot = { environment in
            try await CodexStatusProbe(environment: environment).fetch()
        }
    }

    init(
        fetchRateLimitsAndAccountInfo: @escaping @Sendable (_ context: ProviderFetchContext) async throws -> (CodexHelper.RateLimitsSnapshot, CodexHelper.AccountInfo?),
        fetchStatusSnapshot: @escaping @Sendable (_ environment: [String: String]) async throws -> CodexStatusSnapshot
    ) {
        self.fetchRateLimitsAndAccountInfo = fetchRateLimitsAndAccountInfo
        self.fetchStatusSnapshot = fetchStatusSnapshot
    }

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        let fetchKind: ProviderFetchKind = .cli

        do {
            let (rateLimits, accountInfo) = try await fetchRateLimitsAndAccountInfo(context)
            let statusSnapshot: CodexStatusSnapshot?
            if rateLimits.primary?.resetsAt == nil || rateLimits.secondary?.resetsAt == nil {
                statusSnapshot = try? await fetchStatusSnapshot(context.environment)
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

            let sourceLabel = NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI")

            let result = ProviderFetchResult(
                usage: usage,
                credits: credits,
                cost: nil,
                sourceLabel: sourceLabel,
                fetchKind: fetchKind,
                strategyKind: .direct
            )
            return ProviderFetchOutcome(fetchKind: fetchKind, result: .success(result))
        } catch {
            if let fallbackUsage = await self.makeFallbackUsage(context: context) {
                let result = ProviderFetchResult(
                    usage: fallbackUsage,
                    credits: nil,
                    cost: nil,
                    sourceLabel: NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI"),
                    fetchKind: fetchKind,
                    strategyKind: .fallback
                )
                return ProviderFetchOutcome(fetchKind: fetchKind, result: .success(result))
            }
            return ProviderFetchOutcome(fetchKind: fetchKind, result: .failure(error))
        }
    }

    private func makeFallbackUsage(context: ProviderFetchContext) async -> UsageSnapshot? {
        guard let status = try? await fetchStatusSnapshot(context.environment) else {
            return nil
        }
        let primary = status.fiveHourPercentLeft.map { left in
            RateWindow(
                usedPercent: Self.usedPercent(fromPercentLeft: left),
                resetDescription: status.fiveHourResetDescription.map(Self.formatStatusResetDescription),
                resetsAt: nil,
                windowMinutes: nil
            )
        }
        let secondary = status.weeklyPercentLeft.map { left in
            RateWindow(
                usedPercent: Self.usedPercent(fromPercentLeft: left),
                resetDescription: status.weeklyResetDescription.map(Self.formatStatusResetDescription),
                resetsAt: nil,
                windowMinutes: nil
            )
        }
        if primary == nil, secondary == nil {
            return nil
        }
        return UsageSnapshot(
            identity: nil,
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            updatedAt: Date()
        )
    }

    private static func usedPercent(fromPercentLeft percentLeft: Int) -> Double {
        let clamped = max(0, min(100, percentLeft))
        return Double(100 - clamped)
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
