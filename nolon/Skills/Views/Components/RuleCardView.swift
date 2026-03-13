import SwiftUI

struct RuleInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let preview: String
    let relativePath: String
    let path: String
}

struct RuleCardView: View {
    let rule: RuleInfo
    let searchText: String
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void

    @State private var showingDeleteConfirmation = false
    private let descriptionHeight: CGFloat = 44

    var body: some View {
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

        debugPageMarkerMenuItem(
            [
                PageMarkerItem(title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules tab")),
                PageMarkerItem(title: rule.name)
            ]
        )
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
