import SwiftUI

public struct FormSectionBlockView<Content: View>: View {
    let title: String
    let spacing: CGFloat
    let content: () -> Content

    public init(
        title: String,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            content()
        }
    }
}

public struct FormSecondaryHintText: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
    }
}
