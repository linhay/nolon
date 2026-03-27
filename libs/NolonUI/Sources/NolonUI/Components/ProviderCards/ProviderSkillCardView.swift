import SwiftUI
import NolonUIFoundation

public struct ProviderSkillCardView: View {
    @State private var viewModel = ProviderSkillCardViewViewModel()
    private let state: ProviderSkillCardInfo
    private let hasUpdate: Bool
    private let onUninstall: () async -> Void
    private let onMigrate: () async -> Void
    private let onRepair: () async -> Void
    private let onDelete: () async -> Void
    private let onUpdate: () async -> Void

    @State private var showingDeleteConfirmation = false
    @State private var isHovered = false

    public init(
        state: ProviderSkillCardInfo,
        hasUpdate: Bool,
        onUninstall: @escaping () async -> Void,
        onMigrate: @escaping () async -> Void,
        onRepair: @escaping () async -> Void,
        onDelete: @escaping () async -> Void,
        onUpdate: @escaping () async -> Void
    ) {
        self.state = state
        self.hasUpdate = hasUpdate
        self.onUninstall = onUninstall
        self.onMigrate = onMigrate
        self.onRepair = onRepair
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(state.skillName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                statusBadge
            }

            Text(stateDescription)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(2)

            Spacer(minLength: 0)

            actionButtons
        }
        .padding()
        .frame(minHeight: 120)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFillSubtle,
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
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("confirm.delete_broken_title", comment: "Delete broken symlink?"),
                message: NSLocalizedString(
                    "confirm.delete_broken_message",
                    value: "Are you sure you want to delete this broken skill link?",
                    comment: "Delete broken skill confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $showingDeleteConfirmation,
            onConfirm: {
                Task { await onDelete() }
            },
            onCancel: {}
        )
    }

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
                EllipsisMenuButton(iconSize: 28) {
                    Button(role: .destructive) {
                        Task { await onUninstall() }
                    } label: {
                        Label(NSLocalizedString("action.uninstall", comment: "Uninstall"), systemImage: "trash")
                            .dsIconLabelButton()
                    }
                }

            case .orphaned:
                Button {
                    Task { await onMigrate() }
                } label: {
                    Label(NSLocalizedString("action.import", value: "Import to Library", comment: "Import to library"), systemImage: "square.and.arrow.down")
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

#Preview {
    ProviderSkillCardView(
        state: ProviderSkillCardInfo(
            skillName: "swiftui-patterns",
            state: .orphaned,
            path: "/tmp/swiftui-patterns"
        ),
        hasUpdate: true,
        onUninstall: {},
        onMigrate: {},
        onRepair: {},
        onDelete: {},
        onUpdate: {}
    )
    .frame(width: 280)
    .padding(16)
}
