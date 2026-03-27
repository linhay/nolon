import SwiftUI
import NolonUIFoundation

public struct RuleCardView<ExtraContextMenu: View>: View {
    @State private var viewModel = RuleCardViewViewModel()
    private let rule: RuleInfo
    private let searchText: String
    private let onReveal: () -> Void
    private let onDelete: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: (RuleInfo) -> ExtraContextMenu

    private let descriptionHeight: CGFloat = 44

    public init(
        rule: RuleInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping (RuleInfo) -> ExtraContextMenu
    ) {
        self.rule = rule
        self.searchText = searchText
        self.onReveal = onReveal
        self.onDelete = onDelete
        self.onTap = onTap
        self.extraContextMenu = extraContextMenu
    }

    public init(
        rule: RuleInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            rule: rule,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap,
            extraContextMenu: { _ in EmptyView() }
        )
    }

    public var body: some View {
        ProviderCardTemplate(
            minHeight: 140,
            onTap: onTap
        ) {
            ProviderCardTitleMenuRow {
                HighlightedText(text: rule.name, query: searchText)
                    .font(.headline)
                    .lineLimit(1)
            } menuContent: {
                contextMenuItems
            }
        } bodyContent: {
            ProviderCardOptionalPreviewBlock(
                preview: rule.preview,
                searchText: searchText,
                minHeight: descriptionHeight,
                maxHeight: descriptionHeight
            )
        } footerContent: {
            HStack(spacing: DesignSystem.Metrics.spacingS) {
                Image(systemName: "doc.text")
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                HighlightedText(text: rule.relativePath, query: searchText)
                    .font(.caption2.monospaced())
                    .dsSecondaryText(font: .caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        } actionContent: {
            EmptyView()
        } contextMenuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
                message: NSLocalizedString(
                    "rules.delete_confirm_message",
                    value: "Are you sure you want to delete this rule? This action cannot be undone.",
                    comment: "Rule delete confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingDeleteConfirmation,
            onConfirm: {
                Task { await onDelete() }
            },
            onCancel: {}
        )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ProviderCardRevealDeleteContextMenu(
            onReveal: onReveal,
            onDeleteRequest: { viewModel.showingDeleteConfirmation = true },
            extraContent: { extraContextMenu(rule) }
        )
    }
}

private struct RuleCardViewPreviewContainer: View {
    var body: some View {
        RuleCardView(
            rule: RuleInfo(
                id: "rule-1",
                name: "Swift Style Rule",
                preview: "Prefer explicit concurrency annotations for async APIs.",
                relativePath: "rules/swift/style.md",
                path: "/tmp/rules/swift/style.md"
            ),
            searchText: "sr",
            onReveal: {},
            onDelete: {},
            onTap: {}
        )
        .frame(width: 320)
        .padding(16)
    }
}

#Preview("Rule Card") {
    RuleCardViewPreviewContainer()
}
