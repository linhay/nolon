import SwiftUI
import ProviderUsage
import NolonUI
import NolonUIFoundation

struct ProviderTokenTrendSection: View, DebugPageLocatable {
    let snapshot: ProviderTokenTrendSnapshot?
    let isLoading: Bool
    let errorMessage: String?
    let range: ProviderUsageEngine.TokenTrendRange
    let onRangeChange: (ProviderUsageEngine.TokenTrendRange) -> Void
    let onRefresh: () -> Void
    let debugPageMarkerItems: [PageMarkerItem]

    init(
        snapshot: ProviderTokenTrendSnapshot?,
        isLoading: Bool,
        errorMessage: String?,
        range: ProviderUsageEngine.TokenTrendRange,
        onRangeChange: @escaping (ProviderUsageEngine.TokenTrendRange) -> Void,
        onRefresh: @escaping () -> Void,
        debugPageMarkerItems: [PageMarkerItem] = []
    ) {
        self.snapshot = snapshot
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.range = range
        self.onRangeChange = onRangeChange
        self.onRefresh = onRefresh
        self.debugPageMarkerItems = debugPageMarkerItems
    }

    var body: some View {
        NolonUI.ProviderTokenTrendSectionView(
            data: sectionData,
            onRangeChange: { rangeID in
                guard let next = ProviderUsageEngine.TokenTrendRange(rawValue: rangeID) else { return }
                onRangeChange(next)
            },
            onRefresh: onRefresh
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
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedRangeID: range.rawValue,
            availableRanges: ProviderUsageEngine.TokenTrendRange.allCases.map {
                .init(id: $0.rawValue, title: $0.title)
            }
        )
    }
}
