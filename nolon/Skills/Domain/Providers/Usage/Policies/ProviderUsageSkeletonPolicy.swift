import ProviderCatalog

enum ProviderUsageSkeletonPolicy {
    static func genericCardCount(for _: Provider) -> Int {
        3
    }
    static let tokenTrendSummaryCount = 4
    static let tokenTrendChartBarCount = 7
    static let tokenTrendTableRowCount = 5
}
