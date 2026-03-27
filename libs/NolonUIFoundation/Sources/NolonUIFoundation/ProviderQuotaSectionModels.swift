import Foundation

public struct ProviderQuotaSectionData: Sendable {
    public struct WindowRow: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let remainingPercent: Double
        public let percentText: String
        public let resetText: String?

        public init(
            id: String,
            title: String,
            remainingPercent: Double,
            percentText: String,
            resetText: String?
        ) {
            self.id = id
            self.title = title
            self.remainingPercent = remainingPercent
            self.percentText = percentText
            self.resetText = resetText
        }
    }

    public let accountTitle: String
    public let statusPercent: Double
    public let rows: [WindowRow]
    public let creditsText: String?
    public let planText: String?
    public let syncText: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let showsEmptyState: Bool
    public let usesCardChrome: Bool
    public let showsHeader: Bool

    public init(
        accountTitle: String,
        statusPercent: Double,
        rows: [WindowRow],
        creditsText: String?,
        planText: String?,
        syncText: String?,
        isLoading: Bool,
        errorMessage: String?,
        showsEmptyState: Bool,
        usesCardChrome: Bool,
        showsHeader: Bool
    ) {
        self.accountTitle = accountTitle
        self.statusPercent = statusPercent
        self.rows = rows
        self.creditsText = creditsText
        self.planText = planText
        self.syncText = syncText
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.showsEmptyState = showsEmptyState
        self.usesCardChrome = usesCardChrome
        self.showsHeader = showsHeader
    }
}
