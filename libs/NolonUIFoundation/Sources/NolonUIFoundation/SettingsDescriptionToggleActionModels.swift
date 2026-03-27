import Foundation

public struct SettingsDescriptionToggleActionData: Sendable {
    public let description: String
    public let toggleTitle: String
    public let actionCard: SettingsActionCardData
    public let resultMessage: String?
    public let errorMessage: String?

    public init(
        description: String,
        toggleTitle: String,
        actionCard: SettingsActionCardData,
        resultMessage: String?,
        errorMessage: String?
    ) {
        self.description = description
        self.toggleTitle = toggleTitle
        self.actionCard = actionCard
        self.resultMessage = resultMessage
        self.errorMessage = errorMessage
    }
}
