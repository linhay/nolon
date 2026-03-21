import SwiftUI
import NolonUIFoundation

struct SidebarProviderRowView: View {
    @Environment(\.sidebarRowSize) private var sidebarRowSize

    let item: SidebarProviderItem
    let style: ProviderSidebarStyle
    let providerDebugLocatorText: (SidebarProviderItem) -> String?
    let onShowInFinder: (SidebarProviderItem) -> Void
    let onViewOfficialDocumentation: (SidebarProviderItem) -> Void
    let onEdit: (SidebarProviderItem) -> Void
    let onDeleteProvider: (SidebarProviderItem) -> Void
    let onCopyDebugMarker: (String) -> Void

    private var rowMetrics: SidebarProviderRowMetrics {
        SidebarProviderRowMetrics(sidebarRowSize: sidebarRowSize)
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: rowMetrics.textSpacing) {
                Text(item.title)
                    .font(rowMetrics.titleFont)
                if rowMetrics.showsSubtitle {
                    Text(item.subtitle)
                        .font(rowMetrics.subtitleFont)
                        .foregroundStyle(style.subtitleColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } icon: {
            Image(systemName: item.iconName.isEmpty ? "folder" : item.iconName)
                .font(.system(size: rowMetrics.iconFontSize, weight: .semibold))
                .frame(width: rowMetrics.iconFrameSize, height: rowMetrics.iconFrameSize)
        }
        .padding(.vertical, rowMetrics.verticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            if item.hasDocumentation {
                Button {
                    onViewOfficialDocumentation(item)
                } label: {
                    Label(
                        NSLocalizedString("action.view_official_docs", value: "View Official Documentation", comment: "Open official provider documentation"),
                        systemImage: "book.closed"
                    )
                }

                Divider()
            }

            Button {
                onShowInFinder(item)
            } label: {
                Label(NSLocalizedString("action.show_in_finder", value: "Show in Finder", comment: "Show in Finder"), systemImage: "folder")
            }

            Button {
                onEdit(item)
            } label: {
                Label(NSLocalizedString("action.edit", value: "Edit", comment: "Edit"), systemImage: "square.and.pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDeleteProvider(item)
            } label: {
                Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete"), systemImage: "trash")
                    .foregroundStyle(style.destructiveColor)
            }

            if let locator = providerDebugLocatorText(item), !locator.isEmpty {
                Divider()

                Button {
                    onCopyDebugMarker(locator)
                } label: {
                    Label(
                        NSLocalizedString("debug.page_marker.copy", value: "Copy Page Marker", comment: "Copy sidebar row page marker"),
                        systemImage: "scope"
                    )
                }
            }
        }
    }
}

struct SidebarProviderRowMetrics {
    let titleFont: Font
    let subtitleFont: Font
    let iconFontSize: CGFloat
    let iconFrameSize: CGFloat
    let textSpacing: CGFloat
    let verticalPadding: CGFloat
    let showsSubtitle: Bool

    init(sidebarRowSize: SidebarRowSize) {
        switch sidebarRowSize {
        case .small:
            titleFont = DesignSystem.Typography.labelSmall
            subtitleFont = DesignSystem.Typography.caption2
            iconFontSize = 12
            iconFrameSize = 14
            textSpacing = 1
            verticalPadding = 1
            showsSubtitle = false
        case .medium:
            titleFont = DesignSystem.Typography.body
            subtitleFont = DesignSystem.Typography.caption2
            iconFontSize = 16
            iconFrameSize = 18
            textSpacing = 2
            verticalPadding = 2
            showsSubtitle = true
        case .large:
            titleFont = DesignSystem.Typography.bodyLarge
            subtitleFont = DesignSystem.Typography.bodySmall
            iconFontSize = 18
            iconFrameSize = 20
            textSpacing = 3
            verticalPadding = 3
            showsSubtitle = true
        @unknown default:
            titleFont = DesignSystem.Typography.body
            subtitleFont = DesignSystem.Typography.caption2
            iconFontSize = 16
            iconFrameSize = 18
            textSpacing = 2
            verticalPadding = 2
            showsSubtitle = true
        }
    }
}

#Preview("Sidebar Provider Row") {
    List {
        SidebarProviderRowView(
            item: SidebarProviderItem(
                id: "preview-codex",
                kind: .vendor,
                vendorCategory: .original,
                title: "Codex",
                subtitle: "/tmp/preview/.codex/skills",
                iconName: "terminal",
                hasDocumentation: true
            ),
            style: .default,
            providerDebugLocatorText: { _ in "Sidebar > Codex" },
            onShowInFinder: { _ in },
            onViewOfficialDocumentation: { _ in },
            onEdit: { _ in },
            onDeleteProvider: { _ in },
            onCopyDebugMarker: { _ in }
        )
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 120)
}
