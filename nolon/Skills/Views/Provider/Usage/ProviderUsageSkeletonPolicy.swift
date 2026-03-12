import ProviderCatalog

enum ProviderUsageSkeletonPolicy {
    static func genericCardCount(for provider: Provider) -> Int {
        switch provider.templateId {
        case ProviderTemplate.gemini.rawValue:
            return 2
        default:
            return 1
        }
    }

    static let codexCardCount = 3
    static let tokenTrendSummaryCount = 4
    static let tokenTrendChartBarCount = 7
}
