import Foundation

public struct QuickSwitchUsageWindowData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let remainingPercent: Double

    public init(
        id: String,
        title: String,
        remainingPercent: Double
    ) {
        self.id = id
        self.title = title
        self.remainingPercent = remainingPercent
    }
}

public struct QuickSwitchAccountCardData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let isActive: Bool
    public let isExhausted: Bool
    public let usageWindows: [QuickSwitchUsageWindowData]
    public let activeBadgeTitle: String

    public init(
        id: String,
        title: String,
        detail: String?,
        isActive: Bool,
        isExhausted: Bool,
        usageWindows: [QuickSwitchUsageWindowData],
        activeBadgeTitle: String = NSLocalizedString(
            "quickswitch.account.active_badge",
            value: "ACTIVE",
            comment: "Quick switch active badge title"
        )
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isActive = isActive
        self.isExhausted = isExhausted
        self.usageWindows = usageWindows
        self.activeBadgeTitle = activeBadgeTitle
    }
}
