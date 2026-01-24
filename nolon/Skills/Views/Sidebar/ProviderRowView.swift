import SwiftUI

/// Row view for a provider in the sidebar
struct ProviderRowView: View {
    let provider: Provider
    let isSelected: Bool
    let onShowInFinder: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                Text(provider.defaultSkillsPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            ProviderLogoView(provider: provider, style: .iconOnly, iconSize: 18)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onShowInFinder()
            } label: {
                Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
            }
            
            Button {
                onEdit()
            } label: {
                Label(NSLocalizedString("action.edit", comment: "Edit"), systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(NSLocalizedString("action.delete", comment: "Delete"), systemImage: "trash")
            }
        }
    }
}
