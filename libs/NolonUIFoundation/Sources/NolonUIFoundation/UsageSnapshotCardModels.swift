import Foundation

public struct UsageSnapshotCardData: Sendable {
    public struct Header: Sendable {
        public let displayName: String
        public let providerLabel: String
        public let identityLine: String?
        public let accountLine: String?
        public let planLine: String?

        public init(
            displayName: String,
            providerLabel: String,
            identityLine: String?,
            accountLine: String?,
            planLine: String?
        ) {
            self.displayName = displayName
            self.providerLabel = providerLabel
            self.identityLine = identityLine
            self.accountLine = accountLine
            self.planLine = planLine
        }
    }

    public enum Body: Sendable {
        case success(footerItems: [String])
        case error(message: String, diagnostic: String?, hints: [String])
    }

    public let header: Header
    public let body: Body

    public init(header: Header, body: Body) {
        self.header = header
        self.body = body
    }
}
