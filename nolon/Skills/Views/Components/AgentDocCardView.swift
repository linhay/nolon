import SwiftUI

enum AgentDocKind: String, Sendable {
    case override
    case base
}

struct AgentDocInfo: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let path: String
    let preview: String
    let kind: AgentDocKind
}

struct AgentDocCardView: View {
    let doc: AgentDocInfo
    let searchText: String
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                HighlightedText(text: doc.fileName, query: searchText)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                moreMenu
            }

            HStack(spacing: 6) {
                Image(systemName: doc.kind == .override ? "arrow.up.circle" : "doc.text")
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Text(doc.kind == .override
                     ? NSLocalizedString("agents.priority.override", value: "Higher priority (override)", comment: "Override priority hint")
                     : NSLocalizedString("agents.priority.base", value: "Base priority", comment: "Base priority hint"))
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                    .lineLimit(1)
            }

            if !doc.preview.isEmpty {
                HighlightedText(text: doc.preview, query: searchText)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                    .lineLimit(3)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear
                    .frame(height: 16)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(16)
        .frame(minHeight: 140)
        .providerTabCardStyle()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu { contextMenuItems }
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
                    "agents.delete_confirm_message",
                    value: "Are you sure you want to delete this AGENTS document? This action cannot be undone.",
                    comment: "AGENTS document delete confirmation message"
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
