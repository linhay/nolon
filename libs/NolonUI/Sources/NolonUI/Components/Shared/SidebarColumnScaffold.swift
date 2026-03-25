import SwiftUI

struct SidebarColumnScaffold<Content: View>: View {
    @State private var viewModel = SidebarColumnScaffoldViewModel()
    let title: String
    let showsHeader: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        showsHeader: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsHeader = showsHeader
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                SidebarColumnHeader(title: title)
            }
            content
        }
        .navigationSplitViewColumnWidth(
            min: SidebarColumnMetrics.columnMinWidth,
            ideal: SidebarColumnMetrics.columnIdealWidth,
            max: SidebarColumnMetrics.columnMaxWidth
        )
    }
}
