import Foundation

/// Represents a custom user-defined provider
public struct CustomProvider: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var path: String
    public var iconName: String
    
    public init(id: String = UUID().uuidString, name: String, path: String, iconName: String = "folder") {
        self.id = id
        self.name = name
        self.path = path
        self.iconName = iconName
    }
    
    public var displayName: String { name }
    
    public var pathURL: URL {
        URL(fileURLWithPath: path)
    }
}
