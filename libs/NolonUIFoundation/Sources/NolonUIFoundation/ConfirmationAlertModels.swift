import Foundation

public struct ConfirmationAlertData: Hashable, Sendable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String
    public let isDestructiveConfirm: Bool

    public init(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String,
        isDestructiveConfirm: Bool = false
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructiveConfirm = isDestructiveConfirm
    }
}
