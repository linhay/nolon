import Foundation

public struct CodexAdvancedStatTileData: Hashable, Sendable {
    public let title: String
    public let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

public struct CodexAdvancedPathInfoRowData: Hashable, Sendable {
    public let iconName: String
    public let text: String

    public init(iconName: String, text: String) {
        self.iconName = iconName
        self.text = text
    }
}
