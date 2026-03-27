import SwiftUI

struct EllipsisMenuButton<Content: View>: View {
    let iconSize: CGFloat?
    let content: () -> Content

    init(
        iconSize: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.iconSize = iconSize
        self.content = content
    }

    var body: some View {
        Menu {
            content()
        } label: {
            if let iconSize {
                Image(systemName: "ellipsis")
                    .dsIconButton(size: iconSize)
            } else {
                Image(systemName: "ellipsis")
                    .dsIconButton()
            }
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
