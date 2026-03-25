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

    @State private var showingDeleteConfirmation = false
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
        VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
            HStack(alignment: .center, spacing: DesignSystem.Metrics.spacingS) {
                HighlightedText(text: rule.name, query: searchText)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                moreMenu
            }

            if !rule.preview.isEmpty {
                HighlightedText(text: rule.preview, query: searchText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: descriptionHeight, maxHeight: descriptionHeight, alignment: .topLeading)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: descriptionHeight, maxHeight: descriptionHeight, alignment: .topLeading)
            }

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
        }
        .padding(DesignSystem.Metrics.spacingL)
        .frame(minHeight: 140)
        .providerTabCardStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            contextMenuItems
        }
        .confirmationDialog(
            NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                Task { await onDelete() }
            }
            Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action"), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "rules.delete_confirm_message",
                    value: "Are you sure you want to delete this rule? This action cannot be undone.",
                    comment: "Rule delete confirmation message"
                )
            )
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onReveal()
        } label: {
            Label(
                NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                systemImage: "folder"
            )
            .dsIconLabelButton()
        }

        Divider()

        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label(
                NSLocalizedString("action.delete", comment: "Delete"),
                systemImage: "trash"
            )
            .dsIconLabelButton()
        }

        extraContextMenu(rule)
    }

    private var moreMenu: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
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
