import SwiftUI

public struct WindowEmptyStateScaffold<Content: View>: View {
    let hasContent: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let content: () -> Content

    public init(
        hasContent: Bool,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hasContent = hasContent
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.content = content
    }

    public static func resourceCenterEmptyState(
        hasContent: Bool,
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> Self {
        Self(
            hasContent: hasContent,
            emptyTitle: NSLocalizedString(
                "resource.center.empty.title",
                value: "No Resource Center Context",
                comment: "Resource center empty title"
            ),
            emptySystemImage: "tray",
            emptyDescription: NSLocalizedString(
                "resource.center.empty.desc",
                value: "Open Resource Center from toolbar or provider view.",
                comment: "Resource center empty description"
            ),
            minWidth: minWidth,
            minHeight: minHeight,
            content: content
        )
    }

    public static func skillDetailEmptyState(
        hasContent: Bool,
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> Self {
        Self(
            hasContent: hasContent,
            emptyTitle: NSLocalizedString(
                "detail.skill.empty.title",
                value: "No Skill Selected",
                comment: "Skill detail empty title"
            ),
            emptySystemImage: "doc.text.magnifyingglass",
            emptyDescription: NSLocalizedString(
                "detail.skill.empty.desc",
                value: "Select a skill to view details.",
                comment: "Skill detail empty description"
            ),
            minWidth: minWidth,
            minHeight: minHeight,
            content: content
        )
    }

    public var body: some View {
        EmptyStateScaffold(
            isEmpty: !hasContent,
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription
        ) {
            if hasContent {
                content()
            } else {
                EmptyView()
            }
        }
        .frame(minWidth: minWidth, minHeight: minHeight)
    }
}
