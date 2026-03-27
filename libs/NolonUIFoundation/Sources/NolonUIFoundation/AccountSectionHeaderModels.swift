import Foundation

public struct AccountSectionHeaderData: Sendable {
    public enum SectionTone: Sendable {
        case primary
        case secondary
        case success
    }

    public struct Section: Sendable {
        public let shortLabel: String
        public let title: String
        public let accountCountText: String
        public let tone: SectionTone

        public init(
            shortLabel: String,
            title: String,
            accountCountText: String,
            tone: SectionTone
        ) {
            self.shortLabel = shortLabel
            self.title = title
            self.accountCountText = accountCountText
            self.tone = tone
        }
    }

    public struct Provider: Sendable {
        public let name: String
        public let logoName: String?

        public init(name: String, logoName: String?) {
            self.name = name
            self.logoName = logoName
        }
    }

    public enum Style: Sendable {
        case section(Section)
        case provider(Provider)
    }

    public let style: Style

    public init(style: Style) {
        self.style = style
    }
}
