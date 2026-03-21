import SwiftUI

struct SidebarColumnScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            SidebarColumnHeader(title: title)
            content
        }
        .navigationSplitViewColumnWidth(
            min: SidebarColumnMetrics.columnMinWidth,
            ideal: SidebarColumnMetrics.columnIdealWidth,
            max: SidebarColumnMetrics.columnMaxWidth
        )
    }
}
