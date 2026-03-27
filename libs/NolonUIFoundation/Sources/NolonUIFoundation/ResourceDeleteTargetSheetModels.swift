import Foundation

public struct ResourceDeleteTargetSheetData: Sendable {
    public let resourceName: String
    public let resourceTypeName: String
    public let providers: [SkillInstallProviderOption]
    public let preferredProviderID: String?

    public init(
        resourceName: String,
        resourceTypeName: String,
        providers: [SkillInstallProviderOption],
        preferredProviderID: String?
    ) {
        self.resourceName = resourceName
        self.resourceTypeName = resourceTypeName
        self.providers = providers
        self.preferredProviderID = preferredProviderID
    }
}
