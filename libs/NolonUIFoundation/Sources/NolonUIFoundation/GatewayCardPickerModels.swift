import Foundation
import CoreGraphics

public struct GatewayCardPickerItemData: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let countText: String

    public init(
        id: UUID,
        title: String,
        countText: String
    ) {
        self.id = id
        self.title = title
        self.countText = countText
    }
}

public struct GatewayCardPickerSheetData: Sendable {
    public let title: String
    public let subtitle: String?
    public let items: [GatewayCardPickerItemData]
    public let cancelTitle: String
    public let width: CGFloat
    public let height: CGFloat
    public let minListHeight: CGFloat

    public init(
        title: String,
        subtitle: String? = nil,
        items: [GatewayCardPickerItemData],
        cancelTitle: String,
        width: CGFloat = 360,
        height: CGFloat = 320,
        minListHeight: CGFloat = 200
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.cancelTitle = cancelTitle
        self.width = width
        self.height = height
        self.minListHeight = minListHeight
    }
}
