import Foundation

public struct AccountTrendSampleData: Sendable, Identifiable {
    public let id: String
    public let label: String
    public let heightRatio: Double
    public let opacity: Double

    public init(id: String, label: String, heightRatio: Double, opacity: Double) {
        self.id = id
        self.label = label
        self.heightRatio = heightRatio
        self.opacity = opacity
    }
}

public struct AccountTrendPanelData: Sendable {
    public struct WindowOption: Sendable, Identifiable {
        public let id: String
        public let title: String
        public let isSelected: Bool

        public init(id: String, title: String, isSelected: Bool) {
            self.id = id
            self.title = title
            self.isSelected = isSelected
        }
    }

    public let title: String
    public let windowOptions: [WindowOption]
    public let samples: [AccountTrendSampleData]

    public init(
        title: String = NSLocalizedString(
            "accounts.dashboard.trend",
            value: "Aggregated Usage Trend",
            comment: "Aggregated trend panel"
        ),
        windowOptions: [WindowOption],
        samples: [AccountTrendSampleData]
    ) {
        self.title = title
        self.windowOptions = windowOptions
        self.samples = samples
    }
}

public struct AccountProviderRankingItemData: Sendable, Identifiable {
    public enum Tone: Sendable {
        case primary
        case secondary
        case success
        case warning
    }

    public let id: String
    public let name: String
    public let ratio: Double
    public let valueText: String
    public let tone: Tone

    public init(
        id: String,
        name: String,
        ratio: Double,
        valueText: String,
        tone: Tone
    ) {
        self.id = id
        self.name = name
        self.ratio = ratio
        self.valueText = valueText
        self.tone = tone
    }
}

public struct AccountRankingPanelData: Sendable {
    public let title: String
    public let items: [AccountProviderRankingItemData]

    public init(
        title: String = NSLocalizedString(
            "accounts.dashboard.ranking",
            value: "Provider Ranking",
            comment: "Provider ranking panel"
        ),
        items: [AccountProviderRankingItemData]
    ) {
        self.title = title
        self.items = items
    }
}
