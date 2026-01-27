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
    let onUnlinkWorkflow: () -> Void
    var onMigrate: () async -> Void = {}
    let onTap: () -> Void
    
    @State private var showingUninstallConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 标题 | 菜单
            HStack(alignment: .center) {
                HighlightedText(text: skill.name, query: searchText)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                moreMenu
            }
            
            // 2. 版本标签
            HStack(spacing: 4) {
                SkillVersionBadge(version: skill.version)
                
                if skill.installationState == .orphaned {
                    SkillOrphanedBadge()
                }
            }
            
            // 3. 技能描述
            HighlightedText(text: skill.description, query: searchText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxHeight: .infinity)
            
            // 4. 操作区: 工作流 圆角矩形按钮
            if hasWorkflow {
                HStack {
                    Button {
                        onUnlinkWorkflow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                            Text("Workflow")
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
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
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
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
        }
        .padding(16)
        .frame(minHeight: 140)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            contextMenuItems
        }
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
            // Installed: Link/Unlink Workflow
            if hasWorkflow {
                Button {
                    onUnlinkWorkflow()
                } label: {
                    Label(
                        NSLocalizedString("action.unlink_workflow", value: "Unlink Workflow", comment: "Unlink from Workflow"),
                        systemImage: "link.badge.plus"
                    )
                }
            } else {
                Button {
                    onLinkWorkflow()
                } label: {
                    Label(
                        NSLocalizedString("action.link_workflow", comment: "Link to Workflow"),
                        systemImage: "link"
                    )
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
            }
        }
    }
    
    private var moreMenu: some View {
        Menu {
            contextMenuItems
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
