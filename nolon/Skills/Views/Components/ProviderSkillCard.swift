import SwiftUI
import NolonResourceKit

struct ProviderSkillCard: View {
    let state: ProviderSkillState
    let hasUpdate: Bool
    let onUninstall: () async -> Void
    let onMigrate: () async -> Void
    let onRepair: () async -> Void
    let onDelete: () async -> Void
    let onUpdate: () async -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Skill Name + Status Badge
            HStack(alignment: .top) {
                Text(state.skillName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                statusBadge
            }
            
            // Description / State Info
            Text(stateDescription)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(2)
            
            Spacer(minLength: 0)
            
            // Actions Footer
            actionButtons
        }
        .padding()
        .frame(minHeight: 120)
        .dsCard(
            background: cardBackground,
            borderColor: borderColor
        )
        .shadow(
            color: DesignSystem.Colors.Shadow.floating.opacity(isHovered ? 0.75 : 0.35),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .confirmationDialog(
            NSLocalizedString("confirm.delete_broken_title", comment: "Delete broken symlink?"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        Group {
            switch state.state {
            case .installed:
                Label(NSLocalizedString("status.synced", value: "Synced", comment: "Synced status"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .dsBadge(
                        foreground: DesignSystem.Colors.Status.success,
                        background: DesignSystem.Colors.Status.success.opacity(0.15),
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
            case .orphaned:
                Label(NSLocalizedString("status.local", value: "Local", comment: "Local status"), systemImage: "folder.fill")
                    .font(.caption.weight(.medium))
                    .dsBadge(
                        foreground: DesignSystem.Colors.Status.warning,
                        background: DesignSystem.Colors.Status.warning.opacity(0.15),
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
            case .broken:
                Label(NSLocalizedString("status.broken", comment: "Broken Link"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .dsBadge(
                        foreground: DesignSystem.Colors.Status.error,
                        background: DesignSystem.Colors.Status.error.opacity(0.15),
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
            }
        }
    }
    
    // MARK: - State Description
    private var stateDescription: String {
        switch state.state {
        case .installed:
            return NSLocalizedString("status.synced_desc", value: "Managed by Nolon. Changes sync automatically.", comment: "Synced state description")
        case .orphaned:
            return NSLocalizedString("status.local_desc", value: "Not managed. Migrate to enable syncing.", comment: "Orphaned state description")
        case .broken:
            return NSLocalizedString("status.broken_desc", value: "Link target missing. Repair or delete.", comment: "Broken state description")
        }
    }
    
    // MARK: - Background & Border
    private var cardBackground: Color {
        DesignSystem.Colors.Component.controlFillSubtle
    }
    
    private var borderColor: Color {
        switch state.state {
        case .installed:
            return DesignSystem.Colors.Component.border.opacity(0.35)
        case .orphaned:
            return DesignSystem.Colors.Status.warning.opacity(0.35)
        case .broken:
            return DesignSystem.Colors.Status.error.opacity(0.35)
        }
    }
    
    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if hasUpdate && state.state == .installed {
                Button {
                    Task { await onUpdate() }
                } label: {
                    Label(NSLocalizedString("action.update", value: "Update", comment: "Update"), systemImage: "arrow.down.circle")
                        .font(.caption.weight(.medium))
                }
                .dsPrimaryButton()
                .controlSize(.small)
            }
            
            switch state.state {
            case .installed:
                Menu {
                    Button(role: .destructive) {
                        Task { await onUninstall() }
                    } label: {
                        Label(NSLocalizedString("action.uninstall", comment: "Uninstall"), systemImage: "trash")
                            .dsIconLabelButton()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .dsIconButton(size: 28)
                }
                .dsBorderlessMenu()
                .menuIndicator(.hidden)
                .fixedSize()
                
            case .orphaned:
                Button {
                    Task { await onMigrate() }
                } label: {
                    Label(NSLocalizedString("action.import", value: "Import", comment: "Import to library"), systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.medium))
                }
                .dsPrimaryButton()
                .controlSize(.small)
                
            case .broken:
                Button {
                    Task { await onRepair() }
                } label: {
                    Label(NSLocalizedString("action.repair", comment: "Repair"), systemImage: "wrench")
                        .font(.caption)
                }
                .dsSecondaryButton()
                .controlSize(.small)
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .dsSecondaryButton(
                    foreground: DesignSystem.Colors.Status.error,
                    background: DesignSystem.Colors.Status.error.opacity(0.08),
                    borderColor: DesignSystem.Colors.Status.error.opacity(0.45)
                )
                .controlSize(.small)
            }
            
            Spacer()
        }
    }
}
