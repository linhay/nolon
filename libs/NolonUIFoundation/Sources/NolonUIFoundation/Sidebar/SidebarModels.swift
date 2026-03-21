import Foundation

public enum SidebarSectionID: String, Codable, Hashable, Sendable, Identifiable {
    case originalVendors
    case integratedVendors
    case projects

    public var id: String { rawValue }
}

public enum SidebarProviderKind: String, Codable, Hashable, Sendable {
    case vendor
    case project
}

public enum SidebarVendorCategory: String, Codable, Hashable, Sendable {
    case original
    case integrated
}

public enum SidebarToolID: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case accounts
    case pluginManagement

    public var id: String { rawValue }
}

public enum SidebarItemID: Hashable, Sendable, Codable {
    case provider(String)
    case tool(SidebarToolID)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw.hasPrefix("provider:") {
            self = .provider(String(raw.dropFirst("provider:".count)))
        } else if let tool = SidebarToolID(rawValue: raw) {
            self = .tool(tool)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported sidebar item id: \(raw)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .provider(providerID):
            try container.encode("provider:\(providerID)")
        case let .tool(tool):
            try container.encode(tool.rawValue)
        }
    }
}

public struct SidebarProviderInput: Hashable, Sendable, Codable, Identifiable {
    public let id: String
    public let kind: SidebarProviderKind
    public let vendorCategory: SidebarVendorCategory?
    public let name: String
    public let subtitle: String
    public let iconName: String
    public let hasDocumentation: Bool

    public init(
        id: String,
        kind: SidebarProviderKind,
        vendorCategory: SidebarVendorCategory?,
        name: String,
        subtitle: String,
        iconName: String,
        hasDocumentation: Bool
    ) {
        self.id = id
        self.kind = kind
        self.vendorCategory = vendorCategory
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
        self.hasDocumentation = hasDocumentation
    }
}

public struct SidebarProviderItem: Hashable, Sendable, Codable, Identifiable {
    public let id: String
    public let kind: SidebarProviderKind
    public let vendorCategory: SidebarVendorCategory?
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let hasDocumentation: Bool

    public init(
        id: String,
        kind: SidebarProviderKind,
        vendorCategory: SidebarVendorCategory?,
        title: String,
        subtitle: String,
        iconName: String,
        hasDocumentation: Bool
    ) {
        self.id = id
        self.kind = kind
        self.vendorCategory = vendorCategory
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.hasDocumentation = hasDocumentation
    }
}

public struct SidebarToolItem: Hashable, Sendable, Codable, Identifiable {
    public let id: SidebarToolID
    public let titleKey: String
    public let fallbackTitle: String
    public let systemImage: String

    public init(id: SidebarToolID, titleKey: String, fallbackTitle: String, systemImage: String) {
        self.id = id
        self.titleKey = titleKey
        self.fallbackTitle = fallbackTitle
        self.systemImage = systemImage
    }

    public static let `default`: [SidebarToolItem] = [
        SidebarToolItem(
            id: .accounts,
            titleKey: "sidebar.tools.accounts",
            fallbackTitle: "Accounts",
            systemImage: "person.crop.circle.badge.checkmark"
        ),
        SidebarToolItem(
            id: .pluginManagement,
            titleKey: "sidebar.plugins.management",
            fallbackTitle: "Plugin Management",
            systemImage: "puzzlepiece.extension"
        )
    ]
}

public struct SidebarSection: Hashable, Sendable, Codable, Identifiable {
    public let id: SidebarSectionID
    public let titleKey: String
    public let fallbackTitle: String
    public let items: [SidebarProviderItem]

    public init(id: SidebarSectionID, titleKey: String, fallbackTitle: String, items: [SidebarProviderItem]) {
        self.id = id
        self.titleKey = titleKey
        self.fallbackTitle = fallbackTitle
        self.items = items
    }
}
