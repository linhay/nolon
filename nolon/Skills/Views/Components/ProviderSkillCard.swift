import SwiftUI

/// Card view for displaying provider skill status (for ProviderSkillsView)
struct ProviderSkillCard: View {
    let state: ProviderSkillState
    let onUninstall: () async -> Void
    let onMigrate: () async -> Void
    let onRepair: () async -> Void
    let onDelete: () async -> Void
    
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
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Spacer(minLength: 0)
            
            // Actions Footer
            actionButtons
        }
        .padding()
        .frame(minHeight: 120)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
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
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
            case .orphaned:
                Label(NSLocalizedString("status.local", value: "Local", comment: "Local status"), systemImage: "folder.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
            case .broken:
                Label(NSLocalizedString("status.broken", comment: "Broken Link"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(6)
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
    private var cardBackground: some View {
        Group {
            switch state.state {
            case .installed:
                Color.secondary.opacity(0.08)
            case .orphaned:
                Color.orange.opacity(0.05)
            case .broken:
                Color.red.opacity(0.05)
            }
        }
    }
    
    private var borderColor: Color {
        switch state.state {
        case .installed:
            return .clear
        case .orphaned:
            return .orange.opacity(0.3)
        case .broken:
            return .red.opacity(0.3)
        }
    }
    
    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            switch state.state {
            case .installed:
                Menu {
                    Button(role: .destructive) {
                        Task { await onUninstall() }
                    } label: {
                        Label(NSLocalizedString("action.uninstall", comment: "Uninstall"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                
            case .orphaned:
                Button {
                    Task { await onMigrate() }
                } label: {
                    Label(NSLocalizedString("action.import", value: "Import", comment: "Import to library"), systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
            case .broken:
                Button {
                    Task { await onRepair() }
                } label: {
                    Label(NSLocalizedString("action.repair", comment: "Repair"), systemImage: "wrench")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
            
            Spacer()
        }
    }
}
