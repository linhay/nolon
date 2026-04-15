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
    public let drilldown: ProviderTokenTrendDrilldownData?
    public let selectedDayKey: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedRangeID: String
    public let availableRanges: [ProviderTokenTrendRangeOption]

    public init(
        snapshot: ProviderTokenTrendSnapshotData?,
        drilldown: ProviderTokenTrendDrilldownData? = nil,
        selectedDayKey: String? = nil,
        isLoading: Bool,
        errorMessage: String?,
        selectedRangeID: String,
        availableRanges: [ProviderTokenTrendRangeOption]
    ) {
        self.snapshot = snapshot
        self.drilldown = drilldown
        self.selectedDayKey = selectedDayKey
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedRangeID = selectedRangeID
        self.availableRanges = availableRanges
    }
}

public struct ProviderIntradayBucketOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct ProviderIntradayUsagePointData: Hashable, Sendable {
    public let label: String
    public let rangeLabel: String
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int

    public init(
        label: String,
        rangeLabel: String,
        totalTokens: Int,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int
    ) {
        self.label = label
        self.rangeLabel = rangeLabel
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
    }
}

public struct ProviderTokenTrendDrilldownData: Sendable {
    public let dayKey: String
    public let bucketID: String
    public let actualBucketCount: Int
    public let fullBucketCount: Int
    public let rangeDescription: String
    public let bucketSummary: String?
    public let presentationNote: String?
    public let points: [ProviderIntradayUsagePointData]
    public let availableBuckets: [ProviderIntradayBucketOption]
    public let isLoading: Bool
    public let errorMessage: String?
    public let freshnessText: String?

    public init(
        dayKey: String,
        bucketID: String,
        actualBucketCount: Int,
        fullBucketCount: Int,
        rangeDescription: String,
        bucketSummary: String?,
        presentationNote: String?,
        points: [ProviderIntradayUsagePointData],
        availableBuckets: [ProviderIntradayBucketOption],
        isLoading: Bool,
        errorMessage: String?,
        freshnessText: String?
    ) {
        self.dayKey = dayKey
        self.bucketID = bucketID
        self.actualBucketCount = actualBucketCount
        self.fullBucketCount = fullBucketCount
        self.rangeDescription = rangeDescription
        self.bucketSummary = bucketSummary
        self.presentationNote = presentationNote
        self.points = points
        self.availableBuckets = availableBuckets
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.freshnessText = freshnessText
    }
}
