import Foundation

/// Represents a provider for installing skills
public struct Provider: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var path: String
    public var iconName: String
    public var installMethod: SkillInstallationMethod
    
    /// Template ID if created from a built-in template
    public var templateId: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink,
        templateId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.iconName = iconName
        self.installMethod = installMethod
        self.templateId = templateId
    }
    
    public var displayName: String { name }
    
    public var pathURL: URL {
        URL(fileURLWithPath: path)
    }
}
