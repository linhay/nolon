import SwiftUI

public struct SidebarHeaderScaffold<Content: View>: View {
    let showsSheetHeader: Bool
    let sheetTitle: String
    let sidebarTitle: String?
    let content: () -> Content

    public init(
        showsSheetHeader: Bool,
        sheetTitle: String,
        sidebarTitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsSheetHeader = showsSheetHeader
        self.sheetTitle = sheetTitle
        self.sidebarTitle = sidebarTitle
        self.content = content
    }

    public var body: some View {
        if showsSheetHeader {
            SheetHeaderSection(title: sheetTitle) {
                EmptyView()
            } content: {
                content()
            }
        } else if let sidebarTitle, !sidebarTitle.isEmpty {
            VStack(spacing: 0) {
                SidebarTitleHeaderRowView(title: sidebarTitle)
                content()
            }
        } else {
            content()
        }
    }
}
