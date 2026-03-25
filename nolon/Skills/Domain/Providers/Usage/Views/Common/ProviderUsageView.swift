import SwiftUI
import AppKit
import ProviderCatalog
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers
import NolonUIFoundation
import NolonUI

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
    static func statusKind(for state: ProviderUsageEngine.CodexAccountDisplayState) -> CodexUsageCardStatusKind {
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

struct ProviderUsageView: View, DebugPageLocatable {
    enum CodexListLayout {
        static let planColumnWidth: CGFloat = 96
        static let usageColumnWidth: CGFloat = 232
    }

    struct CodexListUsageWindow: Identifiable {
        let id: String
        let title: String
        let remainingPercent: Double
    }

    let provider: Provider
    let isEmbedded: Bool
    @State private var rootViewModel: ProviderUsageRootViewModel
    @State var targetingGatewayCardID: UUID?
    @State var gatewayAccountPickerCardID: UUID?
    @State var gatewayAccountPickerSelection: Set<UUID> = []
    private let codexAutoSwitchThresholdOptions: [Double] = [5, 10, 15, 20, 30]
    private let codexAutoSwitchCandidateOptions: [Double] = [10, 20, 30, 40, 50]

    let codexAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)
    ]
    let claudeAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 12, alignment: .topLeading)
    ]

    @MainActor
    init(provider: Provider, isEmbedded: Bool = false) {
        self.provider = provider
        self.isEmbedded = isEmbedded
        self._rootViewModel = State(initialValue: ProviderUsageRootViewModelStore.shared.viewModel(for: provider))
    }

    var viewModel: ProviderUsageAccountsViewModel {
        rootViewModel.accountsViewModel
    }

    var accountsViewModel: ProviderUsageAccountsViewModel {
        rootViewModel.accountsViewModel
    }

    var tokenTrendViewModel: ProviderTokenTrendViewModel {
        rootViewModel.tokenTrendViewModel
    }

    var importExportViewModel: CodexImportExportViewModel {
        rootViewModel.importExportViewModel
    }

    var loginFlowViewModel: ProviderLoginFlowViewModel {
        rootViewModel.loginFlowViewModel
    }

    var gatewayCardsViewModel: CodexGatewayCardsViewModel {
        rootViewModel.gatewayCardsViewModel
    }

    static func shouldUseFullWidthGeminiCardLayout(accountCount: Int) -> Bool {
        accountCount == 1
    }

    static func visibleCodexPrimaryHeaderActions(
        from actions: [ProviderUsageEngine.CodexPrimaryHeaderAction],
        isCodexMultiSelectionEnabled: Bool
    ) -> [ProviderUsageEngine.CodexPrimaryHeaderAction] {
        guard !isCodexMultiSelectionEnabled else { return [] }
        return Array(actions.prefix(2))
    }

    static func shouldShowActivateAccountContextAction(isActiveAccount: Bool) -> Bool {
        !isActiveAccount
    }

    static func shouldShowActivateGatewayContextAction(isActiveGateway: Bool) -> Bool {
        !isActiveGateway
    }

    static func shouldUseCompactCodexListRows(
        layoutMode: ProviderUsageEngine.CodexAccountLayoutMode
    ) -> Bool {
        layoutMode == .list
    }

    static func shouldEnableCodexTextSelection(
        layoutMode: ProviderUsageEngine.CodexAccountLayoutMode
    ) -> Bool {
        layoutMode != .list
    }

    static func gatewayMemberDisplayLimit(
        layoutMode: ProviderUsageEngine.CodexAccountLayoutMode
    ) -> Int {
        shouldUseCompactCodexListRows(layoutMode: layoutMode) ? 8 : 12
    }

    static func gatewayMemberRowMaxHeight(
        layoutMode: ProviderUsageEngine.CodexAccountLayoutMode
    ) -> CGFloat {
        shouldUseCompactCodexListRows(layoutMode: layoutMode) ? 48 : 70
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        [
            PageMarkerItem(title: provider.displayName),
            PageMarkerItem(title: ProviderContentTabType.usage.localizedName(for: provider))
        ]
    }

    var tokenTrendDebugPageMarkerItems: [PageMarkerItem] {
        debugPageMarkerItems + [
            PageMarkerItem(
                title: NSLocalizedString(
                    "usage.token_trend.title",
                    value: "历史 Token 消耗",
                    comment: "Token trend section title"
                )
            )
        ]
    }

    var gatewayCardsDebugPageMarkerItems: [PageMarkerItem] {
        debugPageMarkerItems + [
            PageMarkerItem(
                title: NSLocalizedString(
                    "codex.gateway.cards.title",
                    value: "网关卡片",
                    comment: "Gateway cards section title"
                )
            )
        ]
    }

    var body: some View {
        let baseView = AnyView(
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .if(!isEmbedded) { view in
                view.navigationTitle(usageNavigationTitle)
            }
            .task(id: provider.id) {
                _ = await rootViewModel.loadIfNeeded()
            }
            .onChange(of: provider.id) { _, _ in
                rootViewModel = ProviderUsageRootViewModelStore.shared.viewModel(for: provider)
                Task { _ = await rootViewModel.loadIfNeeded() }
            }
            .onChange(of: viewModel.settings) { _, _ in
                Task { await viewModel.load() }
            }
        )

        let withSheets = AnyView(
            AnyView(
                AnyView(
                    AnyView(
                        AnyView(
                            baseView.sheet(isPresented: isShowingLoginBinding) {
                                UsageLoginSheet(title: provider.name, url: loginFlowViewModel.dashboardURL)
                            }
                        )
                        .sheet(isPresented: isShowingLoginURLSheetBinding, onDismiss: {
                            loginFlowViewModel.handleLoginURLSheetDismissed()
                        }) {
                            CodexLoginURLSheet(
                                mode: loginFlowViewModel.loginModeForSheet ?? "Login",
                                url: loginFlowViewModel.loginURLForSheet,
                                onCopy: { loginFlowViewModel.copyLoginURL() },
                                onOpen: { loginFlowViewModel.reopenLoginURLInBrowser() },
                                onCancel: { loginFlowViewModel.cancelCLILoginIfNeeded() }
                            )
                        }
                    )
                    .sheet(isPresented: isShowingCodexImportSheetBinding, onDismiss: {
                        importExportViewModel.dismissCodexImportSheet()
                    }) {
                        CodexImportSheet(
                            sections: importExportViewModel.codexImportCandidateSections,
                            hasAnyCandidates: importExportViewModel.hasCodexImportCandidates,
                            isRunningValidation: importExportViewModel.isRunningCodexImportValidation,
                            isRunningConnectionTests: importExportViewModel.isRunningCodexImportConnectionTests,
                            isTargetingDropZone: Binding(
                                get: { importExportViewModel.isTargetingCodexImportDropZone },
                                set: { importExportViewModel.isTargetingCodexImportDropZone = $0 }
                            ),
                            searchText: Binding(
                                get: { importExportViewModel.codexImportSearchText },
                                set: { importExportViewModel.codexImportSearchText = $0 }
                            ),
                            globalErrorMessage: importExportViewModel.codexImportGlobalErrorMessage,
                            onPickFiles: { Task { await importExportViewModel.presentCodexImportFilePicker() } },
                            onPaste: { Task { await importExportViewModel.pasteCodexImportFromClipboard() } },
                            onDropFiles: { urls in Task { await importExportViewModel.handleCodexImportURLs(urls) } },
                            onToggleSelection: { id, selected in
                                Task { @MainActor in importExportViewModel.setCodexImportCandidateSelected(selected, id: id) }
                            },
                            onToggleGroupSelection: { groupID, selected in
                                Task { @MainActor in importExportViewModel.setCodexImportCandidatesSelected(selected, sourceGroupID: groupID) }
                            },
                            onSelectAll: { Task { @MainActor in importExportViewModel.setAllCodexImportCandidatesSelected(true) } },
                            onDeselectAll: { Task { @MainActor in importExportViewModel.setAllCodexImportCandidatesSelected(false) } },
                            onRetry: { id in Task { await importExportViewModel.retryCodexImportConnectionTest(id: id) } },
                            onRetryAll: { Task { await importExportViewModel.retryAllCodexImportConnectionTests() } },
                            onRemove: { id in importExportViewModel.removeCodexImportCandidate(id: id) },
                            onExportZIP: { Task { await importExportViewModel.exportSelectedCodexImportCandidatesAsZIP() } },
                            onExportSub2API: { Task { await importExportViewModel.exportSelectedCodexImportCandidatesAsSub2API() } },
                            onImport: { Task { await importExportViewModel.applySelectedCodexImports() } },
                            onCancel: { importExportViewModel.dismissCodexImportSheet() }
                        )
                    }
                )
                .sheet(isPresented: Binding(
                    get: { viewModel.codex.isShowingConfigEditor },
                    set: { viewModel.codex.isShowingConfigEditor = $0 }
                )) {
                    CodexConfigEditorSheet(
                        draft: Binding(
                            get: { viewModel.codex.configEditorDraft },
                            set: { viewModel.codex.configEditorDraft = $0 }
                        ),
                        errorMessage: viewModel.codex.configEditorErrorMessage,
                        testSuccessMessage: viewModel.codex.usageQueryTestSuccessMessage,
                        testErrorMessage: viewModel.codex.usageQueryTestErrorMessage,
                        isTestingUsageQuery: viewModel.codex.isTestingUsageQuery,
                        onCancel: { viewModel.codex.dismissConfigEditor() },
                        onTest: { Task { await viewModel.codex.testUsageQueryDraft() } },
                        onSave: { Task { await viewModel.codex.saveConfigEditor() } }
                    )
                }
            )
            .sheet(
                isPresented: Binding(
                    get: { viewModel.codex.isShowingGatewayCardPicker },
                    set: { if !$0 { gatewayCardsViewModel.dismissGatewayCardPicker() } }
                )
            ) { gatewayCardPickerSheet }
            .sheet(
                isPresented: Binding(
                    get: { gatewayAccountPickerCardID != nil },
                    set: { if !$0 { dismissGatewayAccountPicker() } }
                )
            ) {
                if let cardID = gatewayAccountPickerCardID {
                    gatewayAccountSelectionSheet(cardID: cardID)
                }
            }
        )

        let withAlerts = AnyView(
            AnyView(
                AnyView(
                    withSheets.alert(
                        NSLocalizedString("gemini.import.confirm.title", value: "Import Existing Gemini Login?", comment: "Gemini import confirmation title"),
                        isPresented: Binding(
                            get: { viewModel.gemini.isShowingImportConfirm },
                            set: { viewModel.gemini.isShowingImportConfirm = $0 }
                        )
                    ) {
                        Button(
                            NSLocalizedString("gemini.import.confirm.skip", value: "Continue OAuth Login", comment: "Continue OAuth login"),
                            role: .cancel
                        ) {
                            viewModel.gemini.continueOAuthLoginWithoutImport()
                        }
                        Button(NSLocalizedString("gemini.import.confirm.import", value: "Import", comment: "Import existing Gemini login")) {
                            Task { await viewModel.gemini.importGlobalSessionAfterConfirmation() }
                        }
                    } message: {
                        let email = viewModel.gemini.pendingImportCandidate?.email ?? NSLocalizedString("generic.unknown", value: "Unknown", comment: "Unknown")
                        let path = viewModel.gemini.pendingImportCandidate?.geminiDirectoryPath ?? "~/.gemini"
                        let format = NSLocalizedString(
                            "gemini.import.confirm.message",
                            value: "Detected an existing Gemini CLI login (%@) at:\n%@\n\nImport it into Nolon now?",
                            comment: "Gemini import confirmation message"
                        )
                        Text(String(format: format, email, path))
                    }
                )
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
            )
            .alert(
                NSLocalizedString("codex.accounts.activate.title", value: "Activate Account", comment: "Activate account title"),
                isPresented: Binding(
                    get: { viewModel.codex.isShowingActivateConfirm },
                    set: { viewModel.codex.isShowingActivateConfirm = $0 }
                )
            ) {
                Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                    viewModel.codex.pendingActivateAccount = nil
                }
                Button(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account")) {
                    Task { await viewModel.codex.confirmActivate() }
                }
            } message: {
                let name = viewModel.codex.pendingActivateAccount?.name ?? ""
                let path = viewModel.codex.authFilePath ?? "~/.codex/auth.json"
                let format = NSLocalizedString(
                    "codex.accounts.activate.message",
                    value: "Switch to \"%@\"? This will overwrite:\n%@",
                    comment: "Activate account message"
                )
                Text(String(format: format, name, path))
            }
            .alert(
                NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"),
                isPresented: Binding(
                    get: { viewModel.codex.isShowingDeleteConfirm },
                    set: { viewModel.codex.isShowingDeleteConfirm = $0 }
                )
            ) {
                Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                    viewModel.codex.pendingDeleteAccount = nil
                }
                Button(NSLocalizedString("generic.delete", value: "Delete", comment: "Delete"), role: .destructive) {
                    Task { await accountsViewModel.codex.confirmDeleteAccount() }
                }
            } message: {
                let account = viewModel.codex.pendingDeleteAccount
                let baseName = account?.name ?? ""
                let email = account.flatMap { candidate in
                    viewModel.codex.accountSummaries[candidate.id]?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
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
        )

        return withAlerts
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
            .overlay(alignment: Alignment.bottomTrailing) {
                if viewModel.isShowingCopyToast {
                    ToastView(
                        text: viewModel.copyToastMessage ?? "",
                        systemImage: "doc.on.doc",
                        style: .success
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Animation.easeOut(duration: 0.2), value: viewModel.isShowingCopyToast)
            .debugPageLocator(debugPageMarkerItems)
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

    private var isShowingLoginBinding: Binding<Bool> {
        Binding(
            get: { loginFlowViewModel.isShowingLogin },
            set: { loginFlowViewModel.isShowingLogin = $0 }
        )
    }

    private var isShowingLoginURLSheetBinding: Binding<Bool> {
        Binding(
            get: { loginFlowViewModel.isShowingLoginURLSheet },
            set: { loginFlowViewModel.isShowingLoginURLSheet = $0 }
        )
    }

    private var isShowingCodexImportSheetBinding: Binding<Bool> {
        Binding(
            get: { importExportViewModel.isShowingCodexImportSheet },
            set: { importExportViewModel.isShowingCodexImportSheet = $0 }
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
            .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: NSLocalizedString("usage.monitor.unsupported.title", value: "Usage not supported", comment: "Unsupported title"))])
        } else {
            usageContent
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(provider.name)
                .font(.headline)

            Spacer()

            if viewModel.capabilities.isCodexFamily {
                Button {
                    viewModel.codex.setHideZeroQuotaAccounts(!viewModel.codex.hideZeroQuotaAccounts)
                } label: {
                    Label(
                        viewModel.codex.hideZeroQuotaAccounts
                            ? NSLocalizedString("codex.accounts.filter.hide_zero_on", value: "显示全部账号", comment: "Show all Codex accounts")
                            : NSLocalizedString("codex.accounts.filter.hide_zero_off", value: "隐藏无额度账号", comment: "Hide zero-quota Codex accounts"),
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(
                    NSLocalizedString(
                        "codex.accounts.filter.hide_zero.help",
                        value: "切换是否显示额度为 0 的账号",
                        comment: "Help for hide zero quota filter"
                    )
                )

                Button {
                    viewModel.codex.setHideErroredAccounts(!viewModel.codex.hideErroredAccounts)
                } label: {
                    Label(
                        viewModel.codex.hideErroredAccounts
                            ? NSLocalizedString("codex.accounts.filter.hide_error_on", value: "显示报错账号", comment: "Show errored Codex accounts")
                            : NSLocalizedString("codex.accounts.filter.hide_error_off", value: "隐藏报错账号", comment: "Hide errored Codex accounts"),
                        systemImage: "exclamationmark.triangle"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(
                    NSLocalizedString(
                        "codex.accounts.filter.hide_error.help",
                        value: "切换是否隐藏报错账号",
                        comment: "Help for hide errored accounts filter"
                    )
                )

                Picker(
                    selection: Binding(
                        get: { viewModel.codex.accountLayoutMode },
                        set: { viewModel.codex.setAccountLayoutMode($0) }
                    )
                ) {
                    Text(NSLocalizedString("codex.accounts.layout.cards", value: "卡片", comment: "Codex account card layout"))
                        .tag(ProviderUsageEngine.CodexAccountLayoutMode.cards)
                    Text(NSLocalizedString("codex.accounts.layout.list", value: "列表", comment: "Codex account list layout"))
                        .tag(ProviderUsageEngine.CodexAccountLayoutMode.list)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 126)
                .help(
                    NSLocalizedString(
                        "codex.accounts.layout.help",
                        value: "切换账号显示为卡片或列表模式",
                        comment: "Codex account layout picker help"
                    )
                )

                if accountsViewModel.codex.isMultiSelectionEnabled {
                    Text(String(
                        format: NSLocalizedString(
                            "codex.accounts.selection.count",
                            value: "已选 %d",
                            comment: "Selected Codex account count"
                        ),
                        viewModel.codex.selectedAccountCount
                    ))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                    Menu {
                        Button {
                            Task { await viewModel.codex.exportSelectedAccountsAsZIP() }
                        } label: {
                            Label(
                                NSLocalizedString("codex.accounts.action.export_zip", value: "导出 ZIP", comment: "Export selected Codex accounts to ZIP"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(!viewModel.codex.canExportSelectedAccounts)

                        Button {
                            Task { await viewModel.codex.exportSelectedAccountsAsSub2API() }
                        } label: {
                            Label(
                                NSLocalizedString("codex.accounts.action.export_sub2api", value: "导出 sub2api", comment: "Export selected Codex accounts to sub2api"),
                                systemImage: "doc.badge.arrow.up"
                            )
                        }
                        .disabled(!viewModel.codex.canExportSelectedAccounts)

                        Button {
                            viewModel.codex.addSelectedToGatewayCard()
                        } label: {
                            Label(
                                NSLocalizedString("codex.gateway.cards.action.add_selected", value: "加入网关卡片", comment: "Add selected accounts to gateway card"),
                                systemImage: "rectangle.stack.badge.plus"
                            )
                        }
                        .disabled(!viewModel.codex.canAddSelectedToGatewayCard)

                        Divider()

                        Button {
                            accountsViewModel.codex.selectedAccountIDs.removeAll()
                        } label: {
                            Label(
                                NSLocalizedString("codex.accounts.action.clear_selection", value: "清空选择", comment: "Clear Codex selection"),
                                systemImage: "xmark.circle"
                            )
                        }
                        .disabled(accountsViewModel.codex.selectedAccountIDs.isEmpty)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.bulk_actions", value: "批量操作", comment: "Bulk account actions"),
                            systemImage: "ellipsis.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(NSLocalizedString("codex.accounts.action.done_selecting", value: "完成", comment: "Done selecting Codex accounts")) {
                        viewModel.codex.setMultiSelectionEnabled(false)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                ForEach(
                    Self.visibleCodexPrimaryHeaderActions(
                        from: viewModel.codex.primaryHeaderActions,
                        isCodexMultiSelectionEnabled: accountsViewModel.codex.isMultiSelectionEnabled
                    ),
                    id: \.id
                ) { action in
                    codexPrimaryActionButton(action)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                actionsMenu
            } else {
                if viewModel.usageProvider == .claude {
                    Button(NSLocalizedString("claude.accounts.migrate", value: "迁移", comment: "Migrate Claude accounts")) {
                        Task { await viewModel.claude.migrateFromCurrentSettings() }
                    }
                    .disabled(viewModel.isLoading)
                    if ProviderUsageLoginPolicy.shouldShowDashboardSignIn(for: provider, dashboardURL: loginFlowViewModel.dashboardURL) {
                        Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                            loginFlowViewModel.isShowingLogin = true
                        }
                    }
                } else if ProviderUsageLoginPolicy.shouldUseCLILogin(for: provider) {
                    Button(NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login")) {
                        loginFlowViewModel.startLoginFlow()
                    }
                    .disabled(loginFlowViewModel.isRunningCLILogin)
                    Button(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")) {
                        Task { await viewModel.load() }
                    }
                    .disabled(viewModel.isLoading)
                } else if ProviderUsageLoginPolicy.shouldShowDashboardSignIn(for: provider, dashboardURL: loginFlowViewModel.dashboardURL) {
                    Button(NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")) {
                        loginFlowViewModel.isShowingLogin = true
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

    @ViewBuilder
    private func codexPrimaryActionButton(_ action: ProviderUsageEngine.CodexPrimaryHeaderAction) -> some View {
        switch action {
        case .refreshAll:
            Button {
                viewModel.handleHeaderRefreshButtonTap()
            } label: {
                Label(NSLocalizedString("codex.accounts.refresh_all", value: "刷新", comment: "Codex refresh all"), systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading && !viewModel.codex.isHeaderRefreshing)
        case .login:
            Button {
                loginFlowViewModel.startLoginFlow()
            } label: {
                Label(NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login"), systemImage: "person.badge.key")
            }
            .disabled(loginFlowViewModel.isRunningCLILogin)
        case .importAuth:
            Button {
                viewModel.codex.beginImportAuthFiles()
            } label: {
                Label(NSLocalizedString("codex.accounts.import", value: "导入", comment: "Codex import"), systemImage: "tray.and.arrow.down")
            }
        case .editConfig:
            Button {
                viewModel.codex.beginEditActiveConfiguredAccount()
            } label: {
                Label(NSLocalizedString("codex.accounts.action.edit", value: "Edit", comment: "Edit configured account"), systemImage: "pencil")
            }
            .disabled(!viewModel.codex.accountSupportsEditing(accountID: viewModel.codex.activeAccountId))
        case .validateConfig:
            Button {
                viewModel.codex.validateActiveConfiguredAccount()
            } label: {
                Label(NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account"), systemImage: "checkmark.shield")
            }
            .disabled({
                guard let activeID = viewModel.codex.activeAccountId else { return true }
                return viewModel.codex.refreshingAccountIds.contains(activeID)
            }())
        }
    }

    private var actionsMenu: some View {
        Menu {
            if viewModel.capabilities.isCodexFamily {
                Section {
                    Picker(
                        selection: Binding(
                            get: { viewModel.codex.accountGroupingOption },
                            set: { viewModel.codex.accountGroupingOption = $0 }
                        )
                    ) {
                        Text(NSLocalizedString("codex.accounts.grouping.none", value: "无分组", comment: "No grouping"))
                            .tag(ProviderUsageEngine.CodexAccountGroupingOption.none)
                        Text(NSLocalizedString("codex.accounts.grouping.type_info", value: "按套餐/提供商分组", comment: "Group by type info"))
                            .tag(ProviderUsageEngine.CodexAccountGroupingOption.typeInfo)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.grouping.title", value: "分组", comment: "Grouping title"),
                            systemImage: "square.grid.2x2"
                        )
                    }

                    Picker(
                        selection: Binding(
                            get: { viewModel.codex.accountLayoutMode },
                            set: { viewModel.codex.setAccountLayoutMode($0) }
                        )
                    ) {
                        Text(NSLocalizedString("codex.accounts.layout.cards", value: "卡片", comment: "Codex account card layout"))
                            .tag(ProviderUsageEngine.CodexAccountLayoutMode.cards)
                        Text(NSLocalizedString("codex.accounts.layout.list", value: "列表", comment: "Codex account list layout"))
                            .tag(ProviderUsageEngine.CodexAccountLayoutMode.list)
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.layout.title", value: "布局", comment: "Codex account layout title"),
                            systemImage: "rectangle.grid.1x2"
                        )
                    }

                    Menu {
                        ForEach(viewModel.codex.sortMenuOptions) { option in
                            Button {
                                viewModel.codex.selectSortOption(option)
                            } label: {
                                let isSelected = viewModel.codex.accountSortOption == option
                                HStack {
                                    Text(
                                        ProviderUsageEngine.codexSortMenuItemTitle(
                                            for: option,
                                            direction: isSelected ? viewModel.codex.direction(for: option) : nil
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

                    if !accountsViewModel.codex.isMultiSelectionEnabled {
                        Button {
                            viewModel.codex.toggleMultiSelectionMode()
                        } label: {
                            Label(
                                NSLocalizedString("codex.accounts.action.multi_select", value: "进入多选", comment: "Enter Codex multi-select mode"),
                                systemImage: "checklist"
                            )
                        }
                    }
                } header: {
                    Text(NSLocalizedString("codex.accounts.menu.section.view", value: "显示", comment: "Codex menu section for view options"))
                }

                Section {
                    Button {
                        viewModel.codex.beginNewAPIKeyAccount()
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.new_api_key", value: "新增 API Key", comment: "New API key account"),
                            systemImage: "key"
                        )
                    }

                    Button {
                        viewModel.codex.beginNewRelayAccount()
                    } label: {
                        Label(
                            NSLocalizedString("codex.accounts.action.new_relay", value: "新增 Relay", comment: "New relay account"),
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                    }

                    Button {
                        createGatewayCardWithPrompt()
                    } label: {
                        Label(
                            NSLocalizedString("codex.gateway.cards.create.title", value: "新建网关卡片", comment: "Create gateway card title"),
                            systemImage: "square.stack.3d.up.badge.a"
                        )
                    }
                } header: {
                    Text(NSLocalizedString("codex.accounts.menu.section.account", value: "账号管理", comment: "Codex menu section for account management"))
                }

                Section {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.codex.autoSwitchConfig.enabled },
                            set: { viewModel.codex.setAutoSwitchEnabled($0) }
                        )
                    ) {
                        Label(
                            NSLocalizedString("codex.accounts.auto_switch.enabled", value: "自动切号", comment: "Codex auto switch enabled"),
                            systemImage: "arrow.left.arrow.right.circle"
                        )
                    }

                    if viewModel.codex.autoSwitchConfig.enabled {
                        Menu {
                            ForEach(codexAutoSwitchThresholdOptions, id: \.self) { option in
                                Button {
                                    viewModel.codex.setAutoSwitchThresholdPercent(Int(option))
                                } label: {
                                    HStack {
                                        Text(
                                            String(
                                                format: NSLocalizedString(
                                                    "codex.accounts.auto_switch.threshold.option",
                                                    value: "低于 %d%% 时切换",
                                                    comment: "Codex auto switch threshold option"
                                                ),
                                                Int(option)
                                            )
                                        )
                                        if viewModel.codex.autoSwitchConfig.thresholdPercent == option {
                                            Spacer(minLength: 8)
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label(
                                String(
                                    format: NSLocalizedString(
                                        "codex.accounts.auto_switch.threshold.title",
                                        value: "切号阈值：%d%%",
                                        comment: "Codex auto switch threshold title"
                                    ),
                                    Int(viewModel.codex.autoSwitchConfig.thresholdPercent)
                                ),
                                systemImage: "gauge.with.dots.needle.33percent"
                            )
                        }

                        Menu {
                            ForEach(codexAutoSwitchCandidateOptions, id: \.self) { option in
                                Button {
                                    viewModel.codex.setAutoSwitchMinimumCandidateRemainingPercent(Int(option))
                                } label: {
                                    HStack {
                                        Text(
                                            String(
                                                format: NSLocalizedString(
                                                    "codex.accounts.auto_switch.candidate.option",
                                                    value: "候选至少保留 %d%%",
                                                    comment: "Codex auto switch candidate threshold option"
                                                ),
                                                Int(option)
                                            )
                                        )
                                        if viewModel.codex.autoSwitchConfig.minimumCandidateRemainingPercent == option {
                                            Spacer(minLength: 8)
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label(
                                String(
                                    format: NSLocalizedString(
                                        "codex.accounts.auto_switch.candidate.title",
                                        value: "候选余量：%d%%",
                                        comment: "Codex auto switch candidate threshold title"
                                    ),
                                    Int(viewModel.codex.autoSwitchConfig.minimumCandidateRemainingPercent)
                                ),
                                systemImage: "battery.75"
                            )
                        }

                        Toggle(
                            isOn: Binding(
                                get: { viewModel.codex.autoSwitchConfig.skipRelayAccounts },
                                set: { viewModel.codex.setAutoSwitchSkipRelay($0) }
                            )
                        ) {
                            Label(
                                NSLocalizedString("codex.accounts.auto_switch.skip_relay", value: "跳过 Relay 账号", comment: "Skip relay accounts in auto switch"),
                                systemImage: "point.3.connected.trianglepath.dotted"
                            )
                        }
                    }
                } header: {
                    Text(NSLocalizedString("codex.accounts.menu.section.auto_switch", value: "自动切号", comment: "Codex menu section for auto switch"))
                }
            } else {
                Section {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label(NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"), systemImage: "arrow.clockwise")
                    }
                }

                if viewModel.usageProvider == .claude {
                    Section {
                        Button {
                            Task { await viewModel.claude.migrateFromCurrentSettings() }
                        } label: {
                            Label(
                                NSLocalizedString("claude.accounts.migrate.current", value: "迁移当前配置", comment: "Migrate Claude from current settings"),
                                systemImage: "tray.and.arrow.down"
                            )
                        }

                        Button {
                            Task { await viewModel.claude.importFromCCSwitch() }
                        } label: {
                            Label(
                                NSLocalizedString("claude.accounts.migrate.cc_switch", value: "从 cc-switch 导入", comment: "Import Claude from cc-switch"),
                                systemImage: "square.and.arrow.down"
                            )
                        }
                    } header: {
                        Text(NSLocalizedString("usage.menu.section.account", value: "账号管理", comment: "Generic menu section for account management"))
                    }
                }
            }

            Section {
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
            } header: {
                Text(NSLocalizedString("usage.menu.section.system", value: "系统", comment: "Menu section for system options"))
            }

            if loginFlowViewModel.isRunningCLILogin {
                Section {
                    Button(role: .destructive) {
                        loginFlowViewModel.cancelCLILoginIfNeeded()
                    } label: {
                        Label(
                            NSLocalizedString("codex.cli_login.cancel", value: "Cancel Login", comment: "Cancel CLI login"),
                            systemImage: "xmark.circle"
                        )
                    }
                } header: {
                    Text(NSLocalizedString("usage.menu.section.danger", value: "危险操作", comment: "Menu section for destructive actions"))
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: DesignSystem.Metrics.iconButtonSize, height: DesignSystem.Metrics.iconButtonSize)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

}
