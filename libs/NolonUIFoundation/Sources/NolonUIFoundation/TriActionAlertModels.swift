import Foundation

public struct TriActionAlertData: Hashable, Sendable {
    public let title: String
    public let message: String
    public let destructiveTitle: String
    public let secondaryTitle: String
    public let cancelTitle: String

    public init(
        title: String,
        message: String,
        destructiveTitle: String,
        secondaryTitle: String,
        cancelTitle: String
    ) {
        self.title = title
        self.message = message
        self.destructiveTitle = destructiveTitle
        self.secondaryTitle = secondaryTitle
        self.cancelTitle = cancelTitle
    }
}
