import Foundation

// MARK: - Copilot Usage Models

/// Response from GitHub Copilot API
public struct CopilotUsageResponse: Sendable, Decodable {
    public struct QuotaSnapshot: Sendable, Decodable {
        public let entitlement: Double
        public let remaining: Double
        public let percentRemaining: Double
        public let quotaId: String

        private enum CodingKeys: String, CodingKey {
            case entitlement
            case remaining
            case percentRemaining = "percent_remaining"
            case quotaId = "quota_id"
        }
    }

    public struct QuotaSnapshots: Sendable, Decodable {
        public let premiumInteractions: QuotaSnapshot?
        public let chat: QuotaSnapshot?

        private enum CodingKeys: String, CodingKey {
            case premiumInteractions = "premium_interactions"
            case chat
        }
    }

    public let quotaSnapshots: QuotaSnapshots
    public let copilotPlan: String
    public let assignedDate: String
    public let quotaResetDate: String

    private enum CodingKeys: String, CodingKey {
        case quotaSnapshots = "quota_snapshots"
        case copilotPlan = "copilot_plan"
        case assignedDate = "assigned_date"
        case quotaResetDate = "quota_reset_date"
    }
}

// MARK: - Simplified Copilot Quota

/// Simplified quota information for a specific Copilot feature
public struct CopilotQuota: Sendable {
    public let feature: String
    public let total: Double
    public let remaining: Double
    public let percentRemaining: Double
    
    public var used: Double {
        total - remaining
    }
    
    public var percentUsed: Double {
        100.0 - percentRemaining
    }
    
    public init(feature: String, total: Double, remaining: Double, percentRemaining: Double) {
        self.feature = feature
        self.total = total
        self.remaining = remaining
        self.percentRemaining = percentRemaining
    }
}

public struct CopilotViewerProfile: Sendable, Equatable {
    public let login: String?
    public let name: String?
    public let email: String?

    public init(login: String?, name: String?, email: String?) {
        self.login = login
        self.name = name
        self.email = email
    }
}

// MARK: - Copilot Usage Snapshot

/// Complete Copilot usage snapshot
public struct CopilotUsageSnapshot: Sendable {
    public let plan: String
    public let viewer: CopilotViewerProfile?
    public let premiumQuota: CopilotQuota?
    public let chatQuota: CopilotQuota?
    public let quotaResetDate: String
    public let updatedAt: Date
    
    public init(
        plan: String,
        viewer: CopilotViewerProfile? = nil,
        premiumQuota: CopilotQuota?,
        chatQuota: CopilotQuota?,
        quotaResetDate: String,
        updatedAt: Date = Date()
    ) {
        self.plan = plan
        self.viewer = viewer
        self.premiumQuota = premiumQuota
        self.chatQuota = chatQuota
        self.quotaResetDate = quotaResetDate
        self.updatedAt = updatedAt
    }
}

// MARK: - Errors

/// Errors that can occur during Copilot usage fetching
public enum CopilotUsageError: LocalizedError, Sendable {
    case invalidToken
    case networkError(String)
    case invalidResponse
    case decodingError(String)
    case unauthorized
    case apiError(Int, String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid or missing GitHub token. Set COPILOT_API_TOKEN environment variable."
        case let .networkError(message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case let .decodingError(message):
            return "Failed to decode response: \(message)"
        case .unauthorized:
            return "Unauthorized. Please check your GitHub token."
        case let .apiError(code, message):
            return "GitHub API error (\(code)): \(message)"
        }
    }
}
