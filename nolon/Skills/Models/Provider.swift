import Foundation

/// Represents a provider for installing skills
public struct Provider: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var skillsPath: String
    public var workflowPath: String
    public var iconName: String
    public var installMethod: SkillInstallationMethod
    
    /// Template ID if created from a built-in template
    public var templateId: String?
    
    public var displayName: String { name }
    
    public var pathURL: URL {
        URL(fileURLWithPath: skillsPath)
    }
    
    public var documentationURL: URL?

    public init(
        id: String = UUID().uuidString,
        name: String,
        skillsPath: String,
        workflowPath: String,
        iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink,
        templateId: String? = nil,
        documentationURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.skillsPath = skillsPath
        self.workflowPath = workflowPath
        self.iconName = iconName
        self.installMethod = installMethod
        self.templateId = templateId
        self.documentationURL = documentationURL
    }
}
