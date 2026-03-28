import Foundation

public struct SidebarSelectionKey: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func provider(_ providerID: String) -> SidebarSelectionKey {
        SidebarSelectionKey(rawValue: "provider:\(providerID)")
    }

    public static let nolon = SidebarSelectionKey(rawValue: "nolon")
    public static let accounts = SidebarSelectionKey(rawValue: "accounts")
    public static let pluginManagement = SidebarSelectionKey(rawValue: "pluginManagement")

    public var itemID: SidebarItemID? {
        if rawValue.hasPrefix("provider:") {
            return .provider(String(rawValue.dropFirst("provider:".count)))
        }
        if let toolID = SidebarToolID(rawValue: rawValue) {
            return .tool(toolID)
        }
        return nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
