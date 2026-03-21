import SwiftUI

public struct ProviderSidebarStyle {
    public var subtitleColor: Color
    public var headerColor: Color
    public var destructiveColor: Color

    public init(
        subtitleColor: Color? = nil,
        headerColor: Color? = nil,
        destructiveColor: Color? = nil
    ) {
        self.subtitleColor = subtitleColor ?? DesignSystem.Colors.Text.secondary
        self.headerColor = headerColor ?? DesignSystem.Colors.Text.secondary
        self.destructiveColor = destructiveColor ?? DesignSystem.Colors.Status.error
    }

    public static var `default`: ProviderSidebarStyle {
        ProviderSidebarStyle()
    }
}
