import Foundation

// MARK: - Credit Models

/// Represents a single credit usage event
public struct CreditEvent: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public let date: Date
    public let service: String
    public let creditsUsed: Double

    public init(id: UUID = UUID(), date: Date, service: String, creditsUsed: Double) {
        self.id = id
        self.date = date
        self.service = service
        self.creditsUsed = creditsUsed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case service
        case creditsUsed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.date = try container.decode(Date.self, forKey: .date)
        self.service = try container.decode(String.self, forKey: .service)
        self.creditsUsed = try container.decode(Double.self, forKey: .creditsUsed)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.date, forKey: .date)
        try container.encode(self.service, forKey: .service)
        try container.encode(self.creditsUsed, forKey: .creditsUsed)
    }
}

/// Snapshot of credits status with remaining balance and usage events
public struct CreditsSnapshot: Equatable, Codable, Sendable {
    public let remaining: Double
    public let events: [CreditEvent]
    public let updatedAt: Date

    public init(remaining: Double, events: [CreditEvent], updatedAt: Date) {
        self.remaining = remaining
        self.events = events
        self.updatedAt = updatedAt
    }
}

// MARK: - Codex Status Models

/// Snapshot of Codex CLI status including credits and rate limits
public struct CodexStatusSnapshot: Sendable {
    public let credits: Double?
    public let fiveHourPercentLeft: Int?
    public let weeklyPercentLeft: Int?
    public let fiveHourResetDescription: String?
    public let weeklyResetDescription: String?
    public let rawText: String

    public init(
        credits: Double?,
        fiveHourPercentLeft: Int?,
        weeklyPercentLeft: Int?,
        fiveHourResetDescription: String?,
        weeklyResetDescription: String?,
        rawText: String
    ) {
        self.credits = credits
        self.fiveHourPercentLeft = fiveHourPercentLeft
        self.weeklyPercentLeft = weeklyPercentLeft
        self.fiveHourResetDescription = fiveHourResetDescription
        self.weeklyResetDescription = weeklyResetDescription
        self.rawText = rawText
    }
}

/// Errors that can occur during Codex status probing
public enum CodexStatusProbeError: LocalizedError, Sendable, Equatable {
    case codexNotInstalled
    case parseFailed(String)
    case timedOut
    case updateRequired(String)

    public var errorDescription: String? {
        switch self {
        case .codexNotInstalled:
            "Codex CLI missing. Install via `npm i -g @openai/codex` (or bun install) and restart."
        case .parseFailed:
            "Could not parse Codex status; will retry shortly."
        case .timedOut:
            "Codex status probe timed out."
        case let .updateRequired(msg):
            "Codex CLI update needed: \(msg)"
        }
    }
}

/// Errors that can occur during credits fetching
public enum CreditsFetchError: LocalizedError, Sendable, Equatable {
    case codexNotInstalled
    case rpcError(String)
    case parseFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .codexNotInstalled:
            "Codex CLI not found. Install with `npm i -g @openai/codex` (or bun) and restart."
        case let .rpcError(msg):
            "Codex RPC error: \(msg)"
        case let .parseFailed(msg):
            "Failed to parse credits: \(msg)"
        case .timedOut:
            "Credits fetch timed out."
        }
    }
}
