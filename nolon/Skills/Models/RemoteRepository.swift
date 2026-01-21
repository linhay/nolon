import Foundation

/// Template types for remote repositories
public enum RepositoryTemplate: String, CaseIterable, Identifiable, Codable, Sendable {
    case clawdhub
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .clawdhub: return "Clawdhub"
        case .custom: return "Custom Repository"
        }
    }

    public var iconName: String {
        switch self {
        case .clawdhub: return "cloud"
        case .custom: return "server.rack"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .clawdhub: return "https://clawdhub.com"
        case .custom: return ""
        }
    }

    public var defaultName: String {
        switch self {
        case .clawdhub: return "Clawdhub"
        case .custom: return ""
        }
    }

    /// Whether this template allows editing the base URL
    public var isURLEditable: Bool {
        switch self {
        case .clawdhub: return false
        case .custom: return true
        }
    }

    /// Create a repository from this template
    public func createRepository(name: String? = nil, baseURL: String? = nil) -> RemoteRepository {
        RemoteRepository(
            name: name ?? defaultName,
            baseURL: baseURL ?? defaultBaseURL,
            iconName: iconName,
            templateType: self,
            isBuiltIn: self == .clawdhub
        )
    }
}

/// Represents a remote skill repository (e.g., Clawdhub)
public struct RemoteRepository: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var baseURL: String
    public var iconName: String
    public var templateType: RepositoryTemplate
    public var isBuiltIn: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        baseURL: String,
        iconName: String = "cloud",
        templateType: RepositoryTemplate = .custom,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.iconName = iconName
        self.templateType = templateType
        self.isBuiltIn = isBuiltIn
    }

    /// Built-in Clawdhub repository
    public static let clawdhub = RepositoryTemplate.clawdhub.createRepository()
}
