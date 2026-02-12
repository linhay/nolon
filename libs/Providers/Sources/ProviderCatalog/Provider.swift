import Foundation
import STFilePath

public enum ProviderKind: String, Codable, Sendable {
    /// Vendor-level provider (predefined locations; typically under the user's home directory).
    case vendor
    /// Project-level provider (paths are derived from a user-selected project root).
    case project
}

/// Represents a provider for installing skills.
public struct Provider: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var kind: ProviderKind
    public var name: String
    /// Only for `.project` providers: the user-selected project root path.
    public var projectRootPath: String?
    public var defaultSkillsPath: String
    public var workflowPath: String
    /// OpenCode uses "command files" instead of "workflows".
    /// For backward compatibility, `workflowPath` may still point to the commands directory.
    public var commandPath: String?
    public var iconName: String
    public var installMethod: SkillInstallationMethod

    /// Template ID if created from a built-in template.
    public var templateId: String?

    /// Additional global paths to scan for skills (penetration reading).
    public var additionalSkillsPaths: [String]?

    public var displayName: String { name }

    public var isVendor: Bool { kind == .vendor }
    public var isProject: Bool { kind == .project }
    public var canEditPaths: Bool { kind == .project }

    public var path: STPath {
        STPath(defaultSkillsPath)
    }

    public var additionalPaths: [STPath] {
        additionalSkillsPaths?.map(STPath.init) ?? []
    }

    public var pathURL: URL {
        path.url
    }

    public var additionalPathURLs: [URL] {
        additionalPaths.map(\.url)
    }

    public var documentationURL: URL?

    public init(
        id: String = UUID().uuidString,
        kind: ProviderKind = .vendor,
        name: String,
        projectRootPath: String? = nil,
        defaultSkillsPath: String,
        workflowPath: String,
        commandPath: String? = nil,
        iconName: String = "folder",
        installMethod: SkillInstallationMethod = .symlink,
        templateId: String? = nil,
        additionalSkillsPaths: [String]? = nil,
        documentationURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.projectRootPath = projectRootPath
        self.defaultSkillsPath = defaultSkillsPath
        self.workflowPath = workflowPath
        self.commandPath = commandPath
        self.iconName = iconName
        self.installMethod = installMethod
        self.templateId = templateId
        self.additionalSkillsPaths = additionalSkillsPaths
        self.documentationURL = documentationURL
    }

    // MARK: - Codable migration

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case name
        case projectRootPath
        case defaultSkillsPath
        case workflowPath
        case commandPath
        case iconName
        case installMethod
        case templateId
        case additionalSkillsPaths
        case documentationURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        kind = (try? container.decode(ProviderKind.self, forKey: .kind)) ?? .vendor
        name = try container.decode(String.self, forKey: .name)
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath)
        defaultSkillsPath = try container.decode(String.self, forKey: .defaultSkillsPath)
        workflowPath = try container.decode(String.self, forKey: .workflowPath)
        commandPath = try container.decodeIfPresent(String.self, forKey: .commandPath)
        iconName = try container.decode(String.self, forKey: .iconName)
        installMethod = try container.decode(SkillInstallationMethod.self, forKey: .installMethod)
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        additionalSkillsPaths = try container.decodeIfPresent([String].self, forKey: .additionalSkillsPaths)
        documentationURL = try container.decodeIfPresent(URL.self, forKey: .documentationURL)
    }
}
