import SwiftUI
import NolonResourceKit

struct UpdatesView: View {
    @State private var viewModel = UpdatesViewModel()
    @State private var selectedUpdate: SkillUpdateInfo?
    @State private var showUpdateConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    private var lastCheckSubtitle: String? {
        guard let lastCheck = viewModel.lastCheckDate else { return nil }
        let minutes = Int(Date().timeIntervalSince(lastCheck) / 60)
        return String(
            format: NSLocalizedString(
                "updates.last_checked",
                value: "Last checked: %d minutes ago",
                comment: "Last checked time"
            ),
            minutes
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            SheetDivider()
            
            if viewModel.isChecking {
                ProgressView()
                    .padding()
            } else if viewModel.availableUpdates.isEmpty {
                emptyStateView
            } else {
                updatesListView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await viewModel.checkForUpdates()
        }
    }
    
    private var headerView: some View {
        UISheetHeaderView(
            title: NSLocalizedString("updates.title", comment: "Updates view title"),
            subtitle: lastCheckSubtitle
        ) {
            HStack(spacing: 12) {
                if viewModel.hasUpdates {
                    Label(String(format: NSLocalizedString("updates.available_count", comment: "Number of updates available"), viewModel.updatableCount), systemImage: "arrow.down.circle")
                        .dsIconLabelText(foreground: DesignSystem.Colors.Status.info, font: .subheadline)
                }

                Button(action: {
                    Task {
                        await viewModel.checkForUpdates()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .dsIconButton()
                }
                .disabled(viewModel.isChecking)
                .help(NSLocalizedString("updates.check_for_updates", comment: "Check for updates button help"))

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .dsIconButton(size: 22, foreground: DesignSystem.Colors.Text.tertiary)
                }
                .dsLinkButton()
                .accessibilityLabel(NSLocalizedString("Close", comment: "Close"))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.Status.success)
            
            Text(NSLocalizedString("updates.empty_title", comment: "All skills up to date"))
                .font(.headline)
            
            Text(NSLocalizedString("updates.empty_desc", comment: "No updates available description"))
                .font(.subheadline)
                .dsSecondaryText(font: .subheadline)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    private var updatesListView: some View {
        List(viewModel.availableUpdates) { update in
            UpdateRowView(update: update) {
                selectedUpdate = update
                showUpdateConfirmation = true
            }
        }
        .sheetScrollContentPadding()
        .alert(NSLocalizedString("action.edit", comment: "Edit"), isPresented: $showUpdateConfirmation) {
            Button(NSLocalizedString("generic.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("generic.save", comment: "Save")) {
                if let update = selectedUpdate {
                    Task {
                        await viewModel.performUpdate(update)
                    }
                }
            }
        } message: {
            if let update = selectedUpdate {
                Text("Update \(update.skillName) to \(update.latestVersion ?? "latest")?")
            }
        }
    }
}

struct UpdateRowView: View {
    let update: SkillUpdateInfo
    let onUpdate: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            statusIndicator
            
            VStack(alignment: .leading, spacing: 4) {
                Text(update.skillName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(update.updateSource.rawValue, systemImage: sourceIcon)
                        .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .caption)
                    
                    if let current = update.currentVersion {
                        Text("Current: \(current)")
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }
                    
                    if let latest = update.latestVersion {
                        Text("Latest: \(latest)")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Status.success)
                    }
                }
            }
            
            Spacer()
            
            if update.hasUpdate {
                Button(NSLocalizedString("action.save", comment: "Save")) {
                    onUpdate()
                }
                .dsPrimaryButton()
                .controlSize(.small)
            } else {
                Label(NSLocalizedString("updates.empty_title", comment: "All skills up to date"), systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.success)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(update.hasUpdate ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success)
            .frame(width: 8, height: 8)
    }
    
    private var sourceIcon: String {
        switch update.updateSource {
        case .clawdhub:
            return "cloud"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        case .gitlab:
            return "chevron.left.forwardslash.chevron.right"
        case .local:
            return "folder"
        }
    }
}

#Preview {
    UpdatesView()
}
