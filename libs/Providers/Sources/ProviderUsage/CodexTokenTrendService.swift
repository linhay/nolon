import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct CodexTokenTrendService: Sendable {
    public typealias SnapshotLoader = @Sendable (
        _ provider: UsageProvider,
        _ trailingDays: Int?,
        _ forceRefresh: Bool,
        _ environment: [String: String]
    ) async throws -> CostUsageTokenSnapshot

    private let loadSnapshot: SnapshotLoader

    public init(loadSnapshot: @escaping SnapshotLoader = { provider, trailingDays, forceRefresh, environment in
        try await CostUsageFetcher().loadTokenSnapshot(
            provider: provider,
            trailingDays: trailingDays,
            forceRefresh: forceRefresh,
            environment: environment
        )
    }) {
        self.loadSnapshot = loadSnapshot
    }

    public func fetchGlobalSnapshot(
        trailingDays: Int? = 30,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> ProviderTokenTrendSnapshot {
        var globalEnvironment = environment
        globalEnvironment.removeValue(forKey: "CODEX_HOME")

        let snapshot = try await loadSnapshot(.codex, trailingDays, false, globalEnvironment)
        let points = snapshot.daily
            .map { entry in
                let input = max(0, entry.inputTokens ?? 0)
                let output = max(0, entry.outputTokens ?? 0)
                let cache = max(0, entry.cacheReadTokens ?? 0)
                let total = max(0, entry.totalTokens ?? (input + output))
                return ProviderTokenTrendPoint(
                    date: entry.date,
                    totalTokens: total,
                    inputTokens: input,
                    outputTokens: output,
                    cacheReadTokens: cache
                )
            }
            .sorted { $0.date < $1.date }

        let today = snapshot.sessionTokens ?? points.last?.totalTokens
        let last7 = sumTrailing(points: points, days: 7)
        let last30 = sumTrailing(points: points, days: 30)

        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: today,
            last7DaysTokens: last7,
            last30DaysTokens: last30,
            updatedAt: snapshot.updatedAt,
            sourceLabel: "global"
        )
    }

    private func sumTrailing(points: [CodexTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.totalTokens)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }
}
