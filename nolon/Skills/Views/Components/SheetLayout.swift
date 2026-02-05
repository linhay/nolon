import SwiftUI

enum SheetLayout {
    static let horizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    static let contentVerticalPadding: CGFloat = DesignSystem.Metrics.paddingL
    static let contentBottomPadding: CGFloat = DesignSystem.Metrics.paddingXL
    static let footerHorizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    static let footerVerticalPadding: CGFloat = DesignSystem.Metrics.paddingL
}

struct SheetDivider: View {
    var body: some View {
        Divider()
            .background(DesignSystem.Colors.Component.separator.opacity(0.25))
    }
}

extension View {
    @ViewBuilder
    func sheetScrollContentPadding() -> some View {
        if #available(macOS 14.0, *) {
            self
                .scrollContentPadding(.horizontal, SheetLayout.horizontalPadding)
                .scrollContentPadding(.top, SheetLayout.contentVerticalPadding)
                .scrollContentPadding(.bottom, SheetLayout.contentBottomPadding)
        } else {
            self
                .padding(.horizontal, SheetLayout.horizontalPadding)
                .padding(.top, SheetLayout.contentVerticalPadding)
                .padding(.bottom, SheetLayout.contentBottomPadding)
        }
    }
}
