import SwiftUI
import AppKit
import ProviderCatalog
import NolonUI

/// Row view for a provider in the sidebar
struct ProviderRowView: View {
    let provider: Provider
    let isSelected: Bool
    let onShowInFinder: () -> Void
    let onViewOfficialDocumentation: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let debugLocatorText: String?
    @State private var commandState = AppCommandState.shared
    
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                Text(provider.defaultSkillsPath)
                    .font(.caption2)
                    .dsSecondaryText(font: .caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            NolonUI.ProviderLogoView(
                name: provider.displayName,
                logoName: ProviderTemplate(rawValue: provider.templateId ?? "")?.logoFile,
                style: .iconOnly,
                iconSize: 18
            )
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            if provider.documentationURL != nil {
                Button {
                    onViewOfficialDocumentation()
                } label: {
                    menuLabel(
                        NSLocalizedString("action.view_official_docs", value: "View Official Documentation", comment: "Open official provider documentation"),
                        systemImage: "book.closed"
                    )
                }

                Divider()
            }

            Button {
                onShowInFinder()
            } label: {
                menuLabel(
                    NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                    systemImage: "folder"
                )
            }
            
            Button {
                onEdit()
            } label: {
                menuLabel(
                    NSLocalizedString("action.edit", comment: "Edit"),
                    systemImage: "square.and.pencil"
                )
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                menuLabel(
                    NSLocalizedString("action.delete", comment: "Delete"),
                    systemImage: "trash",
                    foreground: DesignSystem.Colors.Status.error
                )
            }

            if PageMarkerRouteResolver.isEnabledInCurrentBuild,
               commandState.isDebugPageMarkersEnabled,
               let debugLocatorText,
               !debugLocatorText.isEmpty {
                Divider()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(debugLocatorText, forType: .string)
                    DebugMarkerToastCenter.shared.showCopiedPageMarkerToast(debugLocatorText)
                } label: {
                    menuLabel(
                        NSLocalizedString("debug.page_marker.copy", value: "Copy Page Marker", comment: "Copy sidebar row page marker"),
                        systemImage: "scope"
                    )
                }
            }
        }
    }

    private func menuLabel(
        _ title: String,
        systemImage: String,
        foreground: Color = DesignSystem.Colors.Text.primary
    ) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
        }
        .dsIconLabelButton(foreground: foreground)
    }
}
