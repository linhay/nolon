import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexProvider
import NolonUIFoundation
import NolonUI

struct CodexCloudSyncSettingsView: View {
    let provider: Provider

    @State private var rootViewModel: ProviderUsageRootViewModel
    @State private var isShowingAttentionSheet = false
    @State private var isShowingClearConfirm = false

    @MainActor
    init(provider: Provider) {
        self.provider = provider
        self._rootViewModel = State(initialValue: ProviderUsageRootViewModelStore.shared.viewModel(for: provider))
    }

    private var viewModel: ProviderUsageAccountsViewModel.CodexState {
        rootViewModel.accountsViewModel.codex
    }

    var body: some View {
        card
            .task(id: provider.id) {
                rootViewModel = ProviderUsageRootViewModelStore.shared.viewModel(for: provider)
                _ = await rootViewModel.loadAccountsIfNeeded()
            }
            .onChange(of: provider.id) { _, _ in
                rootViewModel = ProviderUsageRootViewModelStore.shared.viewModel(for: provider)
                Task { _ = await rootViewModel.loadAccountsIfNeeded() }
            }
            .confirmationAlert(
                data: clearCloudAlertData,
                isPresented: $isShowingClearConfirm,
                onConfirm: {
                    Task { await viewModel.clearCloudData() }
                },
                onCancel: {}
            )
            .sheet(isPresented: $isShowingAttentionSheet) {
                CodexCloudAttentionSheet(viewModel: viewModel)
            }
            .messageAlert(alert: alertBinding)
    }

    private var card: some View {
        let snapshot = viewModel.cloudSyncSnapshot

        return VStack(alignment: .leading, spacing: 12) {
            Text(
                NSLocalizedString(
                    "codex.accounts.cloud.title",
                    value: "iCloud 同步",
                    comment: "Codex cloud sync title"
                )
            )
            .font(.headline)

            Text(cloudSyncStatusSummary(snapshot: snapshot))
                .font(.subheadline)
                .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(
                    title: NSLocalizedString("codex.accounts.cloud.status", value: "当前状态", comment: "Codex cloud sync status label"),
                    value: cloudSyncStatusLabel(snapshot: snapshot)
                )
                infoRow(
                    title: NSLocalizedString("codex.accounts.cloud.availability", value: "iCloud 账户", comment: "Codex cloud sync availability label"),
                    value: cloudSyncAvailabilityLabel(snapshot.availability)
                )
                infoRow(
                    title: NSLocalizedString("codex.accounts.cloud.last_synced", value: "上次成功同步", comment: "Codex cloud sync last synced label"),
                    value: snapshot.lastSyncedAt?.formatted(date: .abbreviated, time: .shortened)
                        ?? NSLocalizedString("codex.accounts.cloud.never", value: "尚无", comment: "No cloud sync timestamp")
                )
                infoRow(
                    title: NSLocalizedString("codex.accounts.cloud.pending", value: "待同步变更", comment: "Codex cloud sync pending label"),
                    value: "\(snapshot.pendingChangeCount)"
                )
                infoRow(
                    title: NSLocalizedString("codex.accounts.cloud.error", value: "最近错误", comment: "Codex cloud sync recent error label"),
                    value: snapshot.recentError
                        ?? NSLocalizedString("codex.accounts.cloud.none", value: "无", comment: "No cloud sync error")
                )
            }

            HStack(spacing: 8) {
                if snapshot.isEnabled {
                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.sync_now",
                            value: "立即同步",
                            comment: "Trigger codex cloud sync now"
                        )
                    ) {
                        Task { await viewModel.syncCloudNow() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.disable",
                            value: "关闭本机同步",
                            comment: "Disable codex cloud sync on this machine"
                        )
                    ) {
                        Task { await viewModel.setCloudSyncEnabled(false) }
                    }
                    .buttonStyle(.bordered)

                    if !viewModel.cloudAttentionItems.isEmpty {
                        Button(
                            NSLocalizedString(
                                "codex.accounts.cloud.attention.button",
                                value: "查看冲突",
                                comment: "Show codex cloud attention sheet"
                            )
                        ) {
                            isShowingAttentionSheet = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.clear.action",
                            value: "清空 iCloud 云副本",
                            comment: "Clear codex cloud data action"
                        )
                    ) {
                        isShowingClearConfirm = true
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.enable",
                            value: "开启同步",
                            comment: "Enable codex cloud sync"
                        )
                    ) {
                        Task { await viewModel.setCloudSyncEnabled(true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if snapshot.conflictCount > 0 || snapshot.invalidPendingCount > 0 {
                Text(
                    String(
                        format: NSLocalizedString(
                            "codex.accounts.cloud.attention",
                            value: "有 %d 个冲突、%d 个待修复账号，请优先处理这些卡片的云状态。",
                            comment: "Codex cloud sync attention summary"
                        ),
                        snapshot.conflictCount,
                        snapshot.invalidPendingCount
                    )
                )
                .font(.caption)
                .foregroundStyle(NolonUI.DesignSystem.Colors.Status.warning)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NolonUI.DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NolonUI.DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
        )
    }

    private var alertBinding: Binding<MessageAlertData?> {
        Binding<MessageAlertData?>(
            get: {
                guard let message = rootViewModel.accountsViewModel.alertMessage else { return nil }
                return MessageAlertData(
                    title: rootViewModel.accountsViewModel.alertTitle ?? "",
                    message: message
                )
            },
            set: { value in
                if value == nil {
                    rootViewModel.accountsViewModel.alertTitle = nil
                    rootViewModel.accountsViewModel.alertMessage = nil
                }
            }
        )
    }

    private var clearCloudAlertData: ConfirmationAlertData {
        ConfirmationAlertData(
            title: NSLocalizedString(
                "codex.accounts.cloud.clear.title",
                value: "清空 iCloud 云副本？",
                comment: "Clear codex cloud data title"
            ),
            message: NSLocalizedString(
                "codex.accounts.cloud.clear.message",
                value: "这会删除当前 CloudKit 容器中的 Codex 账号记录，并关闭本机同步。已同步到其他设备的本地账号不会自动删除。",
                comment: "Clear codex cloud data message"
            ),
            confirmTitle: NSLocalizedString(
                "codex.accounts.cloud.clear.confirm",
                value: "清空并关闭同步",
                comment: "Clear codex cloud data confirm"
            ),
            cancelTitle: NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
            isDestructiveConfirm: true
        )
    }

    private func cloudSyncStatusSummary(snapshot: CodexiCloudSyncService.Snapshot) -> String {
        [
            cloudSyncStatusLabel(snapshot: snapshot),
            String(
                format: NSLocalizedString(
                    "codex.accounts.cloud.summary.records",
                    value: "账号记录 %d",
                    comment: "Codex cloud sync record count summary"
                ),
                snapshot.totalRecordCount
            ),
            String(
                format: NSLocalizedString(
                    "codex.accounts.cloud.summary.pending",
                    value: "待处理 %d",
                    comment: "Codex cloud sync pending summary"
                ),
                snapshot.pendingChangeCount
            )
        ].joined(separator: " · ")
    }

    private func cloudSyncStatusLabel(snapshot: CodexiCloudSyncService.Snapshot) -> String {
        switch snapshot.status {
        case .disabled:
            return NSLocalizedString("codex.accounts.cloud.status.disabled", value: "未开启", comment: "Disabled cloud sync status")
        case .syncing:
            return NSLocalizedString("codex.accounts.cloud.status.syncing", value: "同步中", comment: "Syncing cloud sync status")
        case .synced:
            return NSLocalizedString("codex.accounts.cloud.status.synced", value: "已同步", comment: "Synced cloud sync status")
        case .paused:
            return NSLocalizedString("codex.accounts.cloud.status.paused", value: "已暂停", comment: "Paused cloud sync status")
        case .conflict:
            return NSLocalizedString("codex.accounts.cloud.status.conflict", value: "有冲突", comment: "Conflict cloud sync status")
        case .failed:
            return NSLocalizedString("codex.accounts.cloud.status.failed", value: "失败", comment: "Failed cloud sync status")
        }
    }

    private func cloudSyncAvailabilityLabel(_ availability: CodexiCloudSyncService.Availability) -> String {
        switch availability {
        case .unknown:
            return NSLocalizedString("codex.accounts.cloud.availability.unknown", value: "未知", comment: "Unknown cloud availability")
        case .unavailable:
            return NSLocalizedString("codex.accounts.cloud.availability.unavailable", value: "不可用", comment: "Unavailable cloud availability")
        case .available:
            return NSLocalizedString("codex.accounts.cloud.availability.available", value: "可用", comment: "Available cloud availability")
        case .restricted:
            return NSLocalizedString("codex.accounts.cloud.availability.restricted", value: "受限", comment: "Cloud sync restricted")
        case .temporarilyUnavailable:
            return NSLocalizedString("codex.accounts.cloud.availability.temporary", value: "暂时不可用", comment: "Cloud sync temporarily unavailable")
        case .noAccount:
            return NSLocalizedString("codex.accounts.cloud.availability.no_account", value: "未登录 iCloud", comment: "No iCloud account")
        case .couldNotDetermine:
            return NSLocalizedString("codex.accounts.cloud.availability.indeterminate", value: "无法确认", comment: "Indeterminate cloud availability")
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(NolonUI.DesignSystem.Colors.Text.tertiary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.callout)
                .foregroundStyle(NolonUI.DesignSystem.Colors.Text.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

private struct CodexCloudAttentionSheet: View {
    let viewModel: ProviderUsageAccountsViewModel.CodexState
    @Environment(\.dismiss) private var dismiss

    private var items: [CodexCloudAttentionItem] {
        Array(viewModel.cloudAttentionItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        NSLocalizedString(
                            "codex.accounts.cloud.attention.sheet.title",
                            value: "冲突与待修复",
                            comment: "Codex cloud attention sheet title"
                        )
                    )
                    .font(.title3.weight(.semibold))

                    Text(
                        NSLocalizedString(
                            "codex.accounts.cloud.attention.sheet.message",
                            value: "这里列出需要手动处理的 Codex 账号。你可以选择保留本地凭据并重新上传，或在 tombstone 已失效时清理本地残留。",
                            comment: "Codex cloud attention sheet message"
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                }

                Spacer(minLength: 0)

                Button(
                    NSLocalizedString("generic.done", value: "完成", comment: "Done")
                ) {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            if items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        NSLocalizedString(
                            "codex.accounts.cloud.attention.empty",
                            value: "当前没有需要手动处理的云同步问题。",
                            comment: "Codex cloud attention empty state"
                        )
                    )
                    .font(.body)
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(items, id: \.id) { item in
                            CodexCloudAttentionRow(
                                item: item,
                                email: viewModel.accountSummaries[item.account.id]?.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                                retryAction: { id in
                                    Task { await viewModel.retryCloudAttentionAccount(id: id) }
                                },
                                adoptRemoteAction: { id in
                                    Task { await viewModel.adoptRemoteCloudConflict(accountID: id) }
                                },
                                keepBothAction: { id in
                                    Task { await viewModel.keepBothCloudConflict(accountID: id) }
                                },
                                discardAction: { id in
                                    Task { await viewModel.discardInvalidPendingAccount(id: id) }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
        .background(NolonUI.DesignSystem.Colors.Background.canvas)
    }
}

private struct CodexCloudAttentionRow: View {
    let item: CodexCloudAttentionItem
    let email: String?
    let retryAction: @MainActor (UUID) -> Void
    let adoptRemoteAction: @MainActor (UUID) -> Void
    let keepBothAction: @MainActor (UUID) -> Void
    let discardAction: @MainActor (UUID) -> Void

    private var tag: String? {
        ProviderUsageAccountsViewModel.CodexState.cloudSyncStatusTag(for: item.state)
    }

    private var detail: String? {
        ProviderUsageAccountsViewModel.CodexState.cloudSyncTrailingText(for: item.state)
    }

    private var trimmedEmail: String? {
        guard let email, !email.isEmpty else { return nil }
        return email
    }

    private var showsDiscardAction: Bool {
        item.state.syncStatus == .invalidPending
    }

    private var showsAdoptRemoteAction: Bool {
        ProviderUsageAccountsViewModel.CodexState.canAdoptRemoteCloudConflict(for: item.state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: item.account.name)
                    .font(.headline)
                if let tag {
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NolonUI.DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(NolonUI.DesignSystem.Colors.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let trimmedEmail {
                Text(verbatim: trimmedEmail)
                    .font(.caption)
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.tertiary)
            }

            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
            }

            HStack(spacing: 8) {
                if showsAdoptRemoteAction {
                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.attention.adopt_remote",
                            value: "采用云端覆盖本地",
                            comment: "Adopt remote cloud conflict action"
                        )
                    ) {
                        adoptRemoteAction(item.account.id)
                    }
                    .buttonStyle(.bordered)

                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.attention.keep_both",
                            value: "两者都保留",
                            comment: "Keep both cloud conflict action"
                        )
                    ) {
                        keepBothAction(item.account.id)
                    }
                    .buttonStyle(.bordered)
                }

                Button(
                    NSLocalizedString(
                        "codex.accounts.cloud.attention.retry_local",
                        value: "保留本地并重试上传",
                        comment: "Retry local cloud upload action"
                    )
                ) {
                    retryAction(item.account.id)
                }
                .buttonStyle(.borderedProminent)

                if showsDiscardAction {
                    Button(
                        NSLocalizedString(
                            "codex.accounts.cloud.attention.discard_local",
                            value: "清理本地残留",
                            comment: "Discard invalid pending local residue action"
                        )
                    ) {
                        discardAction(item.account.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NolonUI.DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NolonUI.DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
        )
    }
}
