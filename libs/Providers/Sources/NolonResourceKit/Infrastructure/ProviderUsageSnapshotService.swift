import Foundation

public enum ProviderUsageOutcomeStatus: String, Sendable, Equatable {
    case success
    case failure
}

public struct ProviderUsageSnapshotItem: Sendable, Equatable {
    public let id: String
    public let status: ProviderUsageOutcomeStatus
    public let updatedAt: Date?
    public let hasCredits: Bool

    public init(id: String, status: ProviderUsageOutcomeStatus, updatedAt: Date?, hasCredits: Bool) {
        self.id = id
        self.status = status
        self.updatedAt = updatedAt
        self.hasCredits = hasCredits
    }
}

public struct ProviderUsageAggregate: Sendable, Equatable {
    public let totalCount: Int
    public let successCount: Int
    public let failureCount: Int
    public let creditsReadyCount: Int
    public let latestUpdatedAt: Date?

    public init(
        totalCount: Int,
        successCount: Int,
        failureCount: Int,
        creditsReadyCount: Int,
        latestUpdatedAt: Date?
    ) {
        self.totalCount = totalCount
        self.successCount = successCount
        self.failureCount = failureCount
        self.creditsReadyCount = creditsReadyCount
        self.latestUpdatedAt = latestUpdatedAt
    }
}

public struct ProviderUsageSnapshotService: Sendable {
    public init() {}

    public func aggregate(items: [ProviderUsageSnapshotItem]) -> ProviderUsageAggregate {
        let success = items.filter { $0.status == .success }.count
        let failure = items.count - success
        let creditsReady = items.filter(\.hasCredits).count
        let latest = items.compactMap(\.updatedAt).max()
        return ProviderUsageAggregate(
            totalCount: items.count,
            successCount: success,
            failureCount: failure,
            creditsReadyCount: creditsReady,
            latestUpdatedAt: latest
        )
    }
}
