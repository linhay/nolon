import SwiftUI
import ProviderUsage
import NolonUI
import NolonUIFoundation

struct ProviderTokenTrendSection: View, DebugPageLocatable {
    let snapshot: ProviderTokenTrendSnapshot?
    let capability: ProviderUsageCurveCapability
    let selectedDayKey: String?
    let intradayBucket: ProviderIntradayBucket
    let intradaySnapshot: ProviderIntradayUsageSnapshot?
    let intradayErrorMessage: String?
    let isLoadingIntraday: Bool
    let isLoading: Bool
    let errorMessage: String?
    let range: ProviderUsageEngine.TokenTrendRange
    let onRangeChange: (ProviderUsageEngine.TokenTrendRange) -> Void
    let onSelectDay: (String?) -> Void
    let onIntradayBucketChange: (ProviderIntradayBucket) -> Void
    let onRefresh: () -> Void
    let onRefreshIntraday: () -> Void
    let debugPageMarkerItems: [PageMarkerItem]

    init(
        snapshot: ProviderTokenTrendSnapshot?,
        capability: ProviderUsageCurveCapability,
        selectedDayKey: String?,
        intradayBucket: ProviderIntradayBucket,
        intradaySnapshot: ProviderIntradayUsageSnapshot?,
        intradayErrorMessage: String?,
        isLoadingIntraday: Bool,
        isLoading: Bool,
        errorMessage: String?,
        range: ProviderUsageEngine.TokenTrendRange,
        onRangeChange: @escaping (ProviderUsageEngine.TokenTrendRange) -> Void,
        onSelectDay: @escaping (String?) -> Void,
        onIntradayBucketChange: @escaping (ProviderIntradayBucket) -> Void,
        onRefresh: @escaping () -> Void,
        onRefreshIntraday: @escaping () -> Void,
        debugPageMarkerItems: [PageMarkerItem] = []
    ) {
        self.snapshot = snapshot
        self.capability = capability
        self.selectedDayKey = selectedDayKey
        self.intradayBucket = intradayBucket
        self.intradaySnapshot = intradaySnapshot
        self.intradayErrorMessage = intradayErrorMessage
        self.isLoadingIntraday = isLoadingIntraday
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.range = range
        self.onRangeChange = onRangeChange
        self.onSelectDay = onSelectDay
        self.onIntradayBucketChange = onIntradayBucketChange
        self.onRefresh = onRefresh
        self.onRefreshIntraday = onRefreshIntraday
        self.debugPageMarkerItems = debugPageMarkerItems
    }

    var body: some View {
        NolonUI.ProviderTokenTrendSectionView(
            data: sectionData,
            onRangeChange: { rangeID in
                guard let next = ProviderUsageEngine.TokenTrendRange(rawValue: rangeID) else { return }
                onRangeChange(next)
            },
            onSelectDay: onSelectDay,
            onIntradayBucketChange: { bucketID in
                guard let bucket = ProviderIntradayBucket(rawValue: bucketID) else { return }
                onIntradayBucketChange(bucket)
            },
            onRefresh: onRefresh,
            onRefreshIntraday: onRefreshIntraday
        )
        .debugPageLocator(debugPageMarkerItems)
    }

    private var sectionData: ProviderTokenTrendSectionData {
        ProviderTokenTrendSectionData(
            snapshot: snapshot.map { snapshot in
                .init(
                    points: snapshot.points.map {
                        .init(
                            date: $0.date,
                            inputTokens: $0.inputTokens,
                            outputTokens: $0.outputTokens,
                            cacheReadTokens: $0.cacheReadTokens,
                            totalTokens: $0.totalTokens
                        )
                    },
                    todayTokens: snapshot.todayTokens,
                    last7DaysTokens: snapshot.last7DaysTokens,
                    last30DaysTokens: snapshot.last30DaysTokens,
                    allDaysTokens: snapshot.allDaysTokens,
                    updatedAt: snapshot.updatedAt,
                    sourceLabel: snapshot.sourceLabel
                )
            },
            drilldown: drilldownData,
            selectedDayKey: selectedDayKey,
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedRangeID: range.rawValue,
            availableRanges: ProviderUsageEngine.TokenTrendRange.allCases.map {
                .init(id: $0.rawValue, title: $0.title)
            }
        )
    }

    private var drilldownData: ProviderTokenTrendDrilldownData? {
        guard capability == .dailyWithIntradayDrilldown else { return nil }
        guard let selectedDayKey else { return nil }

        let snapshot = intradaySnapshot?.dayKey == selectedDayKey ? intradaySnapshot : nil
        return ProviderTokenTrendSectionPresentationSupport.makeDrilldownData(
            dayKey: selectedDayKey,
            bucket: intradayBucket,
            snapshot: snapshot,
            isLoading: isLoadingIntraday,
            errorMessage: intradayErrorMessage,
            availableBuckets: ProviderIntradayBucket.allCases.map {
                .init(id: $0.rawValue, title: $0.title)
            }
        )
    }
}

enum ProviderTokenTrendSectionPresentationSupport {
    static func makeDrilldownData(
        dayKey: String,
        bucket: ProviderIntradayBucket,
        snapshot: ProviderIntradayUsageSnapshot?,
        isLoading: Bool,
        errorMessage: String?,
        availableBuckets: [ProviderIntradayBucketOption],
        referenceDate: Date = Date()
    ) -> ProviderTokenTrendDrilldownData {
        let timezone = snapshot.flatMap { TimeZone(identifier: $0.timezoneIdentifier) } ?? .current
        let points = snapshot?.points.map {
            ProviderIntradayUsagePointData(
                label: timeLabel(for: $0.start, timezone: timezone),
                rangeLabel: timeRangeLabel(start: $0.start, end: $0.end, timezone: timezone),
                totalTokens: $0.totalTokens,
                inputTokens: $0.inputTokens,
                outputTokens: $0.outputTokens,
                cacheReadTokens: $0.cacheReadTokens
            )
        } ?? []
        let visibleBucketCount = snapshot?.actualBucketCount ?? 0
        let fullBucketCount = expectedBucketCount(
            dayKey: dayKey,
            bucket: bucket,
            timezone: timezone
        )
        let bucketSummary = snapshot != nil && fullBucketCount > 0
            ? "\(visibleBucketCount)/\(fullBucketCount) 可见时间桶"
            : nil
        let presentationNote: String?
        if snapshot != nil {
            presentationNote = isToday(dayKey: dayKey, timezone: timezone, referenceDate: referenceDate)
                ? "仅展示有用量时段；Today 不显示未来时间。"
                : "仅展示有用量时段。"
        } else {
            presentationNote = nil
        }

        return ProviderTokenTrendDrilldownData(
            dayKey: dayKey,
            bucketID: bucket.rawValue,
            actualBucketCount: visibleBucketCount,
            fullBucketCount: fullBucketCount,
            rangeDescription: bucket.title,
            bucketSummary: bucketSummary,
            presentationNote: presentationNote,
            points: points,
            availableBuckets: availableBuckets,
            isLoading: isLoading,
            errorMessage: errorMessage,
            freshnessText: snapshot.map {
                "静态快照 · \($0.fetchedAt.formatted(date: .omitted, time: .shortened))"
            } ?? "静态快照 · 手动刷新"
        )
    }

    static func expectedBucketCount(
        dayKey: String,
        bucket: ProviderIntradayBucket,
        timezone: TimeZone = .current
    ) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayKey),
              let end = formatter.calendar.date(byAdding: .day, value: 1, to: start) else {
            return 0
        }

        let seconds: TimeInterval
        switch bucket {
        case .minute15:
            seconds = 15 * 60
        case .minute30:
            seconds = 30 * 60
        case .hour1:
            seconds = 60 * 60
        }
        return Int((end.timeIntervalSince(start) / seconds).rounded())
    }

    static func timeLabel(for date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func timeRangeLabel(start: Date, end: Date, timezone: TimeZone) -> String {
        "\(timeLabel(for: start, timezone: timezone))-\(timeLabel(for: end, timezone: timezone))"
    }

    private static func isToday(dayKey: String, timezone: TimeZone, referenceDate: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: referenceDate) == dayKey
    }

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }
}
