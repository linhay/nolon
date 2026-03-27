import Foundation

public struct DestructiveConfirmationDialogData: Hashable, Sendable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String

    public init(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String = NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
    }
}
