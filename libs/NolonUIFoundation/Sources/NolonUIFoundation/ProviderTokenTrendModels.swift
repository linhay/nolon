import Foundation

public struct ProviderTokenTrendRangeOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct ProviderTokenTrendPointData: Hashable, Sendable {
    public let date: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int

    public init(
        date: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        totalTokens: Int
    ) {
        self.date = date
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalTokens = totalTokens
    }
}

public struct ProviderTokenTrendSnapshotData: Sendable {
    public let points: [ProviderTokenTrendPointData]
    public let todayTokens: Int?
    public let last7DaysTokens: Int?
    public let last30DaysTokens: Int?
    public let allDaysTokens: Int?
    public let updatedAt: Date
    public let sourceLabel: String

    public init(
        points: [ProviderTokenTrendPointData],
        todayTokens: Int?,
        last7DaysTokens: Int?,
        last30DaysTokens: Int?,
        allDaysTokens: Int?,
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.points = points
        self.todayTokens = todayTokens
        self.last7DaysTokens = last7DaysTokens
        self.last30DaysTokens = last30DaysTokens
        self.allDaysTokens = allDaysTokens
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }
}

public struct ProviderTokenTrendSectionData: Sendable {
    public let snapshot: ProviderTokenTrendSnapshotData?
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedRangeID: String
    public let availableRanges: [ProviderTokenTrendRangeOption]

    public init(
        snapshot: ProviderTokenTrendSnapshotData?,
        isLoading: Bool,
        errorMessage: String?,
        selectedRangeID: String,
        availableRanges: [ProviderTokenTrendRangeOption]
    ) {
        self.snapshot = snapshot
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedRangeID = selectedRangeID
        self.availableRanges = availableRanges
    }
}
