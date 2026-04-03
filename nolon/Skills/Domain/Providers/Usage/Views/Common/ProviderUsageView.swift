import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import NolonUIFoundation
import NolonUI

struct ProviderUsageView: View, DebugPageLocatable {
    let provider: Provider
    let isEmbedded: Bool
    @State private var rootViewModel: ProviderUsageRootViewModel
    @State var targetingGatewayCardID: UUID?
    @State var gatewayAccountPickerCardID: UUID?
    @State var gatewayAccountPickerSelection: Set<IDBox<UUID>> = []
    var currentRootViewModel: ProviderUsageRootViewModel { rootViewModel }

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

    var debugPageMarkerItems: [PageMarkerItem] { rootViewModel.debugPageMarkerItems }
    var tokenTrendDebugPageMarkerItems: [PageMarkerItem] { rootViewModel.tokenTrendDebugPageMarkerItems }
    var gatewayCardsDebugPageMarkerItems: [PageMarkerItem] { rootViewModel.gatewayCardsDebugPageMarkerItems }

    var body: some View {
        NolonUI.ProviderUsageScreenScaffold(
            isEmbedded: isEmbedded,
            navigationTitle: rootViewModel.usageNavigationTitle,
            isShowingCopyToast: viewModel.isShowingCopyToast,
            copyToastMessage: viewModel.copyToastMessage ?? ""
        ) {
            header
        } content: {
            content
        }
        .task(id: provider.id) {
            syncSettingsFromStore()
            _ = await rootViewModel.loadIfNeeded()
        }
        .onChange(of: provider.id) { _, _ in
            rootViewModel = ProviderUsageRootViewModelStore.shared.viewModel(for: provider)
            syncSettingsFromStore()
            Task { _ = await rootViewModel.loadIfNeeded() }
        }
        .onChange(of: provider) { _, _ in
            rootViewModel = ProviderUsageRootViewModelStore.shared.viewModel(for: provider)
            syncSettingsFromStore()
            Task { _ = await rootViewModel.loadIfNeeded() }
        }
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.load() }
        }
        .task(id: provider.id) {
            while !Task.isCancelled {
                await viewModel.performScheduledRefreshTick()
                if Task.isCancelled { break }
                let waitSeconds = viewModel.scheduledRefreshPollInterval(now: Date())
                let waitNanoseconds = UInt64(max(1, waitSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: waitNanoseconds)
            }
        }
        .sheet(isPresented: loginFlowViewModel.isShowingLoginBinding) {
            NolonUI.UsageLoginSheetView(title: provider.name, url: loginFlowViewModel.dashboardURL)
        }
        .sheet(isPresented: loginFlowViewModel.isShowingLoginURLSheetBinding, onDismiss: {
            loginFlowViewModel.handleLoginURLSheetDismissed()
        }) {
            NolonUI.CodexLoginURLSheetView(
                mode: loginFlowViewModel.loginModeForSheet ?? "Login",
                url: loginFlowViewModel.loginURLForSheet,
                onCopy: { loginFlowViewModel.copyLoginURL() },
                onOpen: { loginFlowViewModel.reopenLoginURLInBrowser() },
                onCancel: { loginFlowViewModel.cancelCLILoginIfNeeded() }
            )
        }
        .sheet(isPresented: importExportViewModel.isShowingCodexImportSheetBinding, onDismiss: {
            importExportViewModel.dismissCodexImportSheet()
        }) {
            CodexImportSheet(
                viewModel: importExportViewModel.sheetViewModel,
                onCancel: { importExportViewModel.dismissCodexImportSheet() }
            )
        }
        .sheet(item: viewModel.codex.activeSheetBinding) { sheet in
            switch sheet {
            case .configEditor:
                CodexConfigEditorSheet(
                    draft: Binding(
                        get: { viewModel.codex.configEditorDraft },
                        set: { viewModel.codex.configEditorDraft = $0 }
                    ),
                    modelProviderOptions: viewModel.codex.configEditorModelProviderOptions,
                    errorMessage: viewModel.codex.configEditorErrorMessage,
                    testSuccessMessage: viewModel.codex.usageQueryTestSuccessMessage,
                    testErrorMessage: viewModel.codex.usageQueryTestErrorMessage,
                    isTestingUsageQuery: viewModel.codex.isTestingUsageQuery,
                    onCancel: { viewModel.codex.dismissConfigEditor() },
                    onTest: { Task { await viewModel.codex.testUsageQueryDraft() } },
                    onValidateConnection: { Task { await viewModel.codex.validateConnectionDraft() } },
                    onSave: { Task { await viewModel.codex.saveConfigEditor() } }
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.claude.isShowingEditor },
                set: { if !$0 { viewModel.claude.dismissEditor() } }
            )
        ) {
            ClaudeAccountEditorSheet(
                draft: Binding(
                    get: { viewModel.claude.editorDraft },
                    set: { viewModel.claude.editorDraft = $0 }
                ),
                errorMessage: viewModel.claude.editorErrorMessage,
                onCancel: { viewModel.claude.dismissEditor() },
                onSave: { Task { await viewModel.claude.saveEditor() } }
            )
        }
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
        .confirmationAlert(
            data: geminiImportAlertData,
            isPresented: Binding(
                get: { viewModel.gemini.isShowingImportConfirm },
                set: { viewModel.gemini.isShowingImportConfirm = $0 }
            ),
            onConfirm: {
                Task { await viewModel.gemini.importGlobalSessionAfterConfirmation() }
            },
            onCancel: {
                viewModel.gemini.continueOAuthLoginWithoutImport()
            }
        )
        .messageAlert(alert: globalAlertBinding)
        .confirmationAlert(
            data: codexActivateAlertData,
            isPresented: Binding(
                get: { viewModel.codex.isShowingActivateConfirm },
                set: { viewModel.codex.isShowingActivateConfirm = $0 }
            ),
            onConfirm: {
                Task { await viewModel.codex.confirmActivate() }
            },
            onCancel: {
                viewModel.codex.pendingActivateAccount = nil
            }
        )
        .confirmationAlert(
            data: codexDeleteAlertData,
            isPresented: Binding(
                get: { viewModel.codex.isShowingDeleteConfirm },
                set: { viewModel.codex.isShowingDeleteConfirm = $0 }
            ),
            onConfirm: {
                Task { await accountsViewModel.codex.confirmDeleteAccount() }
            },
            onCancel: {
                viewModel.codex.pendingDeleteAccount = nil
            }
        )
            .debugPageLocator(debugPageMarkerItems)
    }

    private var geminiImportAlertData: ConfirmationAlertData {
        let email = viewModel.gemini.pendingImportCandidate?.email ?? NSLocalizedString("generic.unknown", value: "Unknown", comment: "Unknown")
        let path = viewModel.gemini.pendingImportCandidate?.geminiDirectoryPath ?? "~/.gemini"
        let format = NSLocalizedString(
            "gemini.import.confirm.message",
            value: "Detected an existing Gemini CLI login (%@) at:\n%@\n\nImport it into Nolon now?",
            comment: "Gemini import confirmation message"
        )
        return ConfirmationAlertData(
            title: NSLocalizedString("gemini.import.confirm.title", value: "Import Existing Gemini Login?", comment: "Gemini import confirmation title"),
            message: String(format: format, email, path),
            confirmTitle: NSLocalizedString("gemini.import.confirm.import", value: "Import", comment: "Import existing Gemini login"),
            cancelTitle: NSLocalizedString("gemini.import.confirm.skip", value: "Continue OAuth Login", comment: "Continue OAuth login")
        )
    }

    private var globalAlertBinding: Binding<MessageAlertData?> {
        Binding<MessageAlertData?>(
            get: {
                guard let message = viewModel.alertMessage else { return nil }
                return MessageAlertData(
                    title: viewModel.alertTitle ?? "",
                    message: message
                )
            },
            set: { value in
                if value == nil {
                    viewModel.alertTitle = nil
                    viewModel.alertMessage = nil
                }
            }
        )
    }

    private var codexActivateAlertData: ConfirmationAlertData {
        let name = viewModel.codex.pendingActivateAccount?.name ?? ""
        let path = viewModel.codex.authFilePath ?? "~/.codex/auth.json"
        let format = NSLocalizedString(
            "codex.accounts.activate.message",
            value: "Switch to \"%@\"? This will overwrite:\n%@",
            comment: "Activate account message"
        )
        return ConfirmationAlertData(
            title: NSLocalizedString("codex.accounts.activate.title", value: "Activate Account", comment: "Activate account title"),
            message: String(format: format, name, path),
            confirmTitle: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
            cancelTitle: NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")
        )
    }

    private var codexDeleteAlertData: ConfirmationAlertData {
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
        return ConfirmationAlertData(
            title: NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"),
            message: String(format: format, displayName),
            confirmTitle: NSLocalizedString("generic.delete", value: "Delete", comment: "Delete"),
            cancelTitle: NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
            isDestructiveConfirm: true
        )
    }
}


// MARK: - Actions

protocol ProviderUsageHeaderActionRepresentable {
    var headerActionTitle: String { get }
    var headerActionSystemImage: String? { get }
    @MainActor
    func isHeaderActionEnabled(in rootViewModel: ProviderUsageRootViewModel) -> Bool
    @MainActor
    func performHeaderAction(in rootViewModel: ProviderUsageRootViewModel)
}

protocol ProviderUsageMenuButtonActionRepresentable {
    var menuActionTitle: String { get }
    var menuActionSystemImage: String { get }
    @MainActor
    func isMenuActionVisible(in rootViewModel: ProviderUsageRootViewModel) -> Bool
    @MainActor
    func isMenuActionEnabled(in rootViewModel: ProviderUsageRootViewModel) -> Bool
    @MainActor
    func performMenuAction(
        in rootViewModel: ProviderUsageRootViewModel,
        createGatewayCard: @escaping @MainActor () -> Void
    )
}

enum ProviderUsageMenuButtonAction: String, Identifiable {
    case refresh
    case claudeAddAccount
    case claudeMigrateCurrent
    case claudeImportFromCCSwitch
    case codexEnterMultiSelection
    case codexNewAPIKey
    case codexCreateGatewayCard

    var id: String { rawValue }
}

extension ProviderUsageMenuButtonAction: ProviderUsageMenuButtonActionRepresentable {
    var menuActionTitle: String {
        switch self {
        case .refresh:
            return NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")
        case .claudeAddAccount:
            return NSLocalizedString("claude.accounts.action.add", value: "添加账号", comment: "Add Claude account")
        case .claudeMigrateCurrent:
            return NSLocalizedString("claude.accounts.migrate.current", value: "迁移当前配置", comment: "Migrate Claude from current settings")
        case .claudeImportFromCCSwitch:
            return NSLocalizedString("claude.accounts.migrate.cc_switch", value: "从 cc-switch 导入", comment: "Import Claude from cc-switch")
        case .codexEnterMultiSelection:
            return NSLocalizedString("codex.accounts.action.multi_select", value: "进入多选", comment: "Enter Codex multi-select mode")
        case .codexNewAPIKey:
            return NSLocalizedString("codex.accounts.action.new_api_key", value: "新增 API Key", comment: "New API key account")
        case .codexCreateGatewayCard:
            return NSLocalizedString("codex.gateway.cards.create.title", value: "新建网关卡片", comment: "Create gateway card title")
        }
    }

    var menuActionSystemImage: String {
        switch self {
        case .refresh:
            return "arrow.clockwise"
        case .claudeAddAccount:
            return "plus"
        case .claudeMigrateCurrent:
            return "tray.and.arrow.down"
        case .claudeImportFromCCSwitch:
            return "square.and.arrow.down"
        case .codexEnterMultiSelection:
            return "checklist"
        case .codexNewAPIKey:
            return "key"
        case .codexCreateGatewayCard:
            return "square.stack.3d.up.badge.a"
        }
    }

    func isMenuActionVisible(in rootViewModel: ProviderUsageRootViewModel) -> Bool {
        switch self {
        case .claudeAddAccount, .claudeMigrateCurrent, .claudeImportFromCCSwitch:
            return rootViewModel.usageProvider == .claude
        case .codexEnterMultiSelection:
            return !rootViewModel.accountsViewModel.codex.isMultiSelectionEnabled
        default:
            return true
        }
    }

    func isMenuActionEnabled(in rootViewModel: ProviderUsageRootViewModel) -> Bool {
        switch self {
        case .refresh, .claudeMigrateCurrent, .claudeImportFromCCSwitch:
            return !rootViewModel.accountsViewModel.isLoading
        case .claudeAddAccount, .codexEnterMultiSelection, .codexNewAPIKey, .codexCreateGatewayCard:
            return true
        }
    }

    func performMenuAction(
        in rootViewModel: ProviderUsageRootViewModel,
        createGatewayCard: @escaping @MainActor () -> Void
    ) {
        switch self {
        case .refresh:
            Task { await rootViewModel.accountsViewModel.load() }
        case .claudeAddAccount:
            rootViewModel.accountsViewModel.claude.beginCreateAccount()
        case .claudeMigrateCurrent:
            Task { await rootViewModel.accountsViewModel.claude.migrateFromCurrentSettings() }
        case .claudeImportFromCCSwitch:
            Task { await rootViewModel.accountsViewModel.claude.importFromCCSwitch() }
        case .codexEnterMultiSelection:
            rootViewModel.accountsViewModel.codex.toggleMultiSelectionMode()
        case .codexNewAPIKey:
            rootViewModel.accountsViewModel.codex.beginNewAPIKeyAccount()
        case .codexCreateGatewayCard:
            createGatewayCard()
        }
    }
}

extension ProviderUsageRootViewModel.GenericHeaderAction: ProviderUsageHeaderActionRepresentable {
    var headerActionTitle: String {
        switch self {
        case .claudeMigrate:
            return NSLocalizedString("claude.accounts.migrate", value: "迁移", comment: "Migrate Claude accounts")
        case .signIn:
            return NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in")
        case .cliLogin:
            return NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login")
        case .refresh:
            return NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh")
        }
    }

    var headerActionSystemImage: String? {
        switch self {
        case .claudeMigrate:
            return "arrow.triangle.2.circlepath"
        case .signIn:
            return nil
        case .cliLogin:
            return "person.badge.key"
        case .refresh:
            return "arrow.clockwise"
        }
    }

    func isHeaderActionEnabled(in rootViewModel: ProviderUsageRootViewModel) -> Bool {
        switch self {
        case .claudeMigrate, .refresh:
            return !rootViewModel.accountsViewModel.isLoading
        case .signIn:
            return true
        case .cliLogin:
            return !rootViewModel.loginFlowViewModel.isRunningCLILogin
        }
    }

    func performHeaderAction(in rootViewModel: ProviderUsageRootViewModel) {
        switch self {
        case .claudeMigrate:
            Task { await rootViewModel.accountsViewModel.claude.migrateFromCurrentSettings() }
        case .signIn:
            rootViewModel.loginFlowViewModel.isShowingLogin = true
        case .cliLogin:
            rootViewModel.loginFlowViewModel.startLoginFlow()
        case .refresh:
            Task { await rootViewModel.accountsViewModel.load() }
        }
    }
}

extension ProviderUsageEngine.CodexPrimaryHeaderAction: ProviderUsageHeaderActionRepresentable {
    var headerActionTitle: String {
        switch self {
        case .refreshAll:
            return NSLocalizedString("codex.accounts.refresh_all", value: "刷新", comment: "Codex refresh all")
        case .login:
            return NSLocalizedString("codex.accounts.login", value: "登录", comment: "Codex login")
        case .importAuth:
            return NSLocalizedString("codex.accounts.import", value: "导入", comment: "Codex import")
        case .editConfig:
            return NSLocalizedString("codex.accounts.action.edit", value: "Edit", comment: "Edit configured account")
        case .validateConfig:
            return NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
        }
    }

    var headerActionSystemImage: String? {
        switch self {
        case .refreshAll:
            return "arrow.clockwise"
        case .login:
            return "person.badge.key"
        case .importAuth:
            return "tray.and.arrow.down"
        case .editConfig:
            return "pencil"
        case .validateConfig:
            return "checkmark.shield"
        }
    }

    func isHeaderActionEnabled(in rootViewModel: ProviderUsageRootViewModel) -> Bool {
        let accountsViewModel = rootViewModel.accountsViewModel
        let codex = accountsViewModel.codex
        switch self {
        case .refreshAll:
            return !(accountsViewModel.isLoading && !codex.isHeaderRefreshing)
        case .login:
            return !rootViewModel.loginFlowViewModel.isRunningCLILogin
        case .importAuth:
            return true
        case .editConfig:
            return codex.accountSupportsEditing(accountID: codex.activeAccountId)
        case .validateConfig:
            guard let activeID = codex.activeAccountId else { return false }
            return !codex.refreshingAccountIds.contains(activeID)
        }
    }

    func performHeaderAction(in rootViewModel: ProviderUsageRootViewModel) {
        let accountsViewModel = rootViewModel.accountsViewModel
        switch self {
        case .refreshAll:
            accountsViewModel.handleHeaderRefreshButtonTap()
        case .login:
            rootViewModel.loginFlowViewModel.startLoginFlow()
        case .importAuth:
            accountsViewModel.codex.beginImportAuthFiles()
        case .editConfig:
            accountsViewModel.codex.beginEditActiveConfiguredAccount()
        case .validateConfig:
            accountsViewModel.codex.validateActiveConfiguredAccount()
        }
    }
}


// MARK: - Claude Gemini Section

struct ProviderUsageSectionEmptyState {
    let title: String
    let systemImage: String
    let description: String
}

enum ProviderUsageAccountsSectionState<Content> {
    case loading
    case empty(ProviderUsageSectionEmptyState)
    case content(Content)
}

extension ProviderUsageView {
    var usageContent: some View {
        let capabilities = viewModel.capabilities

        return NolonUI.PaddedScrollContainer(
            padding: EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 12)
        ) {
            LazyVStack(alignment: .leading, spacing: 16) {
                if capabilities.isCodexFamily {
                    codexManagementCard
                    if !gatewayCardsViewModel.gatewayCards.isEmpty {
                        gatewayCardsSection
                    }
                    codexAccountsSection
                } else {
                    genericAccountsSection
                }

                if capabilities.showsTokenTrend {
                    tokenTrendSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var genericAccountsSection: some View {
        let cards = viewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: viewModel.preferredUnifiedCardLiveOutcome,
            isLoading: viewModel.isLoading
        )
        let outcomes = viewModel.displayedOutcomesForUnifiedAccounts()
        let state = genericSectionState(cards: cards, outcomes: outcomes)

        return Group {
            if viewModel.capabilities.showsUnifiedImportCallout {
                unifiedImportCallout
            }

            switch state {
            case .loading:
                genericLoadingContent(provider: provider)
            case let .empty(emptyState):
                ProviderUsageEmptyStateCard(
                    title: LocalizedStringKey(emptyState.title),
                    systemImage: emptyState.systemImage,
                    descriptionText: Text(emptyState.description)
                )
                .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: emptyState.title)])
            case let .content((cards, outcomes)):
                if !cards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = viewModel.unifiedAccountSectionTitle(defaultProviderName: provider.name) {
                            Text(title)
                                .font(.headline)
                        }

                        ProviderUsageUnifiedAccountCardGrid(
                            provider: provider,
                            cards: cards.map(\.data),
                            isLoading: false,
                            columns: claudeAccountColumns,
                            layoutMode: ProviderUsageAccountsViewModel.shouldUseCompactUnifiedListRows(
                                layoutMode: viewModel.accountLayoutMode,
                                accountCount: cards.count
                            ) ? .list : .cards,
                            onTap: { cardData in
                                guard let card = cards.first(where: { $0.data.id == cardData.id }) else { return }
                                Task { await card.onTap() }
                            },
                            onAction: { cardData, action in
                                guard let card = cards.first(where: { $0.data.id == cardData.id }) else { return }
                                Task { await card.onAction(action) }
                            }
                        )
                        .id(cards.map(\.id).joined(separator: "|"))
                    }
                }

                ForEach(outcomes) { outcome in
                    genericOutcomeSnapshotView(outcome: outcome)
                }
            }
        }
    }

    private func genericOutcomeSnapshotView(outcome: ProviderAccountUsageOutcome) -> some View {
        NolonUI.UsageSnapshotCardView(data: genericOutcomeSnapshotCardData(outcome)) {
            if case let .success(result) = outcome.outcome.result {
                NolonUI.ProviderQuotaSectionView(
                    data: genericOutcomeQuotaSectionData(
                        provider: outcome.provider,
                        usage: result.usage,
                        credits: result.credits
                    ),
                    onRefresh: nil
                )
            }
        }
    }

    private func genericOutcomeQuotaSectionData(
        provider: UsageProvider,
        usage: UsageSnapshot,
        credits: ProviderUsage.CreditsSnapshot?
    ) -> ProviderQuotaSectionData {
        ProviderQuotaSectionData(
            accountTitle: genericOutcomeResolvedAccountTitle(usage: usage),
            statusPercent: usage.primary?.remainingPercent ?? 100,
            rows: genericOutcomeQuotaRows(provider: provider, usage: usage),
            creditsText: genericOutcomeCreditsText(credits),
            planText: usage.identity?.plan,
            syncText: nil,
            isLoading: viewModel.isLoading,
            errorMessage: nil,
            showsEmptyState: true,
            usesCardChrome: true,
            showsHeader: true
        )
    }

    private func genericOutcomeQuotaRows(
        provider: UsageProvider,
        usage: UsageSnapshot
    ) -> [ProviderQuotaSectionData.WindowRow] {
        genericOutcomeDisplayWindows(usage: usage, provider: provider).map { item in
            let percent = item.window.remainingPercent
            return .init(
                id: item.id,
                title: genericOutcomeLocalizedQuotaTitle(item, provider: provider),
                remainingPercent: percent,
                percentText: genericOutcomePercentText(percent),
                resetText: item.window.resetsAt.map { ProviderQuotaSectionBuilders.resetText(resetsAt: $0) }
            )
        }
    }

    private func genericOutcomeDisplayWindows(
        usage: UsageSnapshot,
        provider _: UsageProvider
    ) -> [UsageWindow] {
        if !usage.windows.isEmpty { return usage.windows }
        var items: [UsageWindow] = []
        if let primary = usage.primary {
            items.append(UsageWindow(id: "primary", title: "Session", window: primary))
        }
        if let secondary = usage.secondary {
            items.append(UsageWindow(id: "secondary", title: "Weekly", window: secondary))
        }
        return items
    }

    private func genericOutcomeLocalizedQuotaTitle(_ item: UsageWindow, provider: UsageProvider) -> String {
        let metadata = ProviderUsageRegistry.metadata(for: provider)
        return switch item.id {
        case "primary":
            metadata?.sessionLabel ?? "Session"
        case "secondary":
            metadata?.weeklyLabel ?? "Weekly"
        default:
            item.title
        }
    }

    private func genericOutcomePercentText(_ percent: Double) -> String {
        if percent.isInfinite { return "∞" }
        return String(format: "%.0f%%", percent)
    }

    private func genericOutcomeCreditsText(_ credits: ProviderUsage.CreditsSnapshot?) -> String? {
        guard let credits, !credits.remaining.isNaN else { return nil }
        if credits.remaining.isInfinite { return "∞" }
        return String(format: "%.0f", credits.remaining)
    }

    private func genericOutcomeResolvedAccountTitle(usage: UsageSnapshot) -> String {
        let email = usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, !email.isEmpty {
            return email
        }
        return NSLocalizedString("usage.account.unknown", value: "Unknown Account", comment: "Unknown account")
    }

    private func genericOutcomeSnapshotCardData(_ outcome: ProviderAccountUsageOutcome) -> UsageSnapshotCardData {
        let providerLabel = outcome.provider.rawValue.uppercased()
        switch outcome.outcome.result {
        case let .success(result):
            let detail = genericOutcomeIdentityDetails(outcome: outcome, result: result)
            return .init(
                header: .init(
                    displayName: outcome.displayName,
                    providerLabel: providerLabel,
                    identityLine: genericOutcomeIdentityLine(outcome: outcome, result: result),
                    accountLine: detail.account,
                    planLine: detail.plan
                ),
                body: .success(
                    footerItems: [
                        result.fetchKind.nolonLabel,
                        result.strategyKind.nolonLabel,
                        result.usage.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    ]
                )
            )
        case let .failure(error):
            let code = ProviderUsageIssueClassifier.classify(
                providerID: outcome.provider.rawValue,
                errorText: error.localizedDescription,
                usageErrorCode: genericUsageErrorCode(from: error)
            )
            let hints = ProviderUsageIssueClassifier.hints(providerID: outcome.provider.rawValue, code: code)
            return .init(
                header: .init(
                    displayName: outcome.displayName,
                    providerLabel: providerLabel,
                    identityLine: nil,
                    accountLine: nil,
                    planLine: nil
                ),
                body: .error(
                    message: error.localizedDescription,
                    diagnostic: code != .unknown ? code.rawValue : nil,
                    hints: hints
                )
            )
        }
    }

    private func genericOutcomeIdentityLine(
        outcome: ProviderAccountUsageOutcome,
        result: ProviderFetchResult
    ) -> String? {
        let identity = result.usage.identity?.scoped(to: outcome.provider)
        let parts: [String] = [
            identity?.accountOrganization?.trimmingCharacters(in: .whitespacesAndNewlines),
            identity?.loginMethod?.trimmingCharacters(in: .whitespacesAndNewlines),
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func genericOutcomeIdentityDetails(
        outcome: ProviderAccountUsageOutcome,
        result: ProviderFetchResult
    ) -> (account: String?, plan: String?) {
        let identity = result.usage.identity?.scoped(to: outcome.provider)
        let account = identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            account: (account?.isEmpty == false) ? account : nil,
            plan: (plan?.isEmpty == false) ? plan : nil
        )
    }

    private func genericUsageErrorCode(from error: Error) -> String? {
        guard let usageError = error as? ProviderUsageError else {
            return nil
        }

        switch usageError {
        case .unsupported:
            return "unsupported"
        case .missingToken:
            return "missingToken"
        case .missingAccount:
            return "missingAccount"
        case .authExpired:
            return "authExpired"
        }
    }

    private func genericLoadingContent(provider: Provider) -> some View {
        ProviderUsageUnifiedAccountCardGrid(
            provider: provider,
            cards: [],
            isLoading: true,
            columns: claudeAccountColumns,
            layoutMode: .cards,
            onTap: { _ in },
            onAction: { _, _ in }
        )
    }

    private func genericSectionState(
        cards: [ProviderUsageUnifiedAccountCardModel],
        outcomes: [ProviderAccountUsageOutcome]
    ) -> ProviderUsageAccountsSectionState<([ProviderUsageUnifiedAccountCardModel], [ProviderAccountUsageOutcome])> {
        if viewModel.isLoading && cards.isEmpty && outcomes.isEmpty {
            return .loading
        }
        if cards.isEmpty, let emptyState = viewModel.unifiedAccountEmptyState {
            return .empty(
                .init(
                    title: emptyState.title,
                    systemImage: emptyState.systemImage,
                    description: emptyState.description
                )
            )
        }
        return .content((cards, outcomes))
    }

    var unifiedImportCallout: some View {
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
            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)

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
        .background(NolonUI.DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: NolonUI.DesignSystem.Metrics.cornerRadiusL, style: .continuous))
    }
}


// MARK: - Header Menu

extension ProviderUsageView {
    var content: some View {
        NolonUI.ProviderEmptyStateScaffold(
            isEmpty: viewModel.usageProvider == nil,
            preset: .usageUnsupported
        ) {
            usageContent
        }
        .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: NSLocalizedString("usage.unsupported.title", value: "Usage monitoring unavailable", comment: "Unsupported usage title"))])
    }

    var header: some View {
        NolonUI.ProviderUsageTitleHeaderView(title: provider.name) {
            if viewModel.capabilities.isCodexFamily {
                accountLayoutPicker

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
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)

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
                            accountsViewModel.codex.clearSelectedAccounts()
                        } label: {
                            Label(
                                NSLocalizedString("codex.accounts.action.clear_selection", value: "清空选择", comment: "Clear Codex selection"),
                                systemImage: "xmark.circle"
                            )
                        }
                        .disabled(!accountsViewModel.codex.hasSelectedAccounts)
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
                    ProviderUsageAccountsViewModel.CodexState.visiblePrimaryHeaderActions(
                        from: viewModel.codex.primaryHeaderActions,
                        isMultiSelectionEnabled: viewModel.codex.isMultiSelectionEnabled
                    ),
                    id: \.id
                ) { action in
                    if action != .importAuth {
                        headerActionButton(action)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                actionsMenu
            } else {
                accountLayoutPicker
                ForEach(currentRootViewModel.genericHeaderActions) { action in
                    headerActionButton(action)
                }
                actionsMenu
            }
        }
        .onChange(of: viewModel.settings) { _, newValue in
            viewModel.updateSettings(newValue)
        }
    }

    @ViewBuilder
    private func headerActionButton<Action: ProviderUsageHeaderActionRepresentable>(
        _ action: Action
    ) -> some View {
        Button {
            action.performHeaderAction(in: currentRootViewModel)
        } label: {
            if let systemImage = action.headerActionSystemImage {
                Label(action.headerActionTitle, systemImage: systemImage)
            } else {
                Text(action.headerActionTitle)
            }
        }
        .disabled(!action.isHeaderActionEnabled(in: currentRootViewModel))
    }

    private var actionsMenu: some View {
        NolonUI.ProviderUsageActionsMenuView(
            showDangerSection: loginFlowViewModel.isRunningCLILogin,
            dangerSectionTitle: NSLocalizedString(
                "usage.menu.section.danger",
                value: "危险操作",
                comment: "Menu section for destructive actions"
            ),
            dangerActionTitle: NSLocalizedString(
                "codex.cli_login.cancel",
                value: "Cancel Login",
                comment: "Cancel CLI login"
            ),
            onDangerAction: {
                loginFlowViewModel.cancelCLILoginIfNeeded()
            }
        ) {
            if viewModel.capabilities.isCodexFamily {
                codexActionsMenuContent
            } else {
                genericActionsMenuContent
            }
        }
    }

    private var accountLayoutPicker: some View {
        Picker(selection: accountLayoutModeBinding) {
            Text(NSLocalizedString("usage.accounts.layout.cards", value: "卡片", comment: "Usage account card layout"))
                .tag(UsageAccountLayoutMode.cards)
            Text(NSLocalizedString("usage.accounts.layout.list", value: "列表", comment: "Usage account list layout"))
                .tag(UsageAccountLayoutMode.list)
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 126)
        .help(
            NSLocalizedString(
                "usage.accounts.layout.help",
                value: "切换账号显示为卡片或列表模式",
                comment: "Usage account layout picker help"
            )
        )
    }

    private var accountLayoutModeBinding: Binding<UsageAccountLayoutMode> {
        Binding(
            get: { viewModel.accountLayoutMode },
            set: { viewModel.setAccountLayoutMode($0) }
        )
    }

    private var codexAccountManagementMenuActions: [ProviderUsageMenuButtonAction] {
        [.codexNewAPIKey, .codexCreateGatewayCard]
    }

    private var genericMenuActions: [ProviderUsageMenuButtonAction] {
        [.refresh]
    }

    private var claudeAccountManagementMenuActions: [ProviderUsageMenuButtonAction] {
        [.claudeAddAccount, .claudeMigrateCurrent, .claudeImportFromCCSwitch]
    }

    private var codexAccountManagementSectionModel: NolonUI.ProviderUsageMenuActionSectionModel {
        .init(
            id: "codex-account-management",
            title: NSLocalizedString("codex.accounts.menu.section.account", value: "账号管理", comment: "Codex menu section for account management"),
            items: codexAccountManagementMenuActions.compactMap(makeMenuActionItem)
        )
    }

    private var genericActionsSectionModel: NolonUI.ProviderUsageMenuActionSectionModel {
        .init(
            id: "generic-account-management",
            title: NSLocalizedString("usage.menu.section.account", value: "账号管理", comment: "Generic menu section for account management"),
            items: genericMenuActions.compactMap(makeMenuActionItem)
        )
    }

    private var claudeActionsSectionModel: NolonUI.ProviderUsageMenuActionSectionModel {
        .init(
            id: "claude-account-management",
            title: NSLocalizedString("usage.menu.section.account", value: "账号管理", comment: "Generic menu section for account management"),
            items: claudeAccountManagementMenuActions.compactMap(makeMenuActionItem)
        )
    }

    private var codexGroupingOptions: [NolonUI.ProviderUsageMenuOption] {
        [
            .init(
                id: ProviderUsageEngine.CodexAccountGroupingOption.none.rawValue,
                title: NSLocalizedString("codex.accounts.grouping.none", value: "无分组", comment: "No grouping")
            ),
            .init(
                id: ProviderUsageEngine.CodexAccountGroupingOption.typeInfo.rawValue,
                title: NSLocalizedString("codex.accounts.grouping.type_info", value: "按套餐/提供商分组", comment: "Group by type info")
            ),
            .init(
                id: ProviderUsageEngine.CodexAccountGroupingOption.customSQLiteGroup.rawValue,
                title: NSLocalizedString("codex.accounts.grouping.custom_sqlite", value: "按自定义分组", comment: "Group by custom sqlite import group")
            )
        ]
    }

    private var codexLayoutOptions: [NolonUI.ProviderUsageMenuOption] {
        [
            .init(
                id: UsageAccountLayoutMode.cards.rawValue,
                title: NSLocalizedString("usage.accounts.layout.cards", value: "卡片", comment: "Usage account card layout")
            ),
            .init(
                id: UsageAccountLayoutMode.list.rawValue,
                title: NSLocalizedString("usage.accounts.layout.list", value: "列表", comment: "Usage account list layout")
            )
        ]
    }

    private var codexSortingOptions: [NolonUI.ProviderUsageMenuSortOption] {
        let selected = viewModel.codex.accountSortOption
        return viewModel.codex.sortMenuOptions.map { option in
            let isSelected = selected == option
            return .init(
                id: option.id,
                title: ProviderUsageEngine.codexSortMenuItemTitle(
                    for: option,
                    direction: isSelected ? viewModel.codex.direction(for: option) : nil
                ),
                isSelected: isSelected
            )
        }
    }

    private func makeMenuActionItem(_ action: ProviderUsageMenuButtonAction) -> NolonUI.ProviderUsageMenuActionItem? {
        guard action.isMenuActionVisible(in: currentRootViewModel) else { return nil }
        return .init(
            id: action.id,
            title: action.menuActionTitle,
            systemImage: action.menuActionSystemImage,
            isEnabled: action.isMenuActionEnabled(in: currentRootViewModel)
        )
    }

    private func performMenuActionItem(_ item: NolonUI.ProviderUsageMenuActionItem) {
        guard let action = ProviderUsageMenuButtonAction(rawValue: item.id) else { return }
        action.performMenuAction(in: currentRootViewModel, createGatewayCard: createGatewayCardWithPrompt)
    }

    private func syncSettingsFromStore() {
        viewModel.settings = UsageMonitorSettingsStore.shared.settings(for: provider)
    }

    private var codexGroupingBinding: Binding<String> {
        Binding(
            get: { viewModel.codex.accountGroupingOption.rawValue },
            set: { raw in
                guard let option = ProviderUsageEngine.CodexAccountGroupingOption(rawValue: raw) else { return }
                viewModel.codex.accountGroupingOption = option
            }
        )
    }

    private var codexLayoutBinding: Binding<String> {
        Binding(
            get: { viewModel.accountLayoutMode.rawValue },
            set: { raw in
                guard let mode = UsageAccountLayoutMode(rawValue: raw) else { return }
                viewModel.setAccountLayoutMode(mode)
            }
        )
    }

    private func selectCodexSortOption(by id: String) {
        guard let option = viewModel.codex.sortMenuOptions.first(where: { $0.id == id }) else { return }
        viewModel.codex.selectSortOption(option)
    }

    @ViewBuilder
    private var codexActionsMenuContent: some View {
        NolonUI.ProviderUsageDisplaySectionView(
            sectionTitle: NSLocalizedString("usage.menu.section.view", value: "显示", comment: "Usage menu section for view options"),
            layoutTitle: NSLocalizedString("usage.accounts.layout.title", value: "布局", comment: "Usage account layout title"),
            layoutSystemImage: "rectangle.grid.1x2",
            layoutOptions: codexLayoutOptions,
            selectedLayoutID: codexLayoutBinding,
            groupingTitle: NSLocalizedString("codex.accounts.grouping.title", value: "分组", comment: "Grouping title"),
            groupingSystemImage: "square.grid.2x2",
            groupingOptions: codexGroupingOptions,
            selectedGroupingID: codexGroupingBinding,
            sortingTitle: NSLocalizedString("codex.accounts.sorting.title", value: "排序", comment: "Sorting title"),
            sortingSystemImage: "arrow.up.arrow.down",
            sortingOptions: codexSortingOptions,
            onSelectSortingID: selectCodexSortOption(by:),
            trailingAction: ProviderUsageMenuButtonAction.codexEnterMultiSelection.isMenuActionVisible(in: currentRootViewModel)
                ? .init(
                    title: ProviderUsageMenuButtonAction.codexEnterMultiSelection.menuActionTitle,
                    systemImage: ProviderUsageMenuButtonAction.codexEnterMultiSelection.menuActionSystemImage
                )
                : nil,
            onTapTrailingAction: {
                ProviderUsageMenuButtonAction.codexEnterMultiSelection
                    .performMenuAction(in: currentRootViewModel, createGatewayCard: createGatewayCardWithPrompt)
            }
        )

        Section {
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

            Button {
                viewModel.codex.beginImportAuthFiles()
            } label: {
                Label(
                    NSLocalizedString("codex.accounts.import", value: "导入", comment: "Codex import"),
                    systemImage: "tray.and.arrow.down"
                )
            }
        } header: {
            Text(NSLocalizedString("codex.accounts.menu.section.quick_actions", value: "快捷操作", comment: "Codex quick actions menu section"))
        }

        NolonUI.ProviderUsageMenuActionsSectionView(
            section: codexAccountManagementSectionModel,
            onTap: performMenuActionItem
        )

    }

    @ViewBuilder
    private var genericActionsMenuContent: some View {
        NolonUI.ProviderUsageDisplaySectionView(
            sectionTitle: NSLocalizedString("usage.menu.section.view", value: "显示", comment: "Usage menu section for view options"),
            layoutTitle: NSLocalizedString("usage.accounts.layout.title", value: "布局", comment: "Usage account layout title"),
            layoutSystemImage: "rectangle.grid.1x2",
            layoutOptions: codexLayoutOptions,
            selectedLayoutID: codexLayoutBinding
        )

        NolonUI.ProviderUsageMenuActionsSectionView(
            section: genericActionsSectionModel,
            onTap: performMenuActionItem
        )

        if viewModel.usageProvider == .claude {
            NolonUI.ProviderUsageMenuActionsSectionView(
                section: claudeActionsSectionModel,
                onTap: performMenuActionItem
            )
        }
    }
}


// MARK: - Codex Compact List

extension ProviderUsageView {
    private typealias CodexListUsageWindow = ProviderUsageAccountsViewModel.CodexState.ListUsageWindow

    private enum CodexCompactListPolicy {
        static let maxUsageWindowCount = 3
    }

    private var usesCompactCodexListRows: Bool {
        viewModel.codex.usesCompactListRows
    }

    private var selectedCodexAccountIDBoxesBinding: Binding<Set<IDBox<UUID>>> {
        Binding(
            get: { accountsViewModel.codex.selectedAccountIDBoxes },
            set: { accountsViewModel.codex.selectedAccountIDBoxes = $0 }
        )
    }

    func codexOutcomesContainer(_ outcomes: [ProviderAccountUsageOutcome]) -> some View {
        Group {
            if usesCompactCodexListRows {
                if accountsViewModel.codex.isMultiSelectionEnabled {
                    VStack(alignment: .leading, spacing: 0) {
                        codexListTableHeader

                        ForEach(Array(outcomes.enumerated()), id: \.element.id) { index, outcome in
                            codexOutcomeCard(outcome: outcome)
                            if index < outcomes.count - 1 {
                                Divider()
                                    .overlay(NolonUI.DesignSystem.Colors.Component.border.opacity(0.25))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NolonUI.DesignSystem.Colors.Background.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(NolonUI.DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    codexListModeModule(outcomes: outcomes)
                }
            } else {
                NolonUI.AdaptiveCardGrid(columns: codexAccountColumns) {
                    ForEach(outcomes) { outcome in
                        codexOutcomeCard(outcome: outcome)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func codexListModeModule(outcomes: [ProviderAccountUsageOutcome]) -> some View {
        let hasActiveGatewayCardSelection = gatewayCardsViewModel.hasActiveGatewayCardSelection
        let models = outcomes.map {
            accountsViewModel.codex.makeUsageCardModel(
                outcome: $0,
                hasActiveGatewayCardSelection: hasActiveGatewayCardSelection,
                isRunningCLILogin: loginFlowViewModel.isRunningCLILogin
            )
        }
        let modelByID = Dictionary(uniqueKeysWithValues: models.map { ($0.data.id, $0) })

        return NolonUI.AccountListModeModule(
            sections: [
                .init(
                    id: "codex-usage-list",
                    items: models.map { model in
                        .init(
                            id: model.data.id,
                            presentation: model.presentation,
                            header: model.data.header,
                            usageWindows: compactUsageWindows(from: model.data).map {
                                let normalized = max(0, min(100, $0.remainingPercent.isInfinite ? 100 : $0.remainingPercent))
                                return .init(
                                    id: $0.id,
                                    title: $0.title,
                                    progress: CGFloat(normalized / 100),
                                    percentText: $0.remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized)
                                )
                            },
                            menuActions: model.data.menuActions.map {
                                .init(
                                    id: $0.id,
                                    title: $0.title,
                                    systemImage: $0.systemImage,
                                    role: $0.role,
                                    isEnabled: $0.isEnabled
                                )
                            }
                        )
                    }
                )
            ],
            accountColumnTitle: NSLocalizedString("codex.accounts.list.header.account", value: "Account", comment: "Codex account list table account column"),
            planColumnTitle: "",
            usageColumnTitle: NSLocalizedString("codex.accounts.list.header.usage", value: "Usage", comment: "Codex account list table usage column"),
            planColumnWidth: 0,
            usageColumnWidth: viewModel.codex.listUsageColumnWidth,
            onTap: { itemID in
                guard let model = modelByID[itemID] else { return }
                handleCodexAccountCardTap(
                    accountID: model.accountID,
                    hasActiveGatewayCardSelection: hasActiveGatewayCardSelection
                )
            },
            onMenuAction: { itemID, actionID in
                guard let model = modelByID[itemID] else { return }
                guard let action = model.data.menuActions.first(where: { $0.id == actionID }) else { return }
                accountsViewModel.codex.handleUsageCardAction(action.actionID, model: model)
            }
        )
    }

    @ViewBuilder
    private func codexOutcomeCard(outcome: ProviderAccountUsageOutcome) -> some View {
        let hasActiveGatewayCardSelection = gatewayCardsViewModel.hasActiveGatewayCardSelection
        let model = accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            hasActiveGatewayCardSelection: hasActiveGatewayCardSelection,
            isRunningCLILogin: loginFlowViewModel.isRunningCLILogin
        )
        let cardView = codexCompactSnapshotView(model: model)

        if let accountId = model.accountID, accountsViewModel.codex.isMultiSelectionEnabled {
            NolonUI.GenericSelectionControl(
                value: IDBox(accountId),
                selections: selectedCodexAccountIDBoxesBinding,
                onToggle: {
                    if hasActiveGatewayCardSelection {
                        gatewayCardsViewModel.clearActiveGatewayCardSelection()
                    }
                }
            ) { _ in
                cardView
            }
            .applyCodexAccountDraggable(accountID: accountId)
        } else {
            let tappableCardView = cardView.onTapGesture {
                handleCodexAccountCardTap(
                    accountID: model.accountID,
                    hasActiveGatewayCardSelection: hasActiveGatewayCardSelection
                )
            }

            tappableCardView.applyCodexAccountDraggable(accountID: model.accountID)
        }
    }

    private func handleCodexAccountCardTap(
        accountID: UUID?,
        hasActiveGatewayCardSelection: Bool
    ) {
        guard let accountID else { return }
        if hasActiveGatewayCardSelection {
            gatewayCardsViewModel.clearActiveGatewayCardSelection()
        }
        let shouldActivate = accountsViewModel.codex.shouldActivateAccountOnTap(
            id: accountID,
            hasActiveGatewayCardSelection: hasActiveGatewayCardSelection
        )
        guard shouldActivate else { return }
        accountsViewModel.codex.requestActivateAccount(id: accountID)
    }

    @ViewBuilder
    private func codexCompactSnapshotView(
        model: ProviderUsageCodexCardModel
    ) -> some View {
        Group {
            if usesCompactCodexListRows {
                codexCompactListRow(
                    model: model
                )
            } else {
                UnifiedAccountCard(
                    data: model.data,
                    onTap: { _ in },
                    onAction: { _, action in
                        accountsViewModel.codex.handleUsageCardAction(action, model: model)
                    }
                )
            }
        }
        .if(viewModel.codex.enablesTextSelection) { view in
            view.textSelection(.enabled)
        }
    }

    private func codexCompactListRow(
        model: ProviderUsageCodexCardModel
    ) -> some View {
        let usageWindows = compactUsageWindows(from: model.data)
        return NolonUI.CodexCompactAccountRowView(
            statusTone: compactStatusTone(
                presentation: model.presentation,
                badge: model.data.header.badge
            ),
            title: model.data.header.title,
            secondaryText: compactSecondaryText(from: model.data.header),
            planText: "",
            usageWindows: usageWindows.map {
                .init(id: $0.id, title: $0.title, remainingPercent: $0.remainingPercent)
            },
            planColumnWidth: 0,
            usageColumnWidth: viewModel.codex.listUsageColumnWidth,
            isSelected: model.presentation == .selected,
            menuActions: model.data.menuActions.map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    systemImage: $0.systemImage,
                    role: $0.role,
                    isEnabled: $0.isEnabled
                )
            },
            onMenuAction: { actionID in
                guard let action = model.data.menuActions.first(where: { $0.id == actionID }) else { return }
                accountsViewModel.codex.handleUsageCardAction(action.actionID, model: model)
            }
        )
    }

    private var codexListTableHeader: some View {
        NolonUI.CodexCompactAccountsTableHeaderView(
            planTitle: "",
            planColumnWidth: 0,
            usageColumnWidth: viewModel.codex.listUsageColumnWidth
        )
    }

    private func compactUsageWindows(from data: AccountCardViewData) -> [CodexListUsageWindow] {
        guard case let .quota(quota) = data.body, let usage = quota.usage else {
            return [.init(id: "none", title: "-", remainingPercent: 0)]
        }
        let metadata = ProviderUsageRegistry.metadata(for: quota.provider)
        return ProviderQuotaSection
            .displayWindows(for: usage, provider: quota.provider)
            .prefix(CodexCompactListPolicy.maxUsageWindowCount)
            .map { item in
                let title: String
                switch item.id {
                case "primary":
                    title = metadata?.sessionLabel ?? "Session"
                case "secondary":
                    title = metadata?.weeklyLabel ?? "Weekly"
                default:
                    title = item.title
                }
                return .init(
                    id: item.id,
                    title: title,
                    remainingPercent: item.window.remainingPercent
                )
            }
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
        guard let plan, !plan.isEmpty else { return "-" }
        return plan
    }

    private func compactStatusTone(
        presentation: AccountCardPresentation,
        badge: AccountSummaryCardBadgeModel?
    ) -> NolonUI.CodexCompactStatusTone {
        if let badge {
            switch badge.tone {
            case .active:
                return .primary
            case .warning:
                return .warning
            case .neutral:
                return .neutral
            }
        }
        switch presentation.selectionStyle {
        case .active, .selected:
            return .primary
        case .pending:
            return .warning
        case .neutral:
            return .neutral
        }
    }

}

private extension View {
    @ViewBuilder
    func applyCodexAccountDraggable(accountID: UUID?) -> some View {
        if let accountID {
            draggable(CodexGatewayAccountDropItem(accountID: accountID))
        } else {
            self
        }
    }
}


// MARK: - Codex Gateway Section

private enum GatewayCandidateSectionKind {
    case relay
    case openAI
    case premium
    case generic
}

extension ProviderUsageView {
    private var codexAccountsLoadingSkeleton: some View {
        Group {
            if viewModel.accountLayoutMode == .list {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                        UnifiedAccountCardSkeleton(providerName: provider.name)
                    }
                }
            } else {
                NolonUI.AdaptiveCardGrid(columns: codexAccountColumns) {
                    ForEach(0..<ProviderUsageSkeletonPolicy.genericCardCount(for: provider), id: \.self) { _ in
                        UnifiedAccountCardSkeleton(providerName: provider.name)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gatewayCardsHeader: some View {
        HStack(spacing: 8) {
            Button {
                gatewayCardsViewModel.toggleGatewayCardsSectionCollapsed()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: gatewayCardsViewModel.isGatewayCardsSectionCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)

                    Label(
                        NSLocalizedString("codex.gateway.cards.title", value: "网关卡片", comment: "Gateway cards section title"),
                        systemImage: "square.stack.3d.up.fill"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.primary)

                    Text("\(gatewayCardsViewModel.gatewayCards.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NolonUI.DesignSystem.Colors.Component.controlFillSubtle)
                        .clipShape(Capsule())
                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    var codexAccountsSection: some View {
        let state = codexAccountsSectionState

        return Group {
            switch state {
            case let .empty(emptyState):
                ProviderUsageEmptyStateCard(
                    title: LocalizedStringKey(emptyState.title),
                    systemImage: emptyState.systemImage,
                    descriptionText: Text(emptyState.description)
                )
                .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: emptyState.title)])
            case .loading:
                codexAccountsLoadingSkeleton
            case let .content(sections):
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        codexAccountSectionHeader(section: section)

                        if !viewModel.codex.isSectionCollapsed(section.id) {
                            codexOutcomesContainer(section.items)
                        }
                    }
                }
                .animation(.snappy(duration: 0.2), value: viewModel.codex.collapsedSectionIDs)
            }
        }
    }

    private var codexAccountsSectionState: ProviderUsageAccountsSectionState<[ProviderUsageEngine.CodexAccountDisplaySection]> {
        if accountsViewModel.codex.accounts.isEmpty && !viewModel.isLoading {
            return .empty(
                .init(
                    title: NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"),
                    systemImage: "person.crop.circle.badge.plus",
                    description: NSLocalizedString(
                        "codex.accounts.empty.desc",
                        value: "Add a snapshot of Codex auth.json to quickly switch accounts.",
                        comment: "Empty state description"
                    )
                )
            )
        }
        if viewModel.isLoading && accountsViewModel.codex.accountOutcomes.isEmpty {
            return .loading
        }
        if viewModel.codex.accountDisplaySections.isEmpty && viewModel.codex.hasActiveAccountFilters {
            return .empty(
                .init(
                    title: NSLocalizedString("codex.accounts.filtered_empty.title", value: "没有可显示的账号", comment: "All accounts hidden by zero quota filter title"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: codexFilteredEmptyDescription
                )
            )
        }
        if viewModel.codex.accountDisplaySections.isEmpty {
            return .empty(
                .init(
                    title: NSLocalizedString("codex.accounts.empty_unexpected.title", value: "暂无可展示账号", comment: "Codex empty fallback title"),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: NSLocalizedString(
                        "codex.accounts.empty_unexpected.desc",
                        value: "已加载账号数据，但当前卡片列表为空。请尝试刷新或切换分组/筛选。",
                        comment: "Codex empty fallback description"
                    )
                )
            )
        }
        return .content(viewModel.codex.accountDisplaySections)
    }

    @ViewBuilder
    private func codexAccountSectionHeader(
        section: ProviderUsageEngine.CodexAccountDisplaySection
    ) -> some View {
        if let title = section.title {
            HStack(spacing: 8) {
                Button {
                    viewModel.codex.toggleSection(section.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.codex.isSectionCollapsed(section.id) ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.primary)
                        Text(
                            "(\(section.items.count) / \(viewModel.codex.accountSectionTotalCountByID[section.id, default: section.items.count]))"
                        )
                            .font(.caption)
                            .foregroundStyle(NolonUI.DesignSystem.Colors.Text.tertiary)
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
    var codexManagementCard: some View {
        if let status = viewModel.codex.managementStatus, status.needsEnable || status.needsMigration {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("codex.management.title", value: "管理状态", comment: "Codex management status"))
                        .font(.headline)
                    Text(NSLocalizedString("codex.management.desc", value: "首次使用建议先启用管理并执行数据迁移。", comment: "Codex management description"))
                        .font(.caption)
                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
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
            .background(NolonUI.DesignSystem.Colors.Component.controlFillSubtle)
            .clipShape(RoundedRectangle(cornerRadius: NolonUI.DesignSystem.Metrics.cornerRadiusL, style: .continuous))
        }
    }

    var gatewayCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            gatewayCardsHeader

            if !gatewayCardsViewModel.isGatewayCardsSectionCollapsed {
                gatewayCardsContainer(gatewayCardsViewModel.gatewayCards)
            }
        }
        .animation(.snappy(duration: 0.2), value: gatewayCardsViewModel.isGatewayCardsSectionCollapsed)
        .debugCardLocator(gatewayCardsDebugPageMarkerItems)
    }

    @ViewBuilder
    private func gatewayCardsContainer(_ cards: [CodexGatewayCard]) -> some View {
        NolonUI.GatewayCardListModule(
            items: cards,
            layoutMode: viewModel.accountLayoutMode == .list ? .list : .cards,
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
        let isCompact = viewModel.codex.usesCompactListRows
        let memberDisplayLimit = viewModel.codex.gatewayMemberDisplayLimit
        let memberRowMaxHeight = viewModel.codex.gatewayMemberRowMaxHeight
        
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
        .animation(NolonUI.DesignSystem.Animations.springQuick, value: isTargeted || isActiveGateway)
        .contentShape(Rectangle())
        .onTapGesture {
            handleGatewayCardSelection(cardID: card.id)
        }
        .dropDestination(for: CodexGatewayAccountDropItem.self) { items, _ in
            handleGatewayCardDrop(accountIDs: items.map(\.accountID), cardID: card.id)
        } isTargeted: { targeted in
            targetingGatewayCardID = GenericSelectionStateResolver.resolveHoverSelection(
                current: targetingGatewayCardID,
                hovered: card.id,
                isHovering: targeted
            )
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

            if ProviderUsageAccountsViewModel.CodexState.shouldShowActivateGatewayContextAction(
                isActiveGateway: isActiveGateway
            ) {
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

    var gatewayCardPickerSheet: some View {
        NolonUI.GatewayCardPickerSheetView(
            data: GatewayCardPickerSheetData(
                title: NSLocalizedString("codex.gateway.cards.picker.title", value: "选择目标网关卡片", comment: "Gateway card picker title"),
                subtitle: String(
                    format: NSLocalizedString(
                        "codex.gateway.cards.picker.selected_count",
                        value: "将加入 %d 个已选账号",
                        comment: "Gateway picker selected count"
                    ),
                    gatewayCardsViewModel.pendingGatewaySelectionAccountIDs.count
                ),
                items: gatewayCardsViewModel.gatewayCards.map { card in
                    GatewayCardPickerItemData(
                        id: card.id,
                        title: card.name,
                        countText: "\(card.memberAccountIDs.count)"
                    )
                },
                cancelTitle: NSLocalizedString("cancel", value: "Cancel", comment: "Cancel")
            ),
            onSelect: { cardID in
                gatewayCardsViewModel.confirmAddPendingAccounts(to: cardID)
            },
            onCancel: {
                gatewayCardsViewModel.dismissGatewayCardPicker()
            }
        )
    }

    func gatewayAccountSelectionSheet(cardID: UUID) -> some View {
        let card = gatewayCardsViewModel.gatewayCards.first(where: { $0.id == cardID })
        let cardName = card?.name ?? NSLocalizedString("codex.gateway.cards.unknown", value: "网关卡片", comment: "Gateway card fallback name")
        let title = String(
            format: NSLocalizedString(
                "codex.gateway.accounts.picker.title",
                value: "为 %@ 选择账号",
                comment: "Gateway account picker title"
            ),
            cardName
        )

        return GatewayAccountSelectionSheetView(
            title: title,
            listSections: gatewayAccountCandidateListSections(for: cardID),
            selections: $gatewayAccountPickerSelection,
            cancelTitle: NSLocalizedString("cancel", value: "Cancel", comment: "Cancel"),
            confirmTitle: NSLocalizedString(
                "codex.gateway.accounts.picker.add",
                value: "加入网关",
                comment: "Add accounts to gateway card"
            ),
            onCancel: dismissGatewayAccountPicker,
            onConfirm: confirmGatewayAccountPickerSelection,
            debugPageMarkerItems: gatewayCardsDebugPageMarkerItems + [PageMarkerItem(title: title)]
        )
    }

    private func gatewayAccountCandidateListSections(for cardID: UUID) -> [NolonUI.AccountListModeSection] {
        let usageListItemsByAccountID = gatewayCandidateUsageListItemsByAccountID()
        return gatewayCardsViewModel.gatewayCandidateSections(for: cardID).map { section in
            NolonUI.AccountListModeSection(
                id: section.id,
                title: section.title,
                items: section.items.map { account in
                    if let existing = usageListItemsByAccountID[account.id] {
                        return existing
                    }

                    let displayName = gatewayCandidateTitle(for: account)
                    let subtitle = gatewayCandidateSubtitle(for: account, title: displayName)
                    return NolonUI.AccountListModeItem(
                        id: account.id.uuidString,
                        presentation: .neutral,
                        header: .init(
                            eyebrow: nil,
                            title: displayName,
                            subtitle: nil,
                            meta: subtitle,
                            badge: nil
                        ),
                        usageWindows: [.init(id: "none", title: "-", progress: 0, percentText: "0%")]
                    )
                }
            )
        }
    }

    private func gatewayCandidateUsageListItemsByAccountID() -> [UUID: NolonUI.AccountListModeItem] {
        let hasActiveGatewayCardSelection = gatewayCardsViewModel.hasActiveGatewayCardSelection
        let models = viewModel.codex.accountDisplaySections
            .flatMap(\.items)
            .map {
                accountsViewModel.codex.makeUsageCardModel(
                    outcome: $0,
                    hasActiveGatewayCardSelection: hasActiveGatewayCardSelection,
                    isRunningCLILogin: loginFlowViewModel.isRunningCLILogin
                )
            }

        var result: [UUID: NolonUI.AccountListModeItem] = [:]
        for model in models {
            guard let accountID = model.accountID else { continue }
            result[accountID] = .init(
                id: accountID.uuidString,
                presentation: model.presentation,
                header: model.data.header,
                usageWindows: accountListModeUsageWindows(from: model.data),
                menuActions: []
            )
        }
        return result
    }

    private func accountListModeUsageWindows(from data: AccountCardViewData) -> [NolonUI.AccountListModeUsageWindow] {
        compactUsageWindows(from: data).map {
            let normalized = max(0, min(100, $0.remainingPercent.isInfinite ? 100 : $0.remainingPercent))
            return .init(
                id: $0.id,
                title: $0.title,
                progress: CGFloat(normalized / 100),
                percentText: $0.remainingPercent.isInfinite ? "∞" : String(format: "%.0f%%", normalized)
            )
        }
    }

    private func gatewayCandidateTitle(for account: CodexAuthAccount) -> String {
        let summary = accountsViewModel.codex.accountSummaries[account.id]
        return ProviderUsageAccountDisplayNameResolver.resolve(
            email: summary?.email,
            summaryAccountID: summary?.accountID,
            cardKind: summary?.cardKind?.rawValue,
            apiKeySuffix: summary?.apiKeySuffix,
            relayModelProvider: summary?.relayModelProvider,
            relayBaseURL: summary?.relayBaseURL,
            relativeAuthPath: account.relativeAuthPath,
            defaultName: account.name,
            accountID: account.id
        )
    }

    private func gatewayCandidateSectionKind(for title: String) -> GatewayCandidateSectionKind {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("relay") {
            return .relay
        }
        if normalized.contains("openai") {
            return .openAI
        }
        if normalized.contains("plus") || normalized.contains("pro") {
            return .premium
        }
        return .generic
    }

    private func gatewayCandidateSectionIcon(for title: String) -> String {
        switch gatewayCandidateSectionKind(for: title) {
        case .relay:
            return "network"
        case .openAI:
            return "bolt.shield"
        case .premium:
            return "sparkles"
        case .generic:
            return "square.grid.2x2"
        }
    }

    private func gatewayCandidateSectionTone(for title: String) -> GatewayCandidateSectionTone {
        switch gatewayCandidateSectionKind(for: title) {
        case .relay:
            return .relay
        case .openAI:
            return .openAI
        case .premium:
            return .premium
        case .generic:
            return .generic
        }
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

    func dismissGatewayAccountPicker() {
        gatewayAccountPickerCardID = nil
        gatewayAccountPickerSelection = []
    }

    private func confirmGatewayAccountPickerSelection() {
        guard let cardID = gatewayAccountPickerCardID else { return }
        let orderedIDs = gatewayCardsViewModel
            .gatewayCandidateAccounts(for: cardID)
            .map(\.id)
            .filter { gatewayAccountPickerSelection.contains(IDBox($0)) }
        guard !orderedIDs.isEmpty else {
            dismissGatewayAccountPicker()
            return
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: orderedIDs, cardID: cardID)
        dismissGatewayAccountPicker()
        Task { await gatewayCardsViewModel.startGatewayForCardSelection(cardID: cardID) }
    }

    private func handleLegacyGatewayCardDrop(items: [String], cardID: UUID) -> Bool {
        handleGatewayCardDrop(
            accountIDs: CodexGatewayDropParser.accountIDs(fromLegacyStrings: items),
            cardID: cardID
        )
    }

    private func handleGatewayCardDrop(accountIDs droppedIDs: [UUID], cardID: UUID) -> Bool {
        guard !droppedIDs.isEmpty else { return false }
        if accountsViewModel.codex.isMultiSelectionEnabled,
           droppedIDs.contains(where: { accountsViewModel.codex.isAccountSelected(id: $0) }) {
            gatewayCardsViewModel.addAccountsToGatewayCard(
                accountIDs: accountsViewModel.codex.selectedAccountIDsInDisplayOrder,
                cardID: cardID
            )
            return true
        }
        gatewayCardsViewModel.addAccountsToGatewayCard(accountIDs: droppedIDs, cardID: cardID)
        return true
    }

    func createGatewayCardWithPrompt() {
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

    var tokenTrendSection: some View {
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
}

private struct ClaudeAccountEditorSheet: View {
    @Binding var draft: ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft?
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    private var currentDraft: ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft? {
        draft
    }

    private static let fallbackAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private var fallbackDraft: ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft {
        .init(
            mode: .create,
            accountID: Self.fallbackAccountID,
            name: "",
            credentialType: .authToken,
            credentialValue: "",
            baseURL: "",
            anthropicModel: "gpt-5",
            anthropicReasoningModel: "",
            anthropicDefaultHaikuModel: "gpt-5(minimal)",
            anthropicDefaultSonnetModel: "gpt-5(medium)",
            anthropicDefaultOpusModel: "gpt-5(high)"
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(NSLocalizedString("claude.accounts.editor.title", value: "编辑 Claude 账号", comment: "Claude account editor title"))
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Group {
                    if currentDraft != nil {
                        Form {
                            Section(
                                NSLocalizedString(
                                    "claude.accounts.editor.section.basic",
                                    value: "基础信息",
                                    comment: "Claude account editor basic section title"
                                )
                            ) {
                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.name",
                                        value: "账号名称",
                                        comment: "Claude account editor name field"
                                    ),
                                    text: binding(\.name)
                                )

                                Picker(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.credential_type",
                                        value: "鉴权类型",
                                        comment: "Claude account editor credential type field"
                                    ),
                                    selection: binding(\.credentialType)
                                ) {
                                    Text(NSLocalizedString("claude.accounts.editor.credential.auth_token", value: "Auth Token", comment: "Claude auth token type")).tag(ClaudeCredentialType.authToken)
                                    Text(NSLocalizedString("claude.accounts.editor.credential.api_key", value: "API Key", comment: "Claude API key type")).tag(ClaudeCredentialType.apiKey)
                                }

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.credential_value",
                                        value: "密钥",
                                        comment: "Claude account editor credential field"
                                    ),
                                    text: binding(\.credentialValue)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.base_url",
                                        value: "Base URL",
                                        comment: "Claude account editor base url field"
                                    ),
                                    text: binding(\.baseURL)
                                )
                            }

                            Section(
                                NSLocalizedString(
                                    "claude.accounts.editor.section.models",
                                    value: "模型配置",
                                    comment: "Claude account editor models section title"
                                )
                            ) {
                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.model",
                                        value: "默认模型 (ANTHROPIC_MODEL)",
                                        comment: "Claude account editor default model field"
                                    ),
                                    text: binding(\.anthropicModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.reasoning_model",
                                        value: "推理模型 (ANTHROPIC_REASONING_MODEL)",
                                        comment: "Claude account editor reasoning model field"
                                    ),
                                    text: binding(\.anthropicReasoningModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.haiku_model",
                                        value: "Haiku 模型 (ANTHROPIC_DEFAULT_HAIKU_MODEL)",
                                        comment: "Claude account editor haiku model field"
                                    ),
                                    text: binding(\.anthropicDefaultHaikuModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.sonnet_model",
                                        value: "Sonnet 模型 (ANTHROPIC_DEFAULT_SONNET_MODEL)",
                                        comment: "Claude account editor sonnet model field"
                                    ),
                                    text: binding(\.anthropicDefaultSonnetModel)
                                )

                                TextField(
                                    NSLocalizedString(
                                        "claude.accounts.editor.field.opus_model",
                                        value: "Opus 模型 (ANTHROPIC_DEFAULT_OPUS_MODEL)",
                                        comment: "Claude account editor opus model field"
                                    ),
                                    text: binding(\.anthropicDefaultOpusModel)
                                )
                            }

                            if let errorMessage, !errorMessage.isEmpty {
                                Section {
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .formStyle(.grouped)
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("claude.accounts.editor.unavailable.title", value: "无法编辑账号", comment: "Claude account editor unavailable title"),
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(NSLocalizedString("claude.accounts.editor.unavailable.desc", value: "账号已不存在，请刷新后重试。", comment: "Claude account editor unavailable description"))
                        )
                        .padding(24)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button(NSLocalizedString("generic.save", value: "Save", comment: "Save")) {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentDraft == nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)
            }

            NolonUI.FloatingCloseButton(
                help: NSLocalizedString("generic.close", value: "Close", comment: "Close"),
                enableCancelShortcut: true,
                action: onCancel
            )
            .padding(16)
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft, T>) -> Binding<T> {
        Binding(
            get: {
                let resolvedDraft = draft ?? fallbackDraft
                return resolvedDraft[keyPath: keyPath]
            },
            set: { newValue in
                guard var draft else { return }
                draft[keyPath: keyPath] = newValue
                self.draft = draft
            }
        )
    }
}

private extension ProviderFetchKind {
    var nolonLabel: String {
        switch self {
        case .web:
            return NSLocalizedString("usage.source.web", value: "Web", comment: "Web")
        case .cli:
            return NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI")
        case .oauth:
            return NSLocalizedString("usage.source.oauth", value: "OAuth", comment: "OAuth")
        case .apiToken:
            return NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token")
        case .localProbe:
            return NSLocalizedString("usage.source.local_probe", value: "Local probe", comment: "Local probe")
        case .webDashboard:
            return NSLocalizedString("usage.source.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        }
    }
}

private extension ProviderFetchStrategyKind {
    var nolonLabel: String {
        switch self {
        case .direct:
            NSLocalizedString("usage.strategy.direct", value: "Direct", comment: "Direct fetch")
        case .fallback:
            NSLocalizedString("usage.strategy.fallback", value: "Fallback", comment: "Fallback fetch")
        }
    }
}
