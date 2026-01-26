import SwiftUI

/// Skill 卡片视图 - Grid 布局中的卡片
struct SkillCardView: View {
    let skill: Skill
    let provider: Provider
    var hasWorkflow: Bool = false
    let searchText: String
    let onReveal: () -> Void
    let onUninstall: () async -> Void
    let onLinkWorkflow: () -> Void
    var onMigrate: () async -> Void = {}
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header: Title | Menu
            HStack(alignment: .center) {
                HighlightedText(text: skill.name, query: searchText)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                moreMenu
            }
            
            // 2. Version
            HStack(spacing: 4) {
                SkillVersionBadge(version: skill.version)
                
                if skill.installationState == .orphaned {
                    SkillOrphanedBadge()
                }
            }
            
            // 3. Description
            HighlightedText(text: skill.description, query: searchText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            Spacer(minLength: 0)
            
            actionArea
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(skill.installationState == .orphaned ? Color.orange.opacity(0.03) : Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            moreMenuContent
        }
    }
    
    @ViewBuilder
    private var actionArea: some View {
        // 4. Action Area: Rounded rectangle buttons
        HStack(spacing: 8) {
            // Workflow Button
            Button {
                onLinkWorkflow()
            } label: {
                Label("Workflow", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(.bordered)
            .tint(hasWorkflow ? .blue : .secondary)
            .controlSize(.small)
            
            // Status/Action Button
            if skill.installationState == .orphaned {
                Button {
                    Task { await onMigrate() }
                } label: {
                    Label("Migrate", systemImage: "arrow.right.arrow.left")
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .controlSize(.small)
            } else {
                Button {
                    onTap()
                } label: {
                    Label(skill.installationState == .installed ? "Installed" : "Broken", 
                          systemImage: skill.installationState == .installed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                }
                .buttonStyle(.bordered)
                .tint(skill.installationState == .installed ? .accentColor : .red)
                .controlSize(.small)
            }
        }
    }
    
    @ViewBuilder
    private var moreMenuContent: some View {
        // Common: Show in Finder
        Button {
            onReveal()
        } label: {
            Label(
                NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                systemImage: "folder"
            )
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
            }
        } else {
            // Installed: Link to Workflow
            Button {
                onLinkWorkflow()
            } label: {
                Label(
                    NSLocalizedString("action.link_workflow", comment: "Link to Workflow"),
                    systemImage: "link"
                )
            }
            
            Divider()
            
            // Installed: Uninstall
            Button(role: .destructive) {
                Task { await onUninstall() }
            } label: {
                Label(
                    NSLocalizedString("action.uninstall", comment: "Uninstall"),
                    systemImage: "trash"
                )
            }
        }
    }
    
    private var moreMenu: some View {
        Menu {
            moreMenuContent
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
