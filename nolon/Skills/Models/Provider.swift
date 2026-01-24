import Foundation

/// Represents a provider for installing skills
public struct Provider: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var defaultSkillsPath: String
    public var workflowPath: String
    public var iconName: String
    public var installMethod: SkillInstallationMethod
    
    /// Template ID if created from a built-in template
    public var templateId: String?
    
    /// Additional global paths to scan for skills (penetration reading)
    public var additionalSkillsPaths: [String]?
    
    public var displayName: String { name }
    
    public var pathURL: URL {
        URL(fileURLWithPath: defaultSkillsPath)
    }
    
    public var additionalPathURLs: [URL] {
        additionalSkillsPaths?.map { URL(fileURLWithPath: $0) } ?? []
    }
    
    public var documentationURL: URL?

    public init(
        id: String = UUID().uuidString,
        name: String,
        defaultSkillsPath: String,
        workflowPath: String,
        iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink,
        templateId: String? = nil,
        additionalSkillsPaths: [String]? = nil,
        documentationURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultSkillsPath = defaultSkillsPath
        self.workflowPath = workflowPath
        self.iconName = iconName
        self.installMethod = installMethod
        self.templateId = templateId
        self.additionalSkillsPaths = additionalSkillsPaths
        self.documentationURL = documentationURL
    }
}
