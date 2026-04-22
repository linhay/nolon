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

    public func displayDateRange(for rangeID: String) -> String {
        let orderedDays = points.map(\.date).sorted()
        guard !orderedDays.isEmpty else { return "-" }

        let visibleDays: ArraySlice<String>
        switch rangeID {
        case "days30":
            visibleDays = orderedDays.suffix(30)
        case "days7":
            visibleDays = orderedDays.suffix(7)
        case "days1":
            visibleDays = orderedDays.suffix(1)
        case "all":
            visibleDays = orderedDays[orderedDays.startIndex..<orderedDays.endIndex]
        default:
            visibleDays = orderedDays.suffix(1)
        }

        guard let startDay = visibleDays.first,
              let endDay = visibleDays.last else {
            return "-"
        }
        return Self.compactDateRange(startDay: startDay, endDay: endDay)
    }

    private static func compactDateRange(startDay: String, endDay: String) -> String {
        if startDay == endDay {
            return compactDateLabel(day: endDay, comparedTo: nil)
        }

        let startYear = yearComponent(in: startDay)
        let endYear = yearComponent(in: endDay)
        if startYear == endYear, startYear != nil {
            return "\(compactDateLabel(day: startDay, comparedTo: endDay)) - \(compactDateLabel(day: endDay, comparedTo: startDay))"
        }

        return "\(startDay) - \(endDay)"
    }

    private static func compactDateLabel(day: String, comparedTo otherDay: String?) -> String {
        let components = day.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3 else { return day }

        if let otherDay,
           yearComponent(in: day) != nil,
           yearComponent(in: day) == yearComponent(in: otherDay) {
            return "\(components[1])-\(components[2])"
        }

        if otherDay == nil {
            return "\(components[1])-\(components[2])"
        }

        return day
    }

    private static func yearComponent(in day: String) -> String? {
        let components = day.split(separator: "-", omittingEmptySubsequences: false)
        guard let year = components.first, components.count == 3 else { return nil }
        return String(year)
    }
}

public struct ProviderTokenTrendRefreshStatusData: Hashable, Sendable {
    public let title: String
    public let detail: String?
    public let progressLabel: String?
    public let fractionCompleted: Double?

    public var headlineText: String {
        let normalizedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedDetail.isEmpty else {
            return title
        }
        return "\(title)：\(normalizedDetail)"
    }

    public init(
        title: String,
        detail: String? = nil,
        progressLabel: String? = nil,
        fractionCompleted: Double? = nil
    ) {
        self.title = title
        self.detail = detail
        self.progressLabel = progressLabel
        self.fractionCompleted = fractionCompleted
    }
}

public enum ProviderTokenTrendChartStyle: String, CaseIterable, Hashable, Sendable {
    case bar
    case line
}

public enum ProviderTokenTrendContentTab: String, CaseIterable, Hashable, Sendable {
    case daily
    case intraday
}

public struct ProviderTokenTrendSectionData: Sendable {
    public let snapshot: ProviderTokenTrendSnapshotData?
    public let refreshStatus: ProviderTokenTrendRefreshStatusData?
    public let drilldown: ProviderTokenTrendDrilldownData?
    public let supportsIntradayDrilldown: Bool
    public let chartStyle: ProviderTokenTrendChartStyle
    public let activeTab: ProviderTokenTrendContentTab
    public let selectedDayKey: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedRangeID: String
    public let availableRanges: [ProviderTokenTrendRangeOption]

    public init(
        snapshot: ProviderTokenTrendSnapshotData?,
        refreshStatus: ProviderTokenTrendRefreshStatusData? = nil,
        drilldown: ProviderTokenTrendDrilldownData? = nil,
        supportsIntradayDrilldown: Bool = false,
        chartStyle: ProviderTokenTrendChartStyle = .bar,
        activeTab: ProviderTokenTrendContentTab = .daily,
        selectedDayKey: String? = nil,
        isLoading: Bool,
        errorMessage: String?,
        selectedRangeID: String,
        availableRanges: [ProviderTokenTrendRangeOption]
    ) {
        self.snapshot = snapshot
        self.refreshStatus = refreshStatus
        self.drilldown = drilldown
        self.supportsIntradayDrilldown = supportsIntradayDrilldown
        self.chartStyle = chartStyle
        self.activeTab = activeTab
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
    public let usageSummaryText: String?
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
        usageSummaryText: String?,
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
        self.usageSummaryText = usageSummaryText
        self.bucketSummary = bucketSummary
        self.presentationNote = presentationNote
        self.points = points
        self.availableBuckets = availableBuckets
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.freshnessText = freshnessText
    }
}
