import Foundation

public struct MessageAlertData: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public static func migrate(message: String) -> Self {
        .init(
            title: NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate"),
            message: message
        )
    }

    public static func update(message: String) -> Self {
        .init(
            title: NSLocalizedString("action.update", value: "Update", comment: "Update"),
            message: message
        )
    }
}
