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
            // Header: Name + Version + Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HighlightedText(text: skill.name, query: searchText)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        SkillVersionBadge(version: skill.version)
                        
                        if skill.installationState == .orphaned {
                            SkillOrphanedBadge()
                        }
                    }
                }
                
                Spacer()
                
                moreMenu
            }
            
            // Description
            HighlightedText(text: skill.description, query: searchText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            Spacer(minLength: 0)
            
            // Footer: Stats
            HStack(spacing: 12) {
                if hasWorkflow {
                    Label("Workflow", systemImage: "arrow.triangle.branch")
                        .foregroundStyle(.blue)
                }
                
                if skill.hasReferences {
                    Label("\(skill.referenceCount)", systemImage: "doc.text")
                }
                if skill.hasScripts {
                    Label("\(skill.scriptCount)", systemImage: "terminal")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minHeight: 140)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var moreMenu: some View {
        Menu {
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
