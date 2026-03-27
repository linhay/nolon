import SwiftUI

public struct NavigationTopContentScaffold<Top: View, Content: View>: View {
    let navigationTitle: String
    let top: () -> Top
    let content: () -> Content

    public init(
        navigationTitle: String = NSLocalizedString("provider.title", value: "Provider Skills", comment: "Provider skills title"),
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.navigationTitle = navigationTitle
        self.top = top
        self.content = content
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                top()
                content()
            }
            .navigationTitle(navigationTitle)
        }
    }
}
