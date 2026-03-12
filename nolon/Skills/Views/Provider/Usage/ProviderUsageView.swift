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
    private let claudeAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 12, alignment: .topLeading)
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
        .sheet(isPresented: $viewModel.isShowingCodexImportSheet, onDismiss: {
            viewModel.dismissCodexImportSheet()
        }) {
            CodexImportSheet(
                sections: viewModel.codexImportCandidateSections,
                hasAnyCandidates: viewModel.hasCodexImportCandidates,
                isRunningValidation: viewModel.isRunningCodexImportValidation,
                isRunningConnectionTests: viewModel.isRunningCodexImportConnectionTests,
                isTargetingDropZone: Binding(
                    get: { viewModel.isTargetingCodexImportDropZone },
                    set: { viewModel.isTargetingCodexImportDropZone = $0 }
                ),
                searchText: Binding(
                    get: { viewModel.codexImportSearchText },
                    set: { viewModel.codexImportSearchText = $0 }
                ),
                globalErrorMessage: viewModel.codexImportGlobalErrorMessage,
                onPickFiles: {
                    Task { await viewModel.presentCodexImportFilePicker() }
                },
                onPaste: {
                    Task { await viewModel.pasteCodexImportFromClipboard() }
                },
                onDropFiles: { urls in
                    Task { await viewModel.handleCodexImportURLs(urls) }
                },
                onToggleSelection: { id, selected in
                    Task { @MainActor in
                        viewModel.setCodexImportCandidateSelected(selected, id: id)
                    }
                },
                onToggleGroupSelection: { groupID, selected in
                    Task { @MainActor in
                        viewModel.setCodexImportCandidatesSelected(selected, sourceGroupID: groupID)
                    }
                },
                onSelectAll: {
                    Task { @MainActor in
                        viewModel.setAllCodexImportCandidatesSelected(true)
                    }
                },
                onDeselectAll: {
                    Task { @MainActor in
                        viewModel.setAllCodexImportCandidatesSelected(false)
                    }
                },
                onRetry: { id in
                    Task { await viewModel.retryCodexImportConnectionTest(id: id) }
                },
                onRetryAll: {
                    Task { await viewModel.retryAllCodexImportConnectionTests() }
                },
                onRemove: { id in
                    viewModel.removeCodexImportCandidate(id: id)
                },
                onExportZIP: {
                    Task { await viewModel.exportSelectedCodexImportCandidatesAsZIP() }
                },
                onExportSub2API: {
                    Task { await viewModel.exportSelectedCodexImportCandidatesAsSub2API() }
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
        } else if viewModel.usageProvider == .claude {
            claudeContent
        } else if viewModel.outcomes.isEmpty {
            if viewModel.isLoading {
                genericUsageLoadingContent
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
        }
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

                    Button(NSLocalizedString("codex.accounts.action.export_sub2api", value: "导出 sub2api", comment: "Export selected Codex accounts to sub2api")) {
                        Task { await viewModel.exportSelectedCodexAccountsAsSub2API() }
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
                if viewModel.usageProvider == .claude {
                    Button(NSLocalizedString("claude.accounts.migrate", value: "迁移", comment: "Migrate Claude accounts")) {
                        Task { await viewModel.migrateClaudeFromCurrentSettings() }
                    }
                    .disabled(viewModel.isLoading)
                    if ProviderUsageLoginPolicy.shouldShowDashboardSignIn(for: provider, dashboardURL: viewModel.dashboardURL) {
                        Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                            viewModel.isShowingLogin = true
                        }
                    }
                } else if ProviderUsageLoginPolicy.shouldUseCLILogin(for: provider) {
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

                if viewModel.usageProvider == .claude {
                    Divider()

                    Button {
                        Task { await viewModel.migrateClaudeFromCurrentSettings() }
                    } label: {
                        Label(
                            NSLocalizedString("claude.accounts.migrate.current", value: "迁移当前配置", comment: "Migrate Claude from current settings"),
                            systemImage: "tray.and.arrow.down"
                        )
                    }

                    Button {
                        Task { await viewModel.importClaudeFromCCSwitch() }
                    } label: {
                        Label(
                            NSLocalizedString("claude.accounts.migrate.cc_switch", value: "从 cc-switch 导入", comment: "Import Claude from cc-switch"),
                            systemImage: "square.and.arrow.down"
                        )
                    }
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
                        Task { await viewModel.exportSelectedCodexAccountsAsSub2API() }
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.export_sub2api", value: "导出 sub2api", comment: "Export selected Codex accounts to sub2api"),
                            systemImage: "doc.badge.arrow.up"
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
        let displayedOutcomes = ProviderUsageViewModel.displayedGenericUsageOutcomes(
            usageProvider: viewModel.usageProvider,
            hasGeminiAccounts: !viewModel.geminiAccounts.isEmpty,
            outcomes: viewModel.outcomes
        )
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.shouldShowGeminiImportAction {
                    geminiImportCallout
                }
                if let usageProvider = viewModel.usageProvider,
                   (usageProvider == .gemini || usageProvider == .antigravity),
                   !viewModel.geminiAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(provider.name)
                            .font(.headline)

                        LazyVGrid(columns: claudeAccountColumns, alignment: .leading, spacing: 12) {
                            ForEach(viewModel.geminiAccounts, id: \.id) { account in
                                geminiAccountCard(account: account)
                            }
                        }
                    }
                }
                ForEach(displayedOutcomes) { outcome in
                    ProviderUsageSnapshotView(outcome: outcome, isLoading: viewModel.isLoading)
                }
                if viewModel.usageProvider == .gemini {
                    tokenTrendSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var genericUsageLoadingContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.usageProvider == .gemini || viewModel.usageProvider == .antigravity {
                    ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                        UnifiedAccountCardSkeleton(providerName: provider.name)
                    }
                } else {
                    ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                        ProviderQuotaSection(
                            provider: viewModel.usageProvider ?? .codex,
                            usage: nil,
                            isLoading: true,
                            showsEmptyState: true
                        )
                    }
                }

                if viewModel.usageProvider == .gemini {
                    tokenTrendSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var claudeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.claudeAccounts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("claude.accounts.empty.title", value: "No Claude accounts", comment: "Empty Claude accounts title"),
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(
                            NSLocalizedString(
                                "claude.accounts.empty.desc",
                                value: "Use \"迁移\" or \"从 cc-switch 导入\" to add accounts.",
                                comment: "Empty Claude accounts description"
                            )
                        )
                        .dsSecondaryText(font: .body)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title"))
                            .font(.headline)

                        LazyVGrid(columns: claudeAccountColumns, alignment: .leading, spacing: 12) {
                            ForEach(viewModel.claudeAccounts, id: \.id) { account in
                                claudeAccountCard(account: account)
                            }
                        }
                    }
                }

                let usageOutcomes = viewModel.outcomes.filter { outcome in
                    if case let .failure(error) = outcome.outcome.result,
                       let usageError = error as? ProviderUsageError,
                       usageError == .unsupported(.claude) {
                        return false
                    }
                    return true
                }
                ForEach(usageOutcomes) { outcome in
                    ProviderUsageSnapshotView(outcome: outcome)
                }
            }
            .padding(.trailing, 12)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func claudeAccountCard(account: ClaudeAccount) -> some View {
        let isActive = viewModel.isActiveClaudeAccount(account)
        let record = AccountRecordBuilder.claude(
            providerName: "Claude",
            account: account,
            isActive: isActive
        )
        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: isActive ? [] : [
                .init(
                    id: "activate",
                    actionID: .activate,
                    title: NSLocalizedString("claude.accounts.action.activate", value: "激活", comment: "Activate Claude account"),
                    systemImage: nil,
                    role: nil,
                    prominence: .primary,
                    isEnabled: true
                )
            ],
            tapBehavior: isActive ? .none : .activate
        )
        return UnifiedAccountCard(
            data: data,
            onTap: { _ in
                guard !isActive else { return }
                Task { await viewModel.activateClaudeAccount(id: account.id) }
            },
            onAction: { _, action in
                guard action == .activate else { return }
                Task { await viewModel.activateClaudeAccount(id: account.id) }
            }
        )
    }

    private func geminiAccountCard(account: GeminiAuthAccount) -> some View {
        let isActive = viewModel.isActiveGeminiAccount(account)
        let liveOutcome = viewModel.outcomes.first
        let quota: AccountRecordQuota? = {
            guard isActive, let liveOutcome else { return nil }

            switch liveOutcome.outcome.result {
            case let .success(result):
                return .init(
                    provider: liveOutcome.provider,
                    accountTitle: account.email ?? account.name,
                    usage: result.usage,
                    credits: result.credits,
                    creditsRefreshedAt: nil,
                    loginAt: account.lastLoginAt,
                    syncedAt: result.usage.updatedAt,
                    isLoading: viewModel.isLoading,
                    showsEmptyState: false,
                    errorMessage: nil
                )
            case let .failure(error):
                return .init(
                    provider: liveOutcome.provider,
                    accountTitle: account.email ?? account.name,
                    usage: nil,
                    credits: nil,
                    creditsRefreshedAt: nil,
                    loginAt: account.lastLoginAt,
                    syncedAt: nil,
                    isLoading: viewModel.isLoading,
                    showsEmptyState: false,
                    errorMessage: ProviderUsageViewModel.errorDetailText(error: error)
                )
            }
        }()

        let record = AccountRecordBuilder.gemini(
            providerName: provider.name,
            account: account,
            isActive: isActive,
            quota: quota
        )
        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: isActive ? [
                .init(id: "refresh", actionID: .refresh, title: NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: nil, role: nil, prominence: .secondary, isEnabled: !viewModel.isLoading)
            ] : [
                .init(id: "activate", actionID: .activate, title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"), systemImage: nil, role: nil, prominence: .primary, isEnabled: true)
            ],
            menuActions: [
                .init(id: "delete", actionID: .delete, title: NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"), systemImage: "trash", role: .destructive, isEnabled: true)
            ],
            quotaRefreshActionID: isActive ? .refresh : nil,
            tapBehavior: isActive ? .none : .activate
        )
        return UnifiedAccountCard(
            data: data,
            onTap: { _ in
                guard !isActive else { return }
                Task { await viewModel.activateGeminiAccount(id: account.id) }
            },
            onAction: { _, action in
                switch action {
                case .activate:
                    Task { await viewModel.activateGeminiAccount(id: account.id) }
                case .refresh:
                    Task { await viewModel.load() }
                case .delete:
                    Task { await viewModel.deleteGeminiAccount(id: account.id) }
                default:
                    break
                }
            }
        )
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

                if viewModel.codexAccounts.isEmpty && !viewModel.isLoading {
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

                if viewModel.isLoading && viewModel.codexAccountOutcomes.isEmpty {
                    LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                        ForEach(0..<ProviderUsageSkeletonPolicy.codexCardCount, id: \.self) { _ in
                            ProviderQuotaSection(
                                provider: .codex,
                                usage: nil,
                                isLoading: true,
                                showsEmptyState: true
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
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

        let cardPresentation = AccountCardPresentation.codex(
            isActive: isActive,
            isPending: isPending,
            isBatchSelected: isBatchSelected
        )
        let summary = accountId.flatMap { viewModel.codexAccountSummaries[$0] }
        let isRefreshing: Bool = {
            guard let id = accountId else { return false }
            return viewModel.codexRefreshingAccountIds.contains(id)
        }()
        let canLogin = viewModel.codexAccountSupportsLogin(accountID: accountId)
        let isLoggingIn = accountId != nil
            && viewModel.isRunningCLILogin
            && viewModel.cliLoginPreferredAccountId == accountId
        let onLogin: (() -> Void)? = canLogin ? accountId.map { id in
            { viewModel.requestLoginForCodexAccount(id: id) }
        } : nil
        codexCompactSnapshotView(
            outcome: outcome,
            presentation: cardPresentation,
            isRefreshing: isRefreshing,
            summary: summary,
            onRefresh: accountId.map { id in
                { viewModel.refreshCodexAccount(id: id) }
            },
            onLogin: onLogin,
            isLoggingIn: isLoggingIn
        )
        .onTapGesture {
            guard let accountId else { return }
            if viewModel.isCodexMultiSelectionEnabled {
                viewModel.toggleCodexAccountSelection(id: accountId)
                return
            }
            guard !isActive else { return }
            viewModel.requestActivateCodexAccount(id: accountId)
        }
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        outcome: ProviderAccountUsageOutcome,
        presentation: AccountCardPresentation,
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
        let savedAccount = accountId.flatMap { id in
            viewModel.codexAccounts.first(where: { $0.id == id })
        }
        let title = CodexAccountDisplayNameResolver.resolve(
            summary: summary,
            relativeAuthPath: savedAccount?.relativeAuthPath,
            defaultName: outcome.displayName,
            accountID: accountId
        )
        let creditsRefreshedAt = creditsRefreshedAt(for: outcome)
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

        let primaryActions: [AccountCardActionViewData] = {
            guard let failureDetail else { return [] }
            var actions: [AccountCardActionViewData] = [
                .init(
                    id: "copyError",
                    actionID: .copyError,
                    title: NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"),
                    systemImage: nil,
                    role: nil,
                    prominence: onLogin == nil ? .primary : .secondary,
                    isEnabled: true
                )
            ]
            if onLogin != nil {
                actions.append(
                    .init(
                        id: "relogin",
                        actionID: .relogin,
                        title: NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
                        systemImage: nil,
                        role: nil,
                        prominence: .primary,
                        isEnabled: !isLoggingIn
                    )
                )
            } else if !failureDetail.isEmpty {
                _ = failureDetail
            }
            return actions
        }()

        let menuActions: [AccountCardMenuActionViewData] = {
            var items: [AccountCardMenuActionViewData] = []
            if onRefresh != nil {
                items.append(.init(id: "refresh", actionID: .refresh, title: NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: "arrow.clockwise", role: nil, isEnabled: !isRefreshing))
            }
            if onLogin != nil {
                items.append(.init(id: "relogin-menu", actionID: .relogin, title: NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"), systemImage: "person.badge.key", role: nil, isEnabled: !isLoggingIn))
            }
            if accountId != nil {
                items.append(.init(id: "reveal", actionID: .revealInFinder, title: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder", role: nil, isEnabled: true))
                items.append(.init(id: "delete", actionID: .delete, title: NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"), systemImage: "trash", role: .destructive, isEnabled: true))
            }
            return items
        }()

        let record = AccountRecordBuilder.codexUsage(
            outcome: outcome,
            summary: summary,
            presentation: presentation,
            title: title,
            creditsRefreshedAt: creditsRefreshedAt,
            isRefreshing: isRefreshing,
            canRelogin: onLogin != nil
        )

        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: primaryActions,
            menuActions: menuActions,
            footer: isLoggingIn ? .init(
                leadingTag: nil,
                trailingText: NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")
            ) : nil,
            quotaRefreshActionID: onRefresh == nil ? nil : .refresh,
            tapBehavior: .none
        )

        UnifiedAccountCard(
            data: data,
            onTap: { _ in },
            onAction: { _, action in
                switch action {
                case .refresh:
                    onRefresh?()
                case .relogin:
                    onLogin?()
                case .copyError:
                    if let failureDetail {
                        viewModel.copyErrorText(failureDetail)
                    }
                case .revealInFinder:
                    if let accountId {
                        viewModel.revealCodexAccountInFinder(id: accountId)
                    }
                case .delete:
                    if let accountId {
                        viewModel.requestDeleteCodexAccount(id: accountId)
                    }
                default:
                    break
                }
            }
        )
        .textSelection(.enabled)
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

    private func codexHeaderBadge(
        isSelected: Bool,
        needsReauth: Bool,
        isPending: Bool
    ) -> AccountSummaryCardBadgeModel? {
        if needsReauth {
            return .init(
                text: NSLocalizedString("codex.accounts.status.reauth_needed", value: "Needs re-login", comment: "Account status reauth"),
                tone: .warning
            )
        }
        if isPending {
            return .init(
                text: NSLocalizedString("codex.accounts.status.pending", value: "Pending", comment: "Account status pending"),
                tone: .neutral
            )
        }
        if isSelected {
            return .init(
                text: NSLocalizedString("accounts.summary.active", value: "已激活", comment: "Active badge"),
                tone: .active
            )
        }
        return nil
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
