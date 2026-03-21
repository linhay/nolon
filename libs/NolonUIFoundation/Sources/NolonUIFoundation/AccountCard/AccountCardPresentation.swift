import Foundation

public enum AccountCardSelectionStyle: String, Codable, Hashable, Sendable {
    case neutral
    case active
    case pending
    case selected
}

public struct AccountCardPresentation: Codable, Hashable, Sendable {
    public let selectionStyle: AccountCardSelectionStyle
    public let showsSelectionBadge: Bool

    public init(selectionStyle: AccountCardSelectionStyle, showsSelectionBadge: Bool) {
        self.selectionStyle = selectionStyle
        self.showsSelectionBadge = showsSelectionBadge
    }

    public static let neutral = AccountCardPresentation(selectionStyle: .neutral, showsSelectionBadge: false)
    public static let active = AccountCardPresentation(selectionStyle: .active, showsSelectionBadge: false)
    public static let pending = AccountCardPresentation(selectionStyle: .pending, showsSelectionBadge: false)
    public static let selected = AccountCardPresentation(selectionStyle: .selected, showsSelectionBadge: false)

    public static func claude(isActive: Bool) -> AccountCardPresentation {
        AccountCardPresentation(
            selectionStyle: isActive ? .active : .neutral,
            showsSelectionBadge: false
        )
    }

    public static func codex(
        isActive: Bool,
        isPending: Bool,
        isBatchSelected: Bool,
        selectableAccountCount: Int
    ) -> AccountCardPresentation {
        if isActive {
            return .active
        }
        if isPending {
            return .pending
        }
        if isBatchSelected, selectableAccountCount > 1 {
            return AccountCardPresentation(selectionStyle: .selected, showsSelectionBadge: true)
        }
        return .neutral
    }
}

public enum AccountSummaryCardBadgeTone: String, Codable, Hashable, Sendable {
    case neutral
    case active
    case warning
}

public struct AccountSummaryCardBadgeModel: Codable, Hashable, Sendable {
    public let text: String
    public let tone: AccountSummaryCardBadgeTone

    public init(text: String, tone: AccountSummaryCardBadgeTone) {
        self.text = text
        self.tone = tone
    }
}

public struct AccountSummaryCardHeaderModel: Codable, Hashable, Sendable {
    public let eyebrow: String?
    public let title: String
    public let subtitle: String?
    public let meta: String?
    public let badge: AccountSummaryCardBadgeModel?

    public init(
        eyebrow: String?,
        title: String,
        subtitle: String?,
        meta: String?,
        badge: AccountSummaryCardBadgeModel?
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.meta = meta
        self.badge = badge
    }
}
