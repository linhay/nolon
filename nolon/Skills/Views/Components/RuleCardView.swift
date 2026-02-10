import SwiftUI

struct RuleInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let preview: String
    let relativePath: String
    let path: String

    static func parse(from url: URL, baseDirectory: URL) -> RuleInfo? {
        guard url.pathExtension.lowercased() == "rules" else { return nil }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let rulePath = url.standardizedFileURL.path
        let basePath = baseDirectory.standardizedFileURL.path
        let relativePath: String
        if rulePath.hasPrefix(basePath + "/") {
            relativePath = String(rulePath.dropFirst(basePath.count + 1))
        } else {
            relativePath = fileName + ".rules"
        }
        let id = relativePath.replacingOccurrences(of: ".rules", with: "")
        let parsedName = fileName
        let parsedPreview = parsePreview(from: content)

        return RuleInfo(
            id: id,
            name: parsedName,
            preview: parsedPreview,
            relativePath: relativePath,
            path: url.path
        )
    }

    private static func parsePreview(from content: String) -> String {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines {
            if line.isEmpty { continue }
            return line
        }
        return ""
    }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
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
                Text(" ")
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: descriptionHeight, maxHeight: descriptionHeight, alignment: .topLeading)
            }

            HStack(spacing: 8) {
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
        .padding(16)
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
            Text(NSLocalizedString("action.delete_confirm_message", value: "Are you sure you want to delete this workflow? This action cannot be undone.", comment: "Delete confirmation message"))
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
