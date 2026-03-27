import SwiftUI

public struct SheetHeaderSection<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: () -> Trailing
    let content: () -> Content

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title, subtitle: subtitle, trailing: trailing)
            SheetDivider()
            content()
        }
    }
}
