import Foundation

public struct CodexAuthUsageCache: Codable, Sendable, Equatable {
    public var version: Int
    public var cachedAt: Date
    public var creditsRefreshedAt: Date?
    public var fetchKind: ProviderFetchKind
    public var strategyKind: ProviderFetchStrategyKind
    public var sourceLabel: String

    public var usage: UsageSnapshot
    public var credits: CreditsSnapshot?
    public var cost: CostSnapshot?

    public init(
        version: Int = 1,
        cachedAt: Date = Date(),
        creditsRefreshedAt: Date? = nil,
        fetchKind: ProviderFetchKind,
        strategyKind: ProviderFetchStrategyKind,
        sourceLabel: String,
        usage: UsageSnapshot,
        credits: CreditsSnapshot?,
        cost: CostSnapshot?
    ) {
        self.version = version
        self.cachedAt = cachedAt
        self.creditsRefreshedAt = creditsRefreshedAt
        self.fetchKind = fetchKind
        self.strategyKind = strategyKind
        self.sourceLabel = sourceLabel
        self.usage = usage
        self.credits = credits
        self.cost = cost
    }

    public func toFetchResult() -> ProviderFetchResult {
        ProviderFetchResult(
            usage: usage,
            credits: credits,
            cost: cost,
            sourceLabel: sourceLabel,
            fetchKind: fetchKind,
            strategyKind: strategyKind
        )
    }

    public static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return encoder
    }

    public static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return decoder
    }
}
