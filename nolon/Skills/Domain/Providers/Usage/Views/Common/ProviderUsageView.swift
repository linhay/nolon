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
    private enum CodexListLayout {
        static let planColumnWidth: CGFloat = 96
        static let usageColumnWidth: CGFloat = 232
    }

    private struct CodexListUsageWindow: Identifiable {
        let id: String
        let title: String
        let remainingPercent: Double
    }

    let provider: Provider
    let isEmbedded: Bool
    @State private var rootViewModel: ProviderUsageRootViewModel
    @State private var targetingGatewayCardID: UUID?
    @State private var gatewayAccountPickerCardID: UUID?
    @State private var gatewayAccountPickerSelection: Set<UUID> = []
    private let codexAutoSwitchThresholdOptions: [Double] = [5, 10, 15, 20, 30]
    private let codexAutoSwitchCandidateOptions: [Double] = [10, 20, 30, 40, 50]

    private let codexAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12, alignment: .topLeading)
    ]
    private let claudeAccountColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 12, alignment: .topLeading)
    ]

    @MainActor
    init(provider: Provider, isEmbedded: Bool = false) {
        self.provider = provider
        self.isEmbedded = isEmbedded
        self._rootViewModel = State(initialValue: ProviderUsageRootViewModelStore.shared.viewModel(for: provider))
    }

    private var viewModel: ProviderUsageAccountsViewModel {
        rootViewModel.accountsViewModel
    }

    private var accountsViewModel: ProviderUsageAccountsViewModel {
        rootViewModel.accountsViewModel
    }

    private var tokenTrendViewModel: ProviderTokenTrendViewModel {
        rootViewModel.tokenTrendViewModel
    }

    private var importExportViewModel: CodexImportExportViewModel {
        rootViewModel.importExportViewModel
    }

    private var loginFlowViewModel: ProviderLoginFlowViewModel {
        rootViewModel.loginFlowViewModel
    }

    private var gatewayCardsViewModel: CodexGatewayCardsViewModel {
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

    private var tokenTrendDebugPageMarkerItems: [PageMarkerItem] {
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

    private var gatewayCardsDebugPageMarkerItems: [PageMarkerItem] {
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
                .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: NSLocalizedString("usage.monitor.empty.title", value: "No usage data", comment: "Empty title"))])
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
            if viewModel.usageProvider == .codex {
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

    private var genericUsageContent: some View {
        let displayedOutcomes = ProviderUsageOutcomeFilter.displayedGenericOutcomes(
            usageProvider: viewModel.usageProvider,
            hasGeminiAccounts: !viewModel.gemini.accounts.isEmpty,
            outcomes: viewModel.outcomes
        )
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.gemini.shouldShowImportAction {
                    geminiImportCallout
                }
                if let usageProvider = viewModel.usageProvider,
                   (usageProvider == .gemini || usageProvider == .antigravity),
                   !viewModel.gemini.accounts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(provider.name)
                            .font(.headline)

                        if Self.shouldUseFullWidthGeminiCardLayout(accountCount: viewModel.gemini.accounts.count) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(viewModel.gemini.accounts, id: \.id) { account in
                                    geminiAccountCard(account: account)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }
                        } else {
                            LazyVGrid(columns: claudeAccountColumns, alignment: .leading, spacing: 12) {
                                ForEach(viewModel.gemini.accounts, id: \.id) { account in
                                    geminiAccountCard(account: account)
                                }
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
                if viewModel.claude.accounts.isEmpty {
                    ProviderUsageEmptyStateCard(
                        title: LocalizedStringKey(
                            NSLocalizedString(
                                "claude.accounts.empty.title",
                                value: "No Claude accounts",
                                comment: "Empty Claude accounts title"
                            )
                        ),
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        descriptionText: Text(
                            NSLocalizedString(
                                "claude.accounts.empty.desc",
                                value: "Use \"迁移\" or \"从 cc-switch 导入\" to add accounts.",
                                comment: "Empty Claude accounts description"
                            )
                        )
                    )
                    .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: NSLocalizedString("claude.accounts.empty.title", value: "No Claude accounts", comment: "Empty Claude accounts title"))])
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title"))
                            .font(.headline)

                        LazyVGrid(columns: claudeAccountColumns, alignment: .leading, spacing: 12) {
                            ForEach(viewModel.claude.accounts, id: \.id) { account in
                                claudeAccountCard(account: account)
                            }
                        }
                    }
                }

                let usageOutcomes = ProviderUsageOutcomeFilter.displayedClaudeOutcomes(
                    hasClaudeAccounts: !viewModel.claude.accounts.isEmpty,
                    outcomes: viewModel.outcomes
                ).filter { outcome in
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
        let isActive = viewModel.claude.isActiveAccount(account)
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
                Task { await viewModel.claude.activateAccount(id: account.id) }
            },
            onAction: { _, action in
                guard action == .activate else { return }
                Task { await viewModel.claude.activateAccount(id: account.id) }
            }
        )
    }

    private func geminiAccountCard(account: GeminiAuthAccount) -> some View {
        let isActive = viewModel.gemini.isActiveAccount(account)
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
                    errorMessage: ProviderUsageErrorFormatter.detailText(error: error)
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
                Task { await viewModel.gemini.activateAccount(id: account.id) }
            },
            onAction: { _, action in
                switch action {
                case .activate:
                    Task { await viewModel.gemini.activateAccount(id: account.id) }
                case .refresh:
                    Task { await viewModel.load() }
                case .delete:
                    Task { await viewModel.gemini.deleteAccount(id: account.id) }
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
                    viewModel.gemini.presentImportConfirmation()
                }
                .buttonStyle(.borderedProminent)

                Button(NSLocalizedString(
                    "gemini.import.inline.oauth",
                    value: "Sign in with OAuth",
                    comment: "Inline Gemini OAuth CTA"
                )) {
                    viewModel.gemini.continueOAuthLoginWithoutImport()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
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
            return viewModel.codex.accountCreditsRefreshedAt[account.id]
        case .default:
            if let activeId = accountsViewModel.codex.activeAccountId {
                return viewModel.codex.accountCreditsRefreshedAt[activeId]
            }
            return nil
        }
    }

    private var codexContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                codexManagementCard
                if !gatewayCardsViewModel.gatewayCards.isEmpty {
                    gatewayCardsSection
                }

                if accountsViewModel.codex.accounts.isEmpty && !viewModel.isLoading {
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
                    .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"))])
                }

                if viewModel.isLoading && accountsViewModel.codex.accountOutcomes.isEmpty {
                    Group {
                        if viewModel.codex.accountLayoutMode == .list {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(0..<ProviderUsageSkeletonPolicy.codexCardCount, id: \.self) { _ in
                                    switch ProviderUsageSkeletonPolicy.codexLoadingSkeletonStyle {
                                    case .unifiedAccountCard:
                                        UnifiedAccountCardSkeleton(providerName: provider.name)
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                                ForEach(0..<ProviderUsageSkeletonPolicy.codexCardCount, id: \.self) { _ in
                                    switch ProviderUsageSkeletonPolicy.codexLoadingSkeletonStyle {
                                    case .unifiedAccountCard:
                                        UnifiedAccountCardSkeleton(providerName: provider.name)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.codex.accountDisplaySections.isEmpty && viewModel.codex.hasActiveAccountFilters {
                    ContentUnavailableView(
                        NSLocalizedString("codex.accounts.filtered_empty.title", value: "没有可显示的账号", comment: "All accounts hidden by zero quota filter title"),
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(
                            codexFilteredEmptyDescription
                        )
                        .dsSecondaryText(font: .body)
                    )
                    .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: NSLocalizedString("codex.accounts.filtered_empty.title", value: "没有可显示的账号", comment: "All accounts hidden by zero quota filter title"))])
                } else {
                    ForEach(viewModel.codex.accountDisplaySections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            if let title = section.title {
                                HStack(spacing: 8) {
                                    Button {
                                        viewModel.codex.toggleSection(section.id)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: viewModel.codex.isSectionCollapsed(section.id) ? "chevron.right" : "chevron.down")
                                                .font(.caption)
                                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                            Text(title)
                                                .font(.headline)
                                                .foregroundStyle(DesignSystem.Colors.Text.primary)
                                            Text(
                                                "(\(section.items.count) / \(viewModel.codex.accountSectionTotalCountByID[section.id, default: section.items.count]))"
                                            )
                                                .font(.caption)
                                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Spacer(minLength: 0)

                                    if accountsViewModel.codex.isMultiSelectionEnabled && !section.items.isEmpty {
                                        Button(viewModel.codex.isSectionFullySelected(section)
                                            ? NSLocalizedString("codex.import.sheet.deselect_all", value: "取消全选", comment: "Deselect all")
                                            : NSLocalizedString("codex.import.sheet.select_all", value: "全选", comment: "Select all")
                                        ) {
                                            viewModel.codex.toggleSectionSelection(section)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                }
                            }

                            if !viewModel.codex.isSectionCollapsed(section.id) {
                                codexOutcomesContainer(section.items)
                            }
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: viewModel.codex.collapsedSectionIDs)
                }

                tokenTrendSection
            }
            .padding(.trailing, 12)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var codexFilteredEmptyDescription: String {
        switch (viewModel.codex.hideZeroQuotaAccounts, viewModel.codex.hideErroredAccounts) {
        case (true, true):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc.hide_zero_and_error",
                value: "当前已隐藏无额度或报错账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by zero quota and errored filters"
            )
        case (true, false):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc",
                value: "当前已隐藏最长额度窗口为 0% 的账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by zero quota filter description"
            )
        case (false, true):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc.hide_error",
                value: "当前已隐藏报错账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by errored filter description"
            )
        case (false, false):
            return NSLocalizedString(
                "codex.accounts.filtered_empty.desc",
                value: "当前已隐藏最长额度窗口为 0% 的账号。关闭筛选后可查看全部账号。",
                comment: "All accounts hidden by zero quota filter description"
            )
        }
    }

    @ViewBuilder
    private var codexManagementCard: some View {
        if let status = viewModel.codex.managementStatus, status.needsEnable || status.needsMigration {
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
                    Task { await viewModel.codex.enableManagement() }
                }
                Button(NSLocalizedString("codex.management.migrate", value: "数据迁移", comment: "Migrate codex data")) {
                    Task { await viewModel.codex.migrateManagementData() }
                }
            }
            .padding(12)
            .background(DesignSystem.Colors.Component.controlFillSubtle)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        }
    }

    private var gatewayCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                    Button {
                        gatewayCardsViewModel.toggleGatewayCardsSectionCollapsed()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: gatewayCardsViewModel.isGatewayCardsSectionCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)

                        Label(
                            NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title"),
                            systemImage: "square.stack.3d.up.fill"
                        )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text("\(gatewayCardsViewModel.gatewayCards.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.Component.controlFillSubtle)
                            .clipShape(Capsule())
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if !gatewayCardsViewModel.isGatewayCardsSectionCollapsed {
                gatewayCardsContainer(gatewayCardsViewModel.gatewayCards)
            }
        }
        .animation(.snappy(duration: 0.2), value: gatewayCardsViewModel.isGatewayCardsSectionCollapsed)
        .debugCardLocator(gatewayCardsDebugPageMarkerItems)
    }

    @ViewBuilder
    private func codexOutcomesContainer(_ outcomes: [ProviderAccountUsageOutcome]) -> some View {
        Group {
            if Self.shouldUseCompactCodexListRows(layoutMode: viewModel.codex.accountLayoutMode) {
                VStack(alignment: .leading, spacing: 0) {
                    codexListTableHeader

                    ForEach(Array(outcomes.enumerated()), id: \.element.id) { index, outcome in
                        codexOutcomeCard(outcome: outcome)
                        if index < outcomes.count - 1 {
                            Divider()
                                .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.Background.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: codexAccountColumns, alignment: .leading, spacing: 12) {
                    ForEach(outcomes) { outcome in
                        codexOutcomeCard(outcome: outcome)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func gatewayCardsContainer(_ cards: [CodexGatewayCard]) -> some View {
        NolonUI.GatewayCardListModule(
            items: cards,
            layoutMode: viewModel.codex.accountLayoutMode == .list ? .list : .cards,
            columns: codexAccountColumns,
            spacing: 12
        ) { card in
            gatewayCardView(card: card)
        }
    }

    private func gatewayCardView(card: CodexGatewayCard) -> some View {
        let members = viewModel.codex.gatewayMembers(for: card)
        let memberItems = members.map { member in
            NolonUI.GatewayCardMemberItem(
                id: member.id,
                title: member.title,
                plan: member.plan
            )
        }
        let isTargeted = targetingGatewayCardID == card.id
        let isActiveGateway = gatewayCardsViewModel.gatewayCardsState.lastUsedCardID == card.id
        let presentation: AccountCardPresentation = (isTargeted || isActiveGateway) ? .selected : .neutral
        let isCompact = Self.shouldUseCompactCodexListRows(layoutMode: viewModel.codex.accountLayoutMode)
        let memberDisplayLimit = Self.gatewayMemberDisplayLimit(layoutMode: viewModel.codex.accountLayoutMode)
        let memberRowMaxHeight = Self.gatewayMemberRowMaxHeight(layoutMode: viewModel.codex.accountLayoutMode)
        
        return NolonUI.GatewayCardModule(
            presentation: presentation,
            title: card.name,
            memberCountText: String(
                format: NSLocalizedString(
                    "codex.gateway.cards.members.count",
                    value: "%d 个成员",
                    comment: "Gateway card members count"
                ),
                members.count
            ),
            members: memberItems,
            isCompact: isCompact,
            memberDisplayLimit: memberDisplayLimit,
            memberRowMaxHeight: memberRowMaxHeight
        )
        .animation(DesignSystem.Animations.springQuick, value: isTargeted || isActiveGateway)
        .contentShape(Rectangle())
        .onTapGesture {
            handleGatewayCardSelection(cardID: card.id)
        }
        .dropDestination(for: CodexGatewayAccountDropItem.self) { items, _ in
            handleGatewayCardDrop(items: items, cardID: card.id)
        } isTargeted: { targeted in
            targetingGatewayCardID = targeted ? card.id : (targetingGatewayCardID == card.id ? nil : targetingGatewayCardID)
        }
        .dropDestination(for: String.self) { items, _ in
            handleLegacyGatewayCardDrop(items: items, cardID: card.id)
        }
        .contextMenu {
            Button {
                handleGatewayCardSelection(cardID: card.id, openPicker: true)
            } label: {
                Label(
                    NSLocalizedString(
                        "codex.gateway.cards.action.add_accounts",
                        value: "添加账号",
                        comment: "Add accounts to gateway card"
                    ),
                    systemImage: "plus"
                )
            }

            Divider()

            if Self.shouldShowActivateGatewayContextAction(isActiveGateway: isActiveGateway) {
                Button {
                    handleGatewayCardSelection(cardID: card.id)
                } label: {
                    Label(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"), systemImage: "checkmark.circle")
                }
            }
            Button {
                if let name = promptGatewayCardName(
                    title: NSLocalizedString("codex.gateway.cards.rename.title", value: "重命名网关卡片", comment: "Rename gateway card title"),
                    defaultValue: card.name
                ) {
                    gatewayCardsViewModel.renameGatewayCard(cardID: card.id, name: name)
                }
            } label: {
                Label(NSLocalizedString("rename", value: "Rename", comment: "Rename"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                gatewayCardsViewModel.deleteGatewayCard(cardID: card.id)
            } label: {
                Label(NSLocalizedString("delete", value: "Delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .debugCardLocator(gatewayCardsDebugPageMarkerItems + [PageMarkerItem(title: card.name)])
    }

    private var gatewayCardPickerSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("codex.gateway.cards.picker.title", value: "选择目标网关卡片", comment: "Gateway card picker title"))
                .font(.headline)
            Text(
                String(
                    format: NSLocalizedString(
                        "codex.gateway.cards.picker.selected_count",
                        value: "将加入 %d 个已选账号",
                        comment: "Gateway picker selected count"
                    ),
                    gatewayCardsViewModel.pendingGatewaySelectionAccountIDs.count
                )
            )
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)

            List(gatewayCardsViewModel.gatewayCards) { card in
                Button {
                    gatewayCardsViewModel.confirmAddPendingAccounts(to: card.id)
                } label: {
                    HStack {
                        Text(card.name)
                        Spacer(minLength: 0)
                        Text("\(card.memberAccountIDs.count)")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 200)

            HStack {
                Spacer(minLength: 0)
                Button(NSLocalizedString("cancel", value: "Cancel", comment: "Cancel")) {
                    gatewayCardsViewModel.dismissGatewayCardPicker()
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 320)
    }

    private func gatewayAccountSelectionSheet(cardID: UUID) -> some View {
        let card = gatewayCardsViewModel.gatewayCards.first(where: { $0.id == cardID })
        let candidates = gatewayCardsViewModel.gatewayCandidateAccounts(for: cardID)
        let candidateSections = gatewayCardsViewModel.gatewayCandidateSections(for: cardID)
        let cardName = card?.name ?? NSLocalizedString("codex.gateway.cards.unknown", value: "网关卡片", comment: "Gateway card fallback name")

        return VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    format: NSLocalizedString(
                        "codex.gateway.accounts.picker.title",
                        value: "为 %@ 选择账号",
                        comment: "Gateway account picker title"
                    ),
                    cardName
                )
            )
            .font(.headline)

            if candidates.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString(
                        "codex.gateway.accounts.picker.empty.title",
                        value: "没有可添加的账号",
                        comment: "Gateway account picker empty title"
                    ),
                    systemImage: "person.crop.circle.badge.checkmark",
                    description: Text(
                        NSLocalizedString(
                            "codex.gateway.accounts.picker.empty.desc",
                            value: "当前所有账号都已在此网关卡片中。",
                            comment: "Gateway account picker empty description"
                        )
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(candidateSections) { section in
                        Section {
                            ForEach(section.items, id: \.id) { account in
                                let title = gatewayCandidateTitle(for: account)
                                let subtitle = gatewayCandidateSubtitle(for: account, title: title)
                                Button {
                                    toggleGatewayAccountPickerSelection(account.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(title)
                                                .font(.body)
                                                .foregroundStyle(DesignSystem.Colors.Text.primary)
                                            if let subtitle, !subtitle.isEmpty {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: gatewayAccountPickerSelection.contains(account.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(
                                                gatewayAccountPickerSelection.contains(account.id)
                                                ? DesignSystem.Colors.primary
                                                : DesignSystem.Colors.Text.tertiary
                                            )
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Label(section.title, systemImage: gatewayCandidateSectionIcon(for: section.title))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(gatewayCandidateSectionForegroundColor(for: section.title))
                                    .background(
                                        gatewayCandidateSectionBackgroundColor(for: section.title),
                                        in: Capsule(style: .continuous)
                                    )
                                Text("\(section.items.count)")
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            }
                        }
                    }
                }
                .frame(minHeight: 220)
            }

            HStack {
                Button(NSLocalizedString("cancel", value: "Cancel", comment: "Cancel")) {
                    dismissGatewayAccountPicker()
                }
                Spacer(minLength: 0)
                Button(
                    NSLocalizedString(
                        "codex.gateway.accounts.picker.add",
                        value: "加入网关",
                        comment: "Add accounts to gateway card"
                    )
                ) {
                    confirmGatewayAccountPickerSelection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(gatewayAccountPickerSelection.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 360)
        .debugCardLocator(
            gatewayCardsDebugPageMarkerItems + [
                PageMarkerItem(
                    title: String(
                        format: NSLocalizedString(
                            "codex.gateway.accounts.picker.title",
                            value: "为 %@ 选择账号",
                            comment: "Gateway account picker title"
                        ),
                        cardName
                    )
                )
            ]
        )
    }

    private func gatewayCandidateTitle(for account: CodexAuthAccount) -> String {
        CodexAccountDisplayNameResolver.resolve(
            summary: accountsViewModel.codex.accountSummaries[account.id],
            relativeAuthPath: account.relativeAuthPath,
            defaultName: account.name,
            accountID: account.id
        )
    }

    private func gatewayCandidateSectionIcon(for title: String) -> String {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("relay") {
            return "network"
        }
        if normalized.contains("openai") {
            return "bolt.shield"
        }
        if normalized.contains("plus") || normalized.contains("pro") {
            return "sparkles"
        }
        return "square.grid.2x2"
    }

    private func gatewayCandidateSectionForegroundColor(for title: String) -> Color {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("relay") {
            return DesignSystem.Colors.Status.info
        }
        if normalized.contains("openai") {
            return DesignSystem.Colors.primary
        }
        if normalized.contains("plus") || normalized.contains("pro") {
            return DesignSystem.Colors.Status.success
        }
        return DesignSystem.Colors.Text.secondary
    }

    private func gatewayCandidateSectionBackgroundColor(for title: String) -> Color {
        gatewayCandidateSectionForegroundColor(for: title).opacity(0.14)
    }

    private func gatewayCandidateSubtitle(for account: CodexAuthAccount, title: String) -> String? {
        guard let raw = accountsViewModel.codex.accountSummaries[account.id]?.email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw == title ? nil : raw
    }

    private func presentGatewayAccountPicker(for cardID: UUID) {
        gatewayAccountPickerCardID = cardID
        gatewayAccountPickerSelection = []
    }

    private func handleGatewayCardSelection(cardID: UUID, openPicker: Bool = false) {
        let shouldPromptAddAccounts = gatewayCardsViewModel.activateGatewayCard(cardID: cardID)
        if openPicker || shouldPromptAddAccounts {
            presentGatewayAccountPicker(for: cardID)
            return
        }
        Task { await gatewayCardsViewModel.startGatewayForCardSelection(cardID: cardID) }
    }

    private func dismissGatewayAccountPicker() {
        gatewayAccountPickerCardID = nil
        gatewayAccountPickerSelection = []
    }

    private func toggleGatewayAccountPickerSelection(_ accountID: UUID) {
        if gatewayAccountPickerSelection.contains(accountID) {
            gatewayAccountPickerSelection.remove(accountID)
        } else {
            gatewayAccountPickerSelection.insert(accountID)
        }
    }

    private func confirmGatewayAccountPickerSelection() {
        guard let cardID = gatewayAccountPickerCardID else { return }
        let orderedIDs = gatewayCardsViewModel
            .gatewayCandidateAccounts(for: cardID)
            .map(\.id)
            .filter { gatewayAccountPickerSelection.contains($0) }
        guard !orderedIDs.isEmpty else {
            dismissGatewayAccountPicker()
            return
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: orderedIDs, cardID: cardID)
        dismissGatewayAccountPicker()
        Task { await gatewayCardsViewModel.startGatewayForCardSelection(cardID: cardID) }
    }

    private func handleGatewayCardDrop(items: [CodexGatewayAccountDropItem], cardID: UUID) -> Bool {
        handleGatewayCardDrop(accountIDs: items.map(\.accountID), cardID: cardID)
    }

    private func handleLegacyGatewayCardDrop(items: [String], cardID: UUID) -> Bool {
        handleGatewayCardDrop(
            accountIDs: CodexGatewayDropParser.accountIDs(fromLegacyStrings: items),
            cardID: cardID
        )
    }

    private func handleGatewayCardDrop(accountIDs droppedIDs: [UUID], cardID: UUID) -> Bool {
        guard let firstID = droppedIDs.first else { return false }
        if accountsViewModel.codex.isMultiSelectionEnabled, accountsViewModel.codex.selectedAccountIDs.contains(firstID) {
            gatewayCardsViewModel.addAccountsToGatewayCard(
                accountIDs: Array(accountsViewModel.codex.selectedAccountIDs),
                cardID: cardID
            )
            return true
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: droppedIDs, cardID: cardID)
        return true
    }

    private func createGatewayCardWithPrompt() {
        let defaultName = String(
            format: NSLocalizedString(
                "codex.gateway.cards.default_name",
                value: "网关 %d",
                comment: "Gateway default card name"
            ),
            gatewayCardsViewModel.gatewayCards.count + 1
        )
        if let name = promptGatewayCardName(
            title: NSLocalizedString("codex.gateway.cards.create.title", value: "新建网关卡片", comment: "Create gateway card title"),
            defaultValue: defaultName
        ) {
            _ = gatewayCardsViewModel.createGatewayCard(name: name)
        }
    }

    private func promptGatewayCardName(title: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: NSLocalizedString("generic.ok", value: "OK", comment: "OK"))
        alert.addButton(withTitle: NSLocalizedString("cancel", value: "Cancel", comment: "Cancel"))

        let textField = NSTextField(string: defaultValue)
        textField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var tokenTrendSection: some View {
        ProviderTokenTrendSection(
            snapshot: tokenTrendViewModel.tokenTrendSnapshot,
            isLoading: tokenTrendViewModel.shouldShowLoadingSkeleton,
            errorMessage: tokenTrendViewModel.tokenTrendErrorMessage,
            range: tokenTrendViewModel.tokenTrendRange,
            onRangeChange: { tokenTrendViewModel.setRange($0) },
            onRefresh: { tokenTrendViewModel.refreshNow() },
            debugPageMarkerItems: tokenTrendDebugPageMarkerItems
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
            return accountsViewModel.codex.pendingActivateAccount?.id == accountId
        }()

        let isActive: Bool = {
            guard let accountId else { return false }
            guard let saved = accountsViewModel.codex.accounts.first(where: { $0.id == accountId }) else { return false }
            return accountsViewModel.codex.isActiveAccount(saved)
        }()
        let hasActiveGatewayCardSelection = gatewayCardsViewModel.hasActiveGatewayCardSelection
        let isActivePresentation = isActive && !hasActiveGatewayCardSelection

        let isBatchSelected = accountsViewModel.codex.isAccountSelected(id: accountId)

        let cardPresentation = AccountCardPresentation.codex(
            isActive: isActivePresentation,
            isPending: isPending,
            isBatchSelected: isBatchSelected,
            selectableAccountCount: accountsViewModel.codex.accounts.count
        )
        let summary = accountId.flatMap { accountsViewModel.codex.accountSummaries[$0] }
        let isRefreshing: Bool = {
            guard let id = accountId else { return false }
            return accountsViewModel.codex.refreshingAccountIds.contains(id)
        }()
        let canLogin = accountsViewModel.codex.accountSupportsLogin(accountID: accountId)
        let isLoggingIn = accountId != nil
            && loginFlowViewModel.isRunningCLILogin
            && viewModel.codex.cliLoginPreferredAccountId == accountId
        let onLogin: (() -> Void)? = canLogin ? accountId.map { id in
            { accountsViewModel.codex.requestLoginForAccount(id: id) }
        } : nil
        let cardView = codexCompactSnapshotView(
            outcome: outcome,
            presentation: cardPresentation,
            isRefreshing: isRefreshing,
            summary: summary,
            onRefresh: accountId.map { id in
                { accountsViewModel.codex.refreshAccount(id: id) }
            },
            onLogin: onLogin,
            isLoggingIn: isLoggingIn
        )
        .onTapGesture {
            guard let accountId else { return }
            if hasActiveGatewayCardSelection {
                gatewayCardsViewModel.clearActiveGatewayCardSelection()
            }
            if accountsViewModel.codex.isMultiSelectionEnabled {
                accountsViewModel.codex.toggleAccountSelection(id: accountId)
                return
            }
            let shouldActivate = accountsViewModel.codex.shouldActivateAccountOnTap(
                id: accountId,
                hasActiveGatewayCardSelection: hasActiveGatewayCardSelection
            )
            guard shouldActivate else { return }
            accountsViewModel.codex.requestActivateAccount(id: accountId)
        }

        if let accountId {
            cardView.draggable(CodexGatewayAccountDropItem(accountID: accountId))
        } else {
            cardView
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
            accountsViewModel.codex.accounts.first(where: { $0.id == id })
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
            if let liveFailureError { return ProviderUsageErrorFormatter.detailText(error: liveFailureError) }
            return nil
        }()
        let isActiveCodexAccount = presentation.selectionStyle == .active

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
                if Self.shouldShowActivateAccountContextAction(isActiveAccount: isActiveCodexAccount) {
                    items.append(.init(id: "activate", actionID: .activate, title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"), systemImage: "checkmark.circle", role: nil, isEnabled: true))
                }
                items.append(.init(id: "copy-auth-json", actionID: .copyAuthJSON, title: NSLocalizedString("codex.accounts.menu.copy_auth_json", value: "Copy auth.json", comment: "Copy auth json"), systemImage: "doc.on.doc.fill", role: nil, isEnabled: true))
                items.append(.init(id: "edit-auth-json", actionID: .editAuthJSON, title: NSLocalizedString("codex.accounts.menu.edit_auth_json", value: "Edit auth.json", comment: "Edit auth json"), systemImage: "pencil", role: nil, isEnabled: true))
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

        Group {
            if Self.shouldUseCompactCodexListRows(layoutMode: viewModel.codex.accountLayoutMode) {
                codexCompactListRow(
                    data: data,
                    presentation: presentation,
                    isRefreshing: isRefreshing,
                    onRefresh: onRefresh,
                    onLogin: onLogin,
                    isLoggingIn: isLoggingIn,
                    accountId: accountId,
                    failureDetail: failureDetail
                )
            } else {
                UnifiedAccountCard(
                    data: data,
                    onTap: { _ in },
                    onAction: { _, action in
                        handleCodexOutcomeAction(
                            action: action,
                            accountId: accountId,
                            onRefresh: onRefresh,
                            onLogin: onLogin,
                            failureDetail: failureDetail
                        )
                    }
                )
            }
        }
        .if(Self.shouldEnableCodexTextSelection(layoutMode: viewModel.codex.accountLayoutMode)) { view in
            view.textSelection(.enabled)
        }
    }

    private func codexCompactListRow(
        data: AccountCardViewData,
        presentation: AccountCardPresentation,
        isRefreshing: Bool,
        onRefresh: (() -> Void)?,
        onLogin: (() -> Void)?,
        isLoggingIn: Bool,
        accountId: UUID?,
        failureDetail: String?
    ) -> some View {
        let usageWindows = compactUsageWindows(from: data)
        return HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(compactStatusColor(presentation: presentation, badge: data.header.badge))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.header.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)

                    if let secondary = compactSecondaryText(from: data.header), !secondary.isEmpty {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(compactPlanText(from: data.header))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .frame(width: CodexListLayout.planColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(usageWindows) { window in
                    HStack(spacing: 6) {
                        Text(window.title)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .frame(width: 46, alignment: .leading)
                        compactUsageProgressBar(remainingPercent: window.remainingPercent)
                    }
                }
            }
            .frame(width: CodexListLayout.usageColumnWidth, alignment: .leading)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(compactRowBackgroundColor(presentation: presentation))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(data.menuActions) { action in
                Button(role: action.role) {
                    handleCodexOutcomeAction(
                        action: action.actionID,
                        accountId: accountId,
                        onRefresh: onRefresh,
                        onLogin: onLogin,
                        failureDetail: failureDetail
                    )
                } label: {
                    if let symbol = action.systemImage, !symbol.isEmpty {
                        Label(action.title, systemImage: symbol)
                    } else {
                        Text(action.title)
                    }
                }
                .disabled(!action.isEnabled)
            }
        }
    }

    private func compactRowBackgroundColor(presentation: AccountCardPresentation) -> Color {
        switch presentation {
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.12)
        default:
            return .clear
        }
    }

    private var codexListTableHeader: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Codex account list table account column"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(NSLocalizedString("codex.accounts.list.header.plan", value: "Plan", comment: "Codex account list table plan column"))
                .frame(width: CodexListLayout.planColumnWidth, alignment: .leading)
            Text(NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Codex account list table usage column"))
                .frame(width: CodexListLayout.usageColumnWidth, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, 8)
    }

    private func compactUsageWindows(from data: AccountCardViewData) -> [CodexListUsageWindow] {
        guard case let .quota(quota) = data.body, let usage = quota.usage else {
            return [.init(id: "none", title: "-", remainingPercent: 0)]
        }
        return ProviderQuotaSection
            .displayWindows(for: usage, provider: quota.provider)
            .prefix(3)
            .map { item in
                .init(
                    id: item.id,
                    title: compactUsageWindowTitle(item, provider: quota.provider),
                    remainingPercent: item.window.remainingPercent
                )
            }
    }

    private func compactUsageWindowTitle(_ item: UsageWindow, provider: UsageProvider) -> String {
        let metadata = ProviderUsageRegistry.metadata(for: provider)
        switch item.id {
        case "primary":
            return metadata?.sessionLabel ?? "Session"
        case "secondary":
            return metadata?.weeklyLabel ?? "Weekly"
        default:
            return item.title
        }
    }

    private func compactUsageProgressBar(remainingPercent: Double) -> some View {
        let normalized = max(0, min(100, remainingPercent.isInfinite ? 100 : remainingPercent))
        let progress = normalized / 100
        let color = compactQuotaColor(for: remainingPercent)
        return HStack(spacing: 8) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.22))
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 8)

            Text(remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized))
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func compactQuotaColor(for remainingPercent: Double) -> Color {
        if remainingPercent.isInfinite { return DesignSystem.Colors.Status.success }
        if remainingPercent < 10 { return DesignSystem.Colors.Status.error }
        if remainingPercent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }

    private func compactSecondaryText(from header: AccountSummaryCardHeaderModel) -> String? {
        let eyebrow = header.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = header.meta?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let eyebrow, !eyebrow.isEmpty, let meta, !meta.isEmpty {
            return "\(eyebrow) • \(meta)"
        }
        if let eyebrow, !eyebrow.isEmpty {
            return eyebrow
        }
        if let meta, !meta.isEmpty {
            return meta
        }
        return nil
    }

    private func compactPlanText(from header: AccountSummaryCardHeaderModel) -> String {
        let raw = header.subtitle ?? "-"
        let plan = raw
            .split(separator: "•")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (plan?.isEmpty == false) ? plan! : "-"
    }

    private func compactStatusColor(
        presentation: AccountCardPresentation,
        badge: AccountSummaryCardBadgeModel?
    ) -> Color {
        if let badge {
            switch badge.tone {
            case .active:
                return DesignSystem.Colors.primary
            case .warning:
                return DesignSystem.Colors.Status.warning
            case .neutral:
                return DesignSystem.Colors.Text.secondary
            }
        }
        switch presentation.selectionStyle {
        case .active, .selected:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.Status.warning
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        }
    }

    private func handleCodexOutcomeAction(
        action: AccountCardActionID,
        accountId: UUID?,
        onRefresh: (() -> Void)?,
        onLogin: (() -> Void)?,
        failureDetail: String?
    ) {
        switch action {
        case .refresh:
            onRefresh?()
        case .relogin:
            onLogin?()
        case .activate:
            if let accountId {
                Task { await accountsViewModel.codex.activateAccountImmediately(id: accountId) }
            }
        case .copyError:
            if let failureDetail {
                viewModel.codex.copyErrorText(failureDetail)
            }
        case .revealInFinder:
            if let accountId {
                viewModel.codex.revealAccountInFinder(id: accountId)
            }
        case .copyAuthJSON:
            if let accountId {
                viewModel.codex.copyAccountAuthJSON(id: accountId)
            }
        case .editAuthJSON:
            if let accountId {
                viewModel.codex.editAccountAuthJSON(id: accountId)
            }
        case .delete:
            if let accountId {
                accountsViewModel.codex.requestDeleteAccount(id: accountId)
            }
        default:
            break
        }
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
