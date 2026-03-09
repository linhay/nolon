import SwiftUI
import AppKit
import ProviderCatalog
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers

enum CodexUsageCardStatusKind: Equatable {
    case healthy
    case error
    case pending
}

enum CodexUsageCardActionLayout: Equatable {
    case singleFullWidth
    case dualEqualWidth
}

enum ProviderUsageLoginPolicy {
    static func shouldUseCLILogin(for provider: Provider) -> Bool {
        guard let templateID = provider.templateId else { return false }
        switch templateID {
        case "gemini", "antigravity":
            return true
        default:
            return false
        }
    }

    static func shouldShowDashboardSignIn(for provider: Provider, dashboardURL: URL?) -> Bool {
        guard dashboardURL != nil else { return false }
        guard let templateID = provider.templateId else { return true }
        switch templateID {
        case "gemini", "antigravity":
            return false
        default:
            return true
        }
    }
}

enum CodexUsageCardPresentationPolicy {
    static func statusKind(for state: ProviderUsageViewModel.CodexAccountDisplayState) -> CodexUsageCardStatusKind {
        switch state {
        case .needsReauth, .failed:
            return .error
        case .healthy:
            return .healthy
        case .pending:
            return .pending
        }
    }

    static func actionLayout(needsReauth: Bool, hasLoginAction: Bool) -> CodexUsageCardActionLayout {
        if needsReauth, hasLoginAction {
            return .dualEqualWidth
        }
        return .singleFullWidth
    }
}

struct ProviderUsageView: View {
    let provider: Provider
    let isEmbedded: Bool
    @State private var viewModel: ProviderUsageViewModel

    private let codexAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)
    ]

    init(provider: Provider, isEmbedded: Bool = false) {
        self.provider = provider
        self.isEmbedded = isEmbedded
        self._viewModel = State(initialValue: ProviderUsageViewModel(provider: provider))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            content

        }
        .if(!isEmbedded) { view in
            view.navigationTitle(usageNavigationTitle)
        }
        .task(id: provider.id) {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: provider.id) { _, _ in
            viewModel = ProviderUsageViewModel(provider: provider)
            Task { await viewModel.loadIfNeeded() }
        }
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: Bindable(viewModel).isShowingLogin) {
            UsageLoginSheet(title: provider.name, url: viewModel.dashboardURL)
        }
        .sheet(isPresented: $viewModel.isShowingLoginURLSheet, onDismiss: {
            viewModel.handleLoginURLSheetDismissed()
        }) {
            CodexLoginURLSheet(
                mode: viewModel.loginModeForSheet ?? "Login",
                url: viewModel.loginURLForSheet,
                onCopy: { viewModel.copyLoginURL() },
                onOpen: { viewModel.reopenLoginURLInBrowser() },
                onCancel: { viewModel.cancelCLILoginIfNeeded() }
            )
        }
        .fileImporter(
            isPresented: $viewModel.isShowingAuthFileImporter,
            allowedContentTypes: [.json, .data, .zip],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await viewModel.handleCodexImportURLs(urls) }
            case .failure:
                viewModel.importedAuthFileURLs = []
            }
        }
        .sheet(isPresented: $viewModel.isShowingCodexImportSheet, onDismiss: {
            viewModel.dismissCodexImportSheet()
        }) {
            CodexImportSheet(
                sections: viewModel.codexImportCandidateSections,
                isRunningValidation: viewModel.isRunningCodexImportValidation,
                isRunningConnectionTests: viewModel.isRunningCodexImportConnectionTests,
                isTargetingDropZone: Binding(
                    get: { viewModel.isTargetingCodexImportDropZone },
                    set: { viewModel.isTargetingCodexImportDropZone = $0 }
                ),
                globalErrorMessage: viewModel.codexImportGlobalErrorMessage,
                onPickFiles: { viewModel.presentCodexImportFilePicker() },
                onPaste: {
                    Task { await viewModel.pasteCodexImportFromClipboard() }
                },
                onDropFiles: { urls in
                    Task { await viewModel.handleCodexImportURLs(urls) }
                },
                onToggleSelection: { id, selected in
                    viewModel.setCodexImportCandidateSelected(selected, id: id)
                },
                onToggleGroupSelection: { groupID, selected in
                    viewModel.setCodexImportCandidatesSelected(selected, sourceGroupID: groupID)
                },
                onSelectAll: { viewModel.setAllCodexImportCandidatesSelected(true) },
                onDeselectAll: { viewModel.setAllCodexImportCandidatesSelected(false) },
                onRetry: { id in
                    Task { await viewModel.retryCodexImportConnectionTest(id: id) }
                },
                onRetryAll: {
                    Task { await viewModel.retryAllCodexImportConnectionTests() }
                },
                onRemove: { id in
                    viewModel.removeCodexImportCandidate(id: id)
                },
                onImport: {
                    Task { await viewModel.applySelectedCodexImports() }
                },
                onCancel: { viewModel.dismissCodexImportSheet() }
            )
        }
        .sheet(isPresented: $viewModel.isShowingCodexConfigEditor) {
            CodexConfigEditorSheet(
                draft: Binding(
                    get: { viewModel.codexConfigEditorDraft },
                    set: { viewModel.codexConfigEditorDraft = $0 }
                ),
                errorMessage: viewModel.codexConfigEditorErrorMessage,
                testSuccessMessage: viewModel.codexUsageQueryTestSuccessMessage,
                testErrorMessage: viewModel.codexUsageQueryTestErrorMessage,
                isTestingUsageQuery: viewModel.isTestingCodexUsageQuery,
                onCancel: { viewModel.dismissCodexConfigEditor() },
                onTest: { Task { await viewModel.testCodexUsageQueryDraft() } },
                onSave: { Task { await viewModel.saveCodexConfigEditor() } }
            )
        }
        .alert(
            NSLocalizedString("gemini.import.confirm.title", value: "Import Existing Gemini Login?", comment: "Gemini import confirmation title"),
            isPresented: $viewModel.isShowingGeminiImportConfirm
        ) {
            Button(
                NSLocalizedString("gemini.import.confirm.skip", value: "Continue OAuth Login", comment: "Continue OAuth login"),
                role: .cancel
            ) {
                viewModel.continueGeminiOAuthLoginWithoutImport()
            }
            Button(NSLocalizedString("gemini.import.confirm.import", value: "Import", comment: "Import existing Gemini login")) {
                Task { await viewModel.importGeminiGlobalSessionAfterConfirmation() }
            }
        } message: {
            let email = viewModel.pendingGeminiImportCandidate?.email ?? NSLocalizedString("generic.unknown", value: "Unknown", comment: "Unknown")
            let path = viewModel.pendingGeminiImportCandidate?.geminiDirectoryPath ?? "~/.gemini"
            let format = NSLocalizedString(
                "gemini.import.confirm.message",
                value: "Detected an existing Gemini CLI login (%@) at:\n%@\n\nImport it into Nolon now?",
                comment: "Gemini import confirmation message"
            )
            Text(String(format: format, email, path))
        }
        .alert(viewModel.alertTitle ?? "", isPresented: Binding(get: {
            viewModel.alertTitle != nil || viewModel.alertMessage != nil
        }, set: { newValue in
            if !newValue {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        })) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert(
            NSLocalizedString("codex.accounts.activate.title", value: "Activate Account", comment: "Activate account title"),
            isPresented: $viewModel.isShowingActivateConfirm
        ) {
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.pendingActivateCodexAccount = nil
            }
            Button(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account")) {
                Task { await viewModel.confirmActivate() }
            }
        } message: {
            let name = viewModel.pendingActivateCodexAccount?.name ?? ""
            let path = viewModel.codexAuthFilePath ?? "~/.codex/auth.json"
            let format = NSLocalizedString(
                "codex.accounts.activate.message",
                value: "Switch to \"%@\"? This will overwrite:\n%@",
                comment: "Activate account message"
            )
            Text(String(format: format, name, path))
        }
        .alert(
            NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"),
            isPresented: $viewModel.isShowingDeleteConfirm
        ) {
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.pendingDeleteCodexAccount = nil
            }
            Button(NSLocalizedString("generic.delete", value: "Delete", comment: "Delete"), role: .destructive) {
                Task { await viewModel.confirmDeleteCodexAccount() }
            }
        } message: {
            let account = viewModel.pendingDeleteCodexAccount
            let baseName = account?.name ?? ""
            let email = account.flatMap { candidate in
                viewModel.codexAccountSummaries[candidate.id]?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let displayName: String = {
                guard let email, !email.isEmpty else { return baseName }
                return "\(baseName) (\(email))"
            }()
            let format = NSLocalizedString(
                "codex.accounts.delete.message",
                value: "Delete \"%@\"? This will not log you out of Codex, it only removes the saved snapshot in Nolon.",
                comment: "Delete account message"
            )
            Text(String(format: format, displayName))
        }
        .task(id: viewModel.settings.autoRefreshIntervalMinutes) {
            let minutes = viewModel.settings.autoRefreshIntervalMinutes
            guard minutes > 0 else { return }
            let interval = UInt64(minutes) * 60 * 1_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { break }
                await viewModel.performAutoRefresh()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isShowingCopyToast {
                ToastView(
                    text: viewModel.copyToastMessage,
                    systemImage: "doc.on.doc",
                    style: .success
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isShowingCopyToast)
    }

    private var autoRefreshIntervalBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.autoRefreshIntervalMinutes },
            set: { newValue in
                var updated = viewModel.settings
                updated.autoRefreshIntervalMinutes = newValue
                viewModel.settings = updated
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.usageProvider == nil {
            ContentUnavailableView(
                NSLocalizedString("usage.monitor.unsupported.title", value: "Usage not supported", comment: "Unsupported title"),
                systemImage: "chart.bar.xaxis",
                description: Text(NSLocalizedString(
                    "usage.monitor.unsupported.desc",
                    value: "Usage is not configured for this provider yet.",
                    comment: "Unsupported description"
                ))
                .dsSecondaryText(font: .body)
            )
        } else if viewModel.usageProvider == .codex {
            codexContent
        } else if viewModel.outcomes.isEmpty {
            if viewModel.isLoading {
                loadingOverlay
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"),
                    systemImage: "chart.bar",
                    description: Text(NSLocalizedString("usage.monitor.empty.desc", value: "No provider data available yet.", comment: "Empty description"))
                        .dsSecondaryText(font: .body)
                )
            }
        } else {
            genericUsageContent
                .overlay {
                    if viewModel.isLoading {
                        loadingOverlay
                    }
                }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.45))
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(provider.name)
                .font(.headline)

            Spacer()

            if viewModel.usageProvider == .codex {
                if viewModel.isCodexMultiSelectionEnabled {
                    Text(String(
                        format: NSLocalizedString(
                            "codex.accounts.selection.count",
                            value: "已选 %d",
                            comment: "Selected Codex account count"
                        ),
                        viewModel.codexSelectedAccountCount
                    ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                    Button(NSLocalizedString("codex.accounts.action.export_zip", value: "导出 ZIP", comment: "Export selected Codex accounts to ZIP")) {
                        Task { await viewModel.exportSelectedCodexAccountsAsZIP() }
                    }
                    .disabled(!viewModel.canExportSelectedCodexAccounts)

                    Button(NSLocalizedString("codex.accounts.action.done_selecting", value: "完成", comment: "Done selecting Codex accounts")) {
                        viewModel.setCodexMultiSelectionEnabled(false)
                    }
                }

                ForEach(viewModel.codexPrimaryHeaderActions) { action in
                    switch action {
                    case .refreshAll:
                        Button(NSLocalizedString("codex.accounts.refresh_all", value: "刷新", comment: "Codex refresh all")) {
                            viewModel.handleHeaderRefreshButtonTap()
                        }
                        .disabled(viewModel.isLoading && !viewModel.isCodexHeaderRefreshing)
                    case .login:
                        Button(NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login")) {
                            viewModel.startLoginFlow()
                        }
                        .disabled(viewModel.isRunningCLILogin)
                    case .importAuth:
                        Button(NSLocalizedString("codex.accounts.import", value: "导入", comment: "Codex import")) {
                            viewModel.beginImportAuthFiles()
                        }
                    case .editConfig:
                        Button(NSLocalizedString("codex.accounts.action.edit", value: "Edit", comment: "Edit configured account")) {
                            viewModel.beginEditActiveCodexConfiguredAccount()
                        }
                        .disabled(!viewModel.codexAccountSupportsEditing(accountID: viewModel.activeCodexAccountId))
                    case .validateConfig:
                        Button(NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")) {
                            viewModel.validateActiveCodexConfiguredAccount()
                        }
                        .disabled({
                            guard let activeID = viewModel.activeCodexAccountId else { return true }
                            return viewModel.codexRefreshingAccountIds.contains(activeID)
                        }())
                    }
                }
                actionsMenu
            } else {
                if ProviderUsageLoginPolicy.shouldUseCLILogin(for: provider) {
                    Button(NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login")) {
                        viewModel.startLoginFlow()
                    }
                    .disabled(viewModel.isRunningCLILogin)
                    Button(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")) {
                        Task { await viewModel.load() }
                    }
                    .disabled(viewModel.isLoading)
                } else if ProviderUsageLoginPolicy.shouldShowDashboardSignIn(for: provider, dashboardURL: viewModel.dashboardURL) {
                    Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                        viewModel.isShowingLogin = true
                    }
                } else {
                    Button(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")) {
                        Task { await viewModel.load() }
                    }
                    .disabled(viewModel.isLoading)
                }
                actionsMenu
            }
        }
        .onChange(of: viewModel.settings) { _, newValue in
            viewModel.updateSettings(newValue)
        }
    }

    private var usageNavigationTitle: String {
        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            return NSLocalizedString("tab.account_usage", value: "账号与用量", comment: "Account and usage")
        }
        return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
    }

    private var actionsMenu: some View {
        Menu {
            if viewModel.usageProvider != .codex {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: "arrow.clockwise")
                }

                Divider()
            }

            if viewModel.usageProvider == .codex {
                Picker(
                    selection: Binding(
                        get: { viewModel.codexAccountGroupingOption },
                        set: { viewModel.codexAccountGroupingOption = $0 }
                    )
                ) {
                    Text(NSLocalizedString("codex.accounts.grouping.none", value: "无分组", comment: "No grouping"))
                        .tag(ProviderUsageViewModel.CodexAccountGroupingOption.none)
                    Text(NSLocalizedString("codex.accounts.grouping.type_info", value: "按套餐/提供商分组", comment: "Group by type info"))
                        .tag(ProviderUsageViewModel.CodexAccountGroupingOption.typeInfo)
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.grouping.title", value: "分组", comment: "Grouping title"),
                        systemImage: "square.grid.2x2"
                    )
                }

                Menu {
                    ForEach(viewModel.codexSortMenuOptions) { option in
                        Button {
                            viewModel.selectCodexSortOption(option)
                        } label: {
                            let isSelected = viewModel.codexAccountSortOption == option
                            HStack {
                                Text(
                                    ProviderUsageViewModel.codexSortMenuItemTitle(
                                        for: option,
                                        direction: isSelected ? viewModel.codexDirection(for: option) : nil
                                    )
                                )
                                if isSelected {
                                    Spacer(minLength: 8)
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.sorting.title", value: "排序", comment: "Sorting title"),
                        systemImage: "arrow.up.arrow.down"
                    )
                }

                Divider()

                Button {
                    viewModel.toggleCodexMultiSelectionMode()
                } label: {
                    Label(
                        viewModel.isCodexMultiSelectionEnabled
                            ? NSLocalizedString("codex.accounts.action.done_selecting", value: "完成", comment: "Done selecting Codex accounts")
                            : NSLocalizedString("codex.accounts.action.multi_select", value: "进入多选", comment: "Enter Codex multi-select mode"),
                        systemImage: viewModel.isCodexMultiSelectionEnabled ? "checkmark.circle" : "checklist"
                    )
                }

                if viewModel.isCodexMultiSelectionEnabled {
                    Button {
                        Task { await viewModel.exportSelectedCodexAccountsAsZIP() }
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.export_zip", value: "导出 ZIP", comment: "Export selected Codex accounts to ZIP"),
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .disabled(!viewModel.canExportSelectedCodexAccounts)

                    Button {
                        viewModel.selectedCodexAccountIDs.removeAll()
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.clear_selection", value: "清空选择", comment: "Clear Codex selection"),
                            systemImage: "xmark.circle"
                        )
                    }
                    .disabled(viewModel.selectedCodexAccountIDs.isEmpty)

                    Divider()
                }

                Button {
                    viewModel.beginNewCodexAPIKeyAccount()
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.action.new_api_key", value: "新增 API Key", comment: "New API key account"),
                        systemImage: "key"
                    )
                }

                Button {
                    viewModel.beginNewCodexRelayAccount()
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.action.new_relay", value: "新增 Relay", comment: "New relay account"),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                }

                Divider()
            }

            Picker(selection: autoRefreshIntervalBinding) {
                ForEach(UsageAutoRefreshInterval.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            } label: {
                Label(
                    NSLocalizedString("usage.monitor.auto_refresh.title", value: "Auto refresh", comment: "Auto refresh interval"),
                    systemImage: "timer"
                )
            }

            if viewModel.isRunningCLILogin {
                Button {
                    viewModel.cancelCLILoginIfNeeded()
                } label: {
                    Label(
                        NSLocalizedString("codex.cli_login.cancel", value: "Cancel Login", comment: "Cancel CLI login"),
                        systemImage: "xmark.circle"
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var genericUsageContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.shouldShowGeminiImportAction {
                    geminiImportCallout
                }
                ForEach(viewModel.outcomes) { outcome in
                    ProviderUsageSnapshotView(outcome: outcome)
                }
                if viewModel.usageProvider == .gemini {
                    tokenTrendSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var geminiImportCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString(
                "gemini.import.inline.title",
                value: "Detected existing Gemini login",
                comment: "Inline Gemini import title"
            ))
            .font(.headline)

            Text(NSLocalizedString(
                "gemini.import.inline.body",
                value: "Nolon found an existing Gemini CLI session on this machine. Import it to activate this provider immediately.",
                comment: "Inline Gemini import body"
            ))
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)

            HStack(spacing: 8) {
                Button(NSLocalizedString(
                    "gemini.import.inline.import",
                    value: "Import Existing Login",
                    comment: "Inline Gemini import CTA"
                )) {
                    viewModel.presentGeminiImportConfirmation()
                }
                .buttonStyle(.borderedProminent)

                Button(NSLocalizedString(
                    "gemini.import.inline.oauth",
                    value: "Sign in with OAuth",
                    comment: "Inline Gemini OAuth CTA"
                )) {
                    viewModel.continueGeminiOAuthLoginWithoutImport()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard()
    }

    private var codexCurrentOutcome: ProviderAccountUsageOutcome? {
        if let outcome = viewModel.outcomes.first(where: { outcome in
            if case .default = outcome.account { return true }
            return false
        }) {
            return outcome
        }
        return viewModel.outcomes.first
    }

    private func creditsRefreshedAt(for outcome: ProviderAccountUsageOutcome) -> Date? {
        guard viewModel.usageProvider == .codex else { return nil }
        switch outcome.account {
        case let .tokenAccount(account):
            return viewModel.codexAccountCreditsRefreshedAt[account.id]
        case .default:
            if let activeId = viewModel.activeCodexAccountId {
                return viewModel.codexAccountCreditsRefreshedAt[activeId]
            }
            return nil
        }
    }

    private var codexContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                codexManagementCard

                if viewModel.codexAccounts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"),
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text(NSLocalizedString(
                            "codex.accounts.empty.desc",
                            value: "Add a snapshot of Codex auth.json to quickly switch accounts.",
                            comment: "Empty state description"
                        ))
                        .dsSecondaryText(font: .body)
                    )
                }

                ForEach(viewModel.codexAccountDisplaySections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = section.title {
                            Button {
                                viewModel.toggleCodexSection(section.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.isCodexSectionCollapsed(section.id) ? "chevron.right" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    Text(title)
                                        .font(.headline)
                                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                                    Text("\(section.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        if !viewModel.isCodexSectionCollapsed(section.id) {
                            LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                                ForEach(section.items) { outcome in
                                    codexOutcomeCard(outcome: outcome)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .animation(.snappy(duration: 0.2), value: viewModel.collapsedCodexSectionIDs)

                if viewModel.isLoading && viewModel.codexAccountOutcomes.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(NSLocalizedString("usage.monitor.refreshing", value: "Refreshing…", comment: "Refreshing status"))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                tokenTrendSection
            }
            .padding(.trailing, 12)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var codexManagementCard: some View {
        if let status = viewModel.codexManagementStatus, status.needsEnable || status.needsMigration {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("codex.management.title", value: "管理状态", comment: "Codex management status"))
                        .font(.headline)
                    Text(NSLocalizedString("codex.management.desc", value: "首次使用建议先启用管理并执行数据迁移。", comment: "Codex management description"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
                Spacer()
                Button(NSLocalizedString("codex.management.enable", value: "启用管理", comment: "Enable codex management")) {
                    Task { await viewModel.enableCodexManagement() }
                }
                Button(NSLocalizedString("codex.management.migrate", value: "数据迁移", comment: "Migrate codex data")) {
                    Task { await viewModel.migrateCodexManagementData() }
                }
            }
            .padding(12)
            .dsCard()
        }
    }

    private var tokenTrendSection: some View {
        ProviderTokenTrendSection(
            snapshot: viewModel.tokenTrendSnapshot,
            isLoading: viewModel.isLoadingTokenTrend,
            errorMessage: viewModel.tokenTrendErrorMessage,
            range: viewModel.tokenTrendRange,
            onRangeChange: { viewModel.setTokenTrendRange($0) },
            onRefresh: { viewModel.refreshTokenTrendNow() }
        )
    }

    @ViewBuilder
    private func codexOutcomeCard(outcome: ProviderAccountUsageOutcome) -> some View {
        let accountId: UUID? = {
            switch outcome.account {
            case .default:
                return nil
            case let .tokenAccount(account):
                return account.id
            }
        }()

        let isPending: Bool = {
            guard let accountId else { return false }
            return viewModel.pendingActivateCodexAccount?.id == accountId
        }()

        let isActive: Bool = {
            guard let accountId else { return false }
            guard let saved = viewModel.codexAccounts.first(where: { $0.id == accountId }) else { return false }
            return viewModel.isActiveCodexAccount(saved)
        }()

        let isBatchSelected = viewModel.isCodexAccountSelected(id: accountId)

        let isSelected = isActive || isPending || isBatchSelected
        let borderColor = isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.6)
        let borderStyle = StrokeStyle(
            lineWidth: isSelected ? 2 : 1,
            dash: isPending && !isActive ? [6, 4] : []
        )
        let summary = accountId.flatMap { viewModel.codexAccountSummaries[$0] }
        let isRefreshing: Bool = {
            guard let id = accountId else { return false }
            return viewModel.codexRefreshingAccountIds.contains(id)
        }()
        let canLogin = viewModel.codexAccountSupportsLogin(accountID: accountId)
        let canEdit = viewModel.codexAccountSupportsEditing(accountID: accountId)
        let isLoggingIn = accountId != nil
            && viewModel.isRunningCLILogin
            && viewModel.cliLoginPreferredAccountId == accountId
        let onLogin: (() -> Void)? = canLogin ? accountId.map { id in
            { viewModel.requestLoginForCodexAccount(id: id) }
        } : nil
        let displayState = viewModel.displayState(accountID: accountId, outcome: outcome, summary: summary)
        let statusTitle = codexAccountStatusTitle(for: displayState)
        let lastSync = summary?.lastSyncSucceededAt
        let liveFailureError: Error? = {
            if case let .failure(error) = outcome.outcome.result { return error }
            return nil
        }()
        let persistedFailureDetail = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let failureDetail: String? = {
            if let persistedFailureDetail, !persistedFailureDetail.isEmpty { return persistedFailureDetail }
            if let liveFailureError { return ProviderUsageViewModel.errorDetailText(error: liveFailureError) }
            return nil
        }()
        let failureSummary: String? = {
            if let liveFailureError {
                return ProviderUsageViewModel.errorSummaryText(error: liveFailureError)
            }
            if let failureDetail {
                if canLogin, CodexAuthFailureClassifier.isAuthFailure(errorText: failureDetail) {
                    return NSLocalizedString(
                        "codex.accounts.error.auth_expired",
                        value: "Authentication expired. Please sign in again.",
                        comment: "Codex auth expired summary"
                    )
                }
                return failureDetail
            }
            return nil
        }()

        codexCompactSnapshotView(
            outcome: outcome,
            isSelected: isSelected,
            isRefreshing: isRefreshing,
            summary: summary,
            onRefresh: accountId.map { id in
                { viewModel.refreshCodexAccount(id: id) }
            },
            onLogin: onLogin,
            isLoggingIn: isLoggingIn
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(
                    borderColor,
                    style: borderStyle
                )
                .overlay(alignment: .topTrailing) {
                    if viewModel.isCodexMultiSelectionEnabled, isBatchSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(DesignSystem.Colors.primary)
                            .padding(10)
                    }
                }
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .fill(DesignSystem.Colors.primary.opacity(isActive ? 0.16 : (isBatchSelected ? 0.14 : 0.1)))
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .fill(DesignSystem.Colors.Background.elevated)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        .onTapGesture {
            guard let accountId else { return }
            if viewModel.isCodexMultiSelectionEnabled {
                viewModel.toggleCodexAccountSelection(id: accountId)
                return
            }
            guard !isActive else { return }
            viewModel.requestActivateCodexAccount(id: accountId)
        }
        .contextMenu {
            if let accountId {
                Button {
                } label: {
                    Label(statusTitle, systemImage: "circle.fill")
                }
                .disabled(true)

                if isRefreshing {
                    Button {} label: {
                        Label(
                            NSLocalizedString("usage.monitor.refreshing", value: "Refreshing…", comment: "Refreshing status"),
                            systemImage: "arrow.trianglehead.clockwise"
                        )
                    }
                        .disabled(true)
                }

                if let failureSummary {
                    Button {} label: {
                        Label(failureSummary, systemImage: "exclamationmark.triangle")
                    }
                        .disabled(true)
                }

                if let lastSync {
                    let prefix = NSLocalizedString("codex.accounts.sync.success", value: "Last sync", comment: "Last sync label")
                    Button {} label: {
                        Label(
                            "\(prefix): \(lastSync.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "clock"
                        )
                    }
                        .disabled(true)
                }

                Divider()

                Button {
                    viewModel.refreshCodexAccount(id: accountId)
                } label: {
                    Label(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)

                if !isActive {
                    Button {
                        viewModel.requestActivateCodexAccount(id: accountId)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
                            systemImage: "checkmark.circle"
                        )
                    }
                }

                if canEdit {
                    Button {
                        viewModel.beginEditCodexConfiguredAccount(id: accountId)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.edit", value: "Edit", comment: "Edit configured account"),
                            systemImage: "pencil"
                        )
                    }
                }

                if let onLogin, canLogin {
                    Button {
                        onLogin()
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
                            systemImage: "person.badge.key"
                        )
                    }
                    .disabled(!canLogin || isLoggingIn)
                }

                if canEdit {
                    Button {
                        viewModel.refreshCodexAccount(id: accountId)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account"),
                            systemImage: "checkmark.shield"
                        )
                    }
                    .disabled(isRefreshing)
                }

                if let failureDetail {
                    Button {
                        viewModel.copyErrorText(failureDetail)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"),
                            systemImage: "doc.on.doc"
                        )
                    }
                }

                if isLoggingIn {
                    Button {} label: {
                        Label(
                            NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status"),
                            systemImage: "hourglass"
                        )
                    }
                        .disabled(true)
                }

                Divider()

                Button {
                    viewModel.revealCodexAccountInFinder(id: accountId)
                } label: {
                    Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                }

                Button {
                    viewModel.copyCodexAccountID(id: accountId)
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.menu.copy_account_id", value: "Copy Account ID", comment: "Copy account id"),
                        systemImage: "number"
                    )
                }

                Button {
                    viewModel.copyCodexAccountAuthJSON(id: accountId)
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.menu.copy_auth_json", value: "Copy Auth JSON", comment: "Copy auth json"),
                        systemImage: "doc.on.doc"
                    )
                }

                Button {
                    viewModel.copyCodexAccountPath(id: accountId)
                } label: {
                    Label(
                        NSLocalizedString("codex.accounts.menu.copy_auth_path", value: "Copy Auth Path", comment: "Copy auth path"),
                        systemImage: "doc.text"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.requestDeleteCodexAccount(id: accountId)
                } label: {
                    Label(NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"), systemImage: "trash")
                }
            }
        }
    }

    private func codexAccountStatusTitle(for state: ProviderUsageViewModel.CodexAccountDisplayState) -> String {
        switch state {
        case .healthy:
            return NSLocalizedString("codex.accounts.status.normal", value: "Normal", comment: "Account status normal")
        case .pending:
            return NSLocalizedString("codex.accounts.status.pending", value: "Pending", comment: "Account status pending")
        case .needsReauth:
            return NSLocalizedString("codex.accounts.status.reauth_needed", value: "Needs re-login", comment: "Account status reauth")
        case .failed:
            return NSLocalizedString("codex.accounts.status.failed", value: "Failed", comment: "Account status failed")
        }
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        outcome: ProviderAccountUsageOutcome,
        isSelected: Bool,
        isRefreshing: Bool,
        summary: CodexAuthSummary?,
        onRefresh: (() -> Void)?,
        onLogin: (() -> Void)?,
        isLoggingIn: Bool
    ) -> some View {
        let accountId: UUID? = {
            switch outcome.account {
            case .default:
                return nil
            case let .tokenAccount(account):
                return account.id
            }
        }()
        let title = outcome.displayName
        let fallbackEmail = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPlan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastLogin = summary?.lastLoginAt
        let lastSync = summary?.lastSyncSucceededAt
        let loginInlineText: String? = {
            guard let lastLogin else { return nil }
            let isChinese = Locale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
            let prefix = isChinese ? "登录于 " : "Logged in at "
            return "\(prefix)\(CodexAccountInlineTimeFormatter.loginTimestamp(lastLogin))"
        }()
        let syncInlineText: String? = {
            guard let lastSync else { return nil }
            let isChinese = Locale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
            let syncDisplay = CodexAccountInlineTimeFormatter.syncDisplay(
                since: lastSync,
                isChinese: isChinese
            )
            switch syncDisplay {
            case .justNow:
                return NSLocalizedString(
                    "codex.accounts.time.sync.just_now",
                    value: "刚刚同步",
                    comment: "Inline sync just now text"
                )
            case let .relative(relativeText):
                return isChinese ? "\(relativeText)前同步" : "Synced \(relativeText) ago"
            case let .absolute(absoluteText):
                return isChinese ? "\(absoluteText)同步" : "Synced \(absoluteText)"
            }
        }()
        let inlineTimeLineText = CodexAccountInlineTimeFormatter.joinInlineTimeLine(
            loginSegment: loginInlineText,
            syncSegment: syncInlineText
        )
        let displayState = viewModel.displayState(accountID: accountId, outcome: outcome, summary: summary)
        let liveFailureError: Error? = {
            if case let .failure(error) = outcome.outcome.result { return error }
            return nil
        }()
        let persistedFailureDetail = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let failureDetail: String? = {
            if let persistedFailureDetail, !persistedFailureDetail.isEmpty { return persistedFailureDetail }
            if let liveFailureError { return ProviderUsageViewModel.errorDetailText(error: liveFailureError) }
            return nil
        }()
        let failureSummary: String? = {
            if let liveFailureError {
                return ProviderUsageViewModel.errorSummaryText(error: liveFailureError)
            }
            if let failureDetail {
                if onLogin != nil, CodexAuthFailureClassifier.isAuthFailure(errorText: failureDetail) {
                    return NSLocalizedString(
                        "codex.accounts.error.auth_expired",
                        value: "Authentication expired. Please sign in again.",
                        comment: "Codex auth expired summary"
                    )
                }
                return failureDetail
            }
            return nil
        }()
        let needsReauth = displayState == .needsReauth
        let shouldShowUsageMetrics = failureSummary == nil && (displayState == .healthy || displayState == .pending)
        let statusKind = CodexUsageCardPresentationPolicy.statusKind(for: displayState)
        let statusColor = statusColor(for: statusKind)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.primary)
                    .lineLimit(1)

                Spacer()

                if let onRefresh {
                    Button {
                        onRefresh()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .dsIconButton(size: 18, foreground: DesignSystem.Colors.Text.secondary)
                        }
                    }
                    .dsBorderlessButton()
                    .help(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"))
                }
            }

            switch outcome.outcome.result {
            case let .success(result):
                let identity = result.usage.identity?.scoped(to: outcome.provider)
                let email = (identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackEmail
                let plan = (identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackPlan

                if let subtitle = codexSubtitleText(title: title, email: email, plan: plan) {
                    Text(subtitle)
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                        .lineLimit(1)
                }

                let displayWindows = ProviderQuotaSection.displayWindows(for: result.usage, provider: outcome.provider)
                if shouldShowUsageMetrics, !displayWindows.isEmpty {
                    ProviderQuotaSection(
                        provider: outcome.provider,
                        usage: result.usage
                    )
                }
            case .failure:
                if let subtitle = codexSubtitleText(title: title, email: fallbackEmail, plan: fallbackPlan) {
                    Text(subtitle)
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                        .lineLimit(1)
                }
            }

            if let failureSummary, let failureDetail {
                VStack(alignment: .leading, spacing: 6) {
                    Text(failureSummary)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(2)

                    let actionLayout = CodexUsageCardPresentationPolicy.actionLayout(
                        needsReauth: needsReauth,
                        hasLoginAction: onLogin != nil
                    )
                    if actionLayout == .dualEqualWidth, let onLogin {
                        HStack(spacing: 8) {
                            Button {
                                viewModel.copyErrorText(failureDetail)
                            } label: {
                                Text(NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)

                            Button {
                                onLogin()
                            } label: {
                                Text(NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .disabled(isLoggingIn)
                        }
                    } else {
                        Button {
                            viewModel.copyErrorText(failureDetail)
                        } label: {
                            Text(NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                    }

                    if isLoggingIn {
                        Text(NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status"))
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
            }

            if let inlineTimeLineText {
                Text(inlineTimeLineText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .textSelection(.enabled)
        .dsCard(background: .clear, borderColor: nil, borderWidth: 0)
    }

    private func statusColor(for statusKind: CodexUsageCardStatusKind) -> Color {
        switch statusKind {
        case .error:
            return DesignSystem.Colors.Status.error
        case .healthy:
            return DesignSystem.Colors.Status.success
        case .pending:
            return DesignSystem.Colors.Text.secondary
        }
    }

    private func codexSubtitleText(title: String, email: String?, plan: String?) -> String? {
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = plan?.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = [
            (trimmedEmail?.isEmpty == false && trimmedEmail != title) ? trimmedEmail : nil,
            (trimmedPlan?.isEmpty == false) ? trimmedPlan : nil,
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func codexCreditsText(_ value: Double) -> String {
        if value.isInfinite {
            return NSLocalizedString("usage.metric.unlimited", value: "Unlimited", comment: "Unlimited")
        }
        if value.isNaN {
            return NSLocalizedString("usage.metric.unknown", value: "Unknown", comment: "Unknown")
        }
        return String(format: "%.0f", value)
    }

    private var isChineseLocale: Bool {
        if #available(macOS 13.0, *) {
            if let code = Locale.current.language.languageCode?.identifier {
                return code.hasPrefix("zh")
            }
        }
        return Locale.current.identifier.hasPrefix("zh")
    }

}
