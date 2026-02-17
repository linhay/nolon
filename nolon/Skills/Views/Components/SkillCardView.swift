import SwiftUI
import ProviderCatalog
import NolonResourceKit

/// Skill 卡片视图 - Grid 布局中的卡片
struct SkillCardView: View {
    let skill: Skill
    let provider: Provider
    var hasWorkflow: Bool = false
    let searchText: String
    let onReveal: () -> Void
    let onUninstall: () async -> Void
    let onLinkWorkflow: () -> Void
    let onUnlinkWorkflow: () -> Void
    var onMigrate: () async -> Void = {}
    let onTap: () -> Void
    
    @State private var showingUninstallConfirmation = false
    private let descriptionHeight: CGFloat = 44
    
    var body: some View {
        cardContainer
    }

    private var cardContainer: AnyView {
        AnyView(
            cardContent
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: 140)
                .providerTabCardStyle()
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .contextMenu { contextMenuItems }
                .confirmationDialog(
                    NSLocalizedString("action.uninstall_confirm_title", value: "Confirm Uninstall", comment: "Uninstall confirmation title"),
                    isPresented: $showingUninstallConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(NSLocalizedString("action.uninstall", comment: "Uninstall"), role: .destructive) {
                        Task { await onUninstall() }
                    }
                    Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action"), role: .cancel) {}
                } message: {
                    Text(NSLocalizedString("action.uninstall_confirm_message", value: "Are you sure you want to uninstall this skill? This action cannot be undone.", comment: "Uninstall confirmation message"))
                }
        )
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            versionRow
            descriptionView
            actionRow
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            HighlightedText(text: skill.name, query: searchText)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            moreMenu
        }
    }

    private var versionRow: some View {
        HStack(spacing: 4) {
            SkillVersionBadge(version: skill.version)
            if skill.installationState == .orphaned {
                SkillOrphanedBadge()
            }
        }
    }

    private var descriptionView: some View {
        HighlightedText(text: skill.description, query: searchText)
            .font(.caption)
            .dsSecondaryText(font: .caption)
            .lineLimit(3)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, minHeight: descriptionHeight, maxHeight: descriptionHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private var actionRow: some View {
        if hasWorkflow {
            HStack {
                Button {
                    onUnlinkWorkflow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Workflow")
                    }
                    .fontWeight(.semibold)
                    .dsBadge(
                        foreground: DesignSystem.Colors.primary,
                        background: DesignSystem.Colors.primary.opacity(0.10),
                        horizontalPadding: 10,
                        verticalPadding: 6,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusM
                    )
                }
                .dsLinkButton()

                Spacer()
            }
        } else {
            HStack(spacing: 12) {
                Button {
                    onLinkWorkflow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text(NSLocalizedString("action.link_workflow", comment: "Link to Workflow"))
                    }
                    .fontWeight(.semibold)
                    .dsBadge(
                        foreground: DesignSystem.Colors.Text.secondary,
                        background: DesignSystem.Colors.Component.controlFill,
                        horizontalPadding: 10,
                        verticalPadding: 6,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusM
                    )
                }
                .dsLinkButton()

                Spacer()

                if skill.hasReferences {
                    Label("\(skill.referenceCount)", systemImage: "doc.text")
                        .dsIconLabelButton(foreground: DesignSystem.Colors.Text.secondary, font: .caption2)
                }
                if skill.hasScripts {
                    Label("\(skill.scriptCount)", systemImage: "terminal")
                        .dsIconLabelButton(foreground: DesignSystem.Colors.Text.secondary, font: .caption2)
                }
            }
            .font(.caption2)
            .dsSecondaryText(font: .caption2)
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        // Common: Show in Finder
        Button {
            onReveal()
        } label: {
            Label(
                NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                systemImage: "folder"
            )
            .dsIconLabelButton()
        }
        
        if skill.installationState == .orphaned {
            // Orphaned: Migrate action
            Button {
                Task { await onMigrate() }
            } label: {
                Label(
                    NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate orphaned skill"),
                    systemImage: "arrow.right.arrow.left"
                )
                .dsIconLabelButton()
            }
            
            Divider()
            
            // Orphaned: Delete (not uninstall)
            Button(role: .destructive) {
                Task { await onUninstall() }
            } label: {
                Label(
                    NSLocalizedString("action.delete", value: "Delete", comment: "Delete skill"),
                    systemImage: "trash"
                )
                .dsIconLabelButton()
            }
        } else {
            // Installed: Link/Unlink Workflow
            if hasWorkflow {
                Button {
                    onUnlinkWorkflow()
                } label: {
                    Label(
                        NSLocalizedString("action.unlink_workflow", value: "Unlink Workflow", comment: "Unlink from Workflow"),
                        systemImage: "link.badge.plus"
                    )
                    .dsIconLabelButton()
                }
            } else {
                Button {
                    onLinkWorkflow()
                } label: {
                    Label(
                        NSLocalizedString("action.link_workflow", comment: "Link to Workflow"),
                        systemImage: "link"
                    )
                    .dsIconLabelButton()
                }
            }
            
            Divider()
            
            // Installed: Uninstall
            Button(role: .destructive) {
                showingUninstallConfirmation = true
            } label: {
                Label(
                    NSLocalizedString("action.uninstall", comment: "Uninstall"),
                    systemImage: "trash"
                )
                .dsIconLabelButton()
            }
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
