import SwiftUI

public struct ProviderCardTemplate<
    HeaderContent: View,
    BodyContent: View,
    FooterContent: View,
    ActionContent: View,
    ContextMenuContent: View
>: View {
    private let minHeight: CGFloat
    private let showsActionDivider: Bool
    private let onTap: (() -> Void)?
    private let headerContent: () -> HeaderContent
    private let bodyContent: () -> BodyContent
    private let footerContent: () -> FooterContent
    private let actionContent: () -> ActionContent
    private let contextMenuContent: () -> ContextMenuContent

    public init(
        minHeight: CGFloat = 140,
        showsActionDivider: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder bodyContent: @escaping () -> BodyContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent,
        @ViewBuilder actionContent: @escaping () -> ActionContent,
        @ViewBuilder contextMenuContent: @escaping () -> ContextMenuContent
    ) {
        self.minHeight = minHeight
        self.showsActionDivider = showsActionDivider
        self.onTap = onTap
        self.headerContent = headerContent
        self.bodyContent = bodyContent
        self.footerContent = footerContent
        self.actionContent = actionContent
        self.contextMenuContent = contextMenuContent
    }

    public var body: some View {
        if let onTap {
            cardBody.onTapGesture(perform: onTap)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
            headerContent()
            bodyContent()
            footerContent()
            if showsActionDivider {
                Divider()
            }
            actionContent()
        }
        .padding(DesignSystem.Metrics.spacingL)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .providerTabCardStyle()
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuContent()
        }
    }
}
