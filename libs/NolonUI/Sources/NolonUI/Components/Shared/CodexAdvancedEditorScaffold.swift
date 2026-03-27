import SwiftUI

public struct CodexAdvancedEditorScaffold<Content: View>: View {
    let title: String
    let content: () -> Content

    public init(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 680, minHeight: 420)
    }
}
