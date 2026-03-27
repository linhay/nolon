import Foundation

public struct SelectableSettingsRowData: Sendable {
    public let title: String
    public let leadingSystemImage: String?
    public let isSelected: Bool
    public let contentPadding: Double
    public let showsSelectionShadow: Bool

    public init(
        title: String,
        leadingSystemImage: String? = nil,
        isSelected: Bool,
        contentPadding: Double = 16,
        showsSelectionShadow: Bool = false
    ) {
        self.title = title
        self.leadingSystemImage = leadingSystemImage
        self.isSelected = isSelected
        self.contentPadding = contentPadding
        self.showsSelectionShadow = showsSelectionShadow
    }
}
