import Foundation

public struct AboutSettingsData: Sendable {
    public let appName: String
    public let version: String?
    public let description: String
    public let checkUpdatesTitle: String

    public init(
        appName: String,
        version: String?,
        description: String,
        checkUpdatesTitle: String
    ) {
        self.appName = appName
        self.version = version
        self.description = description
        self.checkUpdatesTitle = checkUpdatesTitle
    }
}
