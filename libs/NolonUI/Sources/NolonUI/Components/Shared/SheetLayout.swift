import SwiftUI

public enum SheetLayout {
    public static let horizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let contentVerticalPadding: CGFloat = DesignSystem.Metrics.paddingL
    public static let contentBottomPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let footerHorizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let footerVerticalPadding: CGFloat = DesignSystem.Metrics.paddingL
}

public struct SheetDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .background(DesignSystem.Colors.Component.separator.opacity(0.25))
    }
}

public extension View {
    @ViewBuilder
    func sheetScrollContentPadding() -> some View {
        self
            .padding(.horizontal, SheetLayout.horizontalPadding)
            .padding(.top, SheetLayout.contentVerticalPadding)
            .padding(.bottom, SheetLayout.contentBottomPadding)
    }
}
