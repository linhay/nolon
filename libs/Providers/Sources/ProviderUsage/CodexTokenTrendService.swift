import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct CodexTokenTrendPoint: Codable, Sendable, Equatable {
    public let date: String
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int

    public init(
        date: String,
        totalTokens: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int
    ) {
        self.date = date
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
    }
}

public struct CodexTokenTrendSnapshot: Codable, Sendable, Equatable {
    public let points: [CodexTokenTrendPoint]
    public let todayTokens: Int?
    public let last7DaysTokens: Int?
    public let last30DaysTokens: Int?
    public let updatedAt: Date
    public let sourceLabel: String

    public init(
        points: [CodexTokenTrendPoint],
        todayTokens: Int?,
        last7DaysTokens: Int?,
        last30DaysTokens: Int?,
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.points = points
        self.todayTokens = todayTokens
        self.last7DaysTokens = last7DaysTokens
        self.last30DaysTokens = last30DaysTokens
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }
}

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
    ) async throws -> CodexTokenTrendSnapshot {
        var globalEnvironment = environment
        globalEnvironment.removeValue(forKey: "CODEX_HOME")

        let snapshot = try await loadSnapshot(.codex, trailingDays, false, globalEnvironment)
        let points = snapshot.daily
            .map { entry in
                let input = max(0, entry.inputTokens ?? 0)
                let output = max(0, entry.outputTokens ?? 0)
                let cache = max(0, entry.cacheReadTokens ?? 0)
                let total = max(0, entry.totalTokens ?? (input + output))
                return CodexTokenTrendPoint(
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

        return CodexTokenTrendSnapshot(
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
