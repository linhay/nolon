import Foundation

public struct CodexAdvancedMultiAgentToggleRowData: Sendable {
    public let labelText: String
    public let isEnabled: Bool

    public init(labelText: String, isEnabled: Bool) {
        self.labelText = labelText
        self.isEnabled = isEnabled
    }
}

public struct CodexAdvancedMultiAgentStatusRowData: Sendable {
    public let isEnabled: Bool
    public let messageText: String

    public init(isEnabled: Bool, messageText: String) {
        self.isEnabled = isEnabled
        self.messageText = messageText
    }
}
