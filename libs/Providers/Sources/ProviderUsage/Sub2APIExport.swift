import Foundation

public struct Sub2APIExportPayload: Codable, Sendable, Equatable {
    public let type: String
    public let version: Int
    public let exportedAt: String
    public let proxies: [Sub2APIProxy]
    public let accounts: [Sub2APIAccount]

    public init(
        type: String = "sub2api-data",
        version: Int = 1,
        exportedAt: String,
        proxies: [Sub2APIProxy] = [],
        accounts: [Sub2APIAccount]
    ) {
        self.type = type
        self.version = version
        self.exportedAt = exportedAt
        self.proxies = proxies
        self.accounts = accounts
    }

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case exportedAt = "exported_at"
        case proxies
        case accounts
    }
}

public struct Sub2APIProxy: Codable, Sendable, Equatable {
    public init() {}
}

public struct Sub2APIAccount: Codable, Sendable, Equatable {
    public let name: String
    public let notes: String
    public let platform: String
    public let type: String
    public let credentials: [String: String]
    public let extra: [String: Bool]
    public let concurrency: Int
    public let priority: Int
    public let rateMultiplier: Int
    public let autoPauseOnExpired: Bool

    public init(
        name: String,
        notes: String,
        platform: String = "openai",
        type: String,
        credentials: [String: String],
        extra: [String: Bool],
        concurrency: Int,
        priority: Int,
        rateMultiplier: Int,
        autoPauseOnExpired: Bool
    ) {
        self.name = name
        self.notes = notes
        self.platform = platform
        self.type = type
        self.credentials = credentials
        self.extra = extra
        self.concurrency = concurrency
        self.priority = priority
        self.rateMultiplier = rateMultiplier
        self.autoPauseOnExpired = autoPauseOnExpired
    }

    enum CodingKeys: String, CodingKey {
        case name
        case notes
        case platform
        case type
        case credentials
        case extra
        case concurrency
        case priority
        case rateMultiplier = "rate_multiplier"
        case autoPauseOnExpired = "auto_pause_on_expired"
    }
}

public struct Sub2APIExportResult: Sendable, Equatable {
    public let exportedCount: Int
    public let skippedRelayCount: Int
    public let skippedUnsupportedCount: Int

    public init(exportedCount: Int, skippedRelayCount: Int, skippedUnsupportedCount: Int) {
        self.exportedCount = exportedCount
        self.skippedRelayCount = skippedRelayCount
        self.skippedUnsupportedCount = skippedUnsupportedCount
    }
}
