import Foundation

public struct CodexPathStatusBarData: Sendable {
    public let title: String
    public let statusText: String?
    public let configureTitle: String
    public let checkTitle: String
    public let isCheckingPath: Bool
    public let isConfiguringPath: Bool

    public init(
        title: String,
        statusText: String?,
        configureTitle: String,
        checkTitle: String,
        isCheckingPath: Bool,
        isConfiguringPath: Bool
    ) {
        self.title = title
        self.statusText = statusText
        self.configureTitle = configureTitle
        self.checkTitle = checkTitle
        self.isCheckingPath = isCheckingPath
        self.isConfiguringPath = isConfiguringPath
    }
}
