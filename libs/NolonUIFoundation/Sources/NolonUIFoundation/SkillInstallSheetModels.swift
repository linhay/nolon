import Foundation

public struct SkillInstallProviderOption: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let iconName: String?

    public init(id: String, name: String, iconName: String? = nil) {
        self.id = id
        self.name = name
        self.iconName = iconName
    }
}

public struct SkillInstallSheetData: Hashable, Sendable, Codable {
    public let skillName: String
    public let providers: [SkillInstallProviderOption]

    public init(skillName: String, providers: [SkillInstallProviderOption]) {
        self.skillName = skillName
        self.providers = providers
    }
}
