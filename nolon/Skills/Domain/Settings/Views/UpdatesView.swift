import SwiftUI
import NolonResourceKit
import NolonUI
import NolonUIFoundation

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
        NolonUI.UpdatesSheetContentView(
            data: updatesSheetData,
            onRefresh: {
                Task { await viewModel.checkForUpdates() }
            },
            onClose: { dismiss() },
            onTapUpdate: { updateID in
                selectedUpdate = viewModel.availableUpdates.first(where: { $0.id == updateID })
                showUpdateConfirmation = selectedUpdate != nil
            }
        )
        .confirmationAlert(
            data: updateConfirmationData,
            isPresented: $showUpdateConfirmation,
            onConfirm: {
                if let update = selectedUpdate {
                    Task {
                        await viewModel.performUpdate(update)
                    }
                }
                selectedUpdate = nil
            },
            onCancel: {
                selectedUpdate = nil
            }
        )
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await viewModel.checkForUpdates()
        }
    }

    private var updatesSheetData: UpdatesSheetContentData {
        UpdatesSheetContentData(
            title: NSLocalizedString("updates.title", comment: "Updates view title"),
            subtitle: lastCheckSubtitle,
            availableCountText: viewModel.hasUpdates
                ? String(
                    format: NSLocalizedString(
                        "updates.available_count",
                        comment: "Number of updates available"
                    ),
                    viewModel.updatableCount
                )
                : nil,
            isChecking: viewModel.isChecking,
            rows: viewModel.availableUpdates.map(updateRowData(from:))
        )
    }

    private var updateConfirmationData: ConfirmationAlertData {
        let message: String
        if let update = selectedUpdate {
            message = "Update \(update.skillName) to \(update.latestVersion ?? "latest")?"
        } else {
            message = NSLocalizedString("updates.confirm_fallback", value: "Apply this update now?", comment: "Update confirmation fallback")
        }
        return ConfirmationAlertData(
            title: NSLocalizedString("action.edit", comment: "Edit"),
            message: message,
            confirmTitle: NSLocalizedString("generic.save", comment: "Save"),
            cancelTitle: NSLocalizedString("generic.cancel", comment: "Cancel")
        )
    }

    private func updateRowData(from update: SkillUpdateInfo) -> SkillUpdateRowData {
        SkillUpdateRowData(
            id: update.id,
            skillName: update.skillName,
            sourceLabel: update.updateSource.rawValue,
            sourceSystemImage: sourceIcon(for: update.updateSource),
            currentVersionText: update.currentVersion.map { "Current: \($0)" },
            latestVersionText: update.latestVersion.map { "Latest: \($0)" },
            hasUpdate: update.hasUpdate,
            updateButtonTitle: NSLocalizedString("action.save", comment: "Save"),
            upToDateText: NSLocalizedString("updates.empty_title", comment: "All skills up to date")
        )
    }

    private func sourceIcon(for source: SkillUpdateInfo.UpdateSource) -> String {
        switch source {
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
