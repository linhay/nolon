import Foundation

/// Protocol for all remote content types (Skills, Workflows, MCPs)
public protocol RemoteItem: Identifiable, Hashable, Sendable {
    var id: String { get }
    var slug: String { get }
    var displayName: String { get }
    var summary: String? { get }
    var updatedAt: TimeInterval { get }
    var localPath: String? { get }
}

/// Remote content type discriminator
public enum RemoteContentType: String, Codable, CaseIterable, Sendable {
    case skill = "skills"
    case workflow = "workflows"
    case mcp = "mcps"
    
    public var apiPath: String {
        switch self {
        case .skill: return "skills"
        case .workflow: return "workflows"
        case .mcp: return "mcps"
        }
    }
    
    public var displayName: String {
        switch self {
        case .skill: return "Skills"
        case .workflow: return "Workflows"
        case .mcp: return "MCPs"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .skill: return "doc.text.fill"
        case .workflow: return "arrow.triangle.branch"
        case .mcp: return "server.rack"
        }
    }
}
