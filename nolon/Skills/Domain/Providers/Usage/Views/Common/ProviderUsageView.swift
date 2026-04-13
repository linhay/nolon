import SwiftUI
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import NolonUIFoundation
import NolonUI

private struct ClaudeAccountEditorSheet: View {
    typealias Draft = ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft

    @Binding var draft: Draft?
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titleText)
                .font(.title3.weight(.semibold))

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Form {
                TextField(
                    NSLocalizedString("claude.accounts.editor.name", value: "Name", comment: "Claude account name"),
                    text: stringBinding(\.name)
                )

                Picker(
                    NSLocalizedString("claude.accounts.editor.credential_type", value: "Credential Type", comment: "Claude credential type"),
                    selection: credentialTypeBinding
                ) {
                    Text("Auth Token").tag(ClaudeCredentialType.authToken)
                    Text("API Key").tag(ClaudeCredentialType.apiKey)
                }

                SecureField(
                    NSLocalizedString("claude.accounts.editor.credential", value: "Credential", comment: "Claude credential value"),
                    text: stringBinding(\.credentialValue)
                )

                TextField(
                    NSLocalizedString("claude.accounts.editor.base_url", value: "Base URL", comment: "Claude base URL"),
                    text: stringBinding(\.baseURL)
                )

                TextField("Model", text: stringBinding(\.anthropicModel))
                TextField("Reasoning Model", text: stringBinding(\.anthropicReasoningModel))
                TextField("Default Haiku Model", text: stringBinding(\.anthropicDefaultHaikuModel))
                TextField("Default Sonnet Model", text: stringBinding(\.anthropicDefaultSonnetModel))
                TextField("Default Opus Model", text: stringBinding(\.anthropicDefaultOpusModel))
            }
            .formStyle(.grouped)

            HStack {
                Spacer(minLength: 0)
                Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")) {
                    onCancel()
                }
                Button(saveButtonTitle) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
    }

    private var titleText: String {
        switch draft?.mode {
        case .create:
            return NSLocalizedString("claude.accounts.editor.create", value: "New Claude Account", comment: "Create Claude account")
        case .edit:
            return NSLocalizedString("claude.accounts.editor.edit", value: "Edit Claude Account", comment: "Edit Claude account")
        case nil:
            return NSLocalizedString("claude.accounts.editor.title", value: "Claude Account", comment: "Claude account editor title")
        }
    }

    private var saveButtonTitle: String {
        switch draft?.mode {
        case .create:
            return NSLocalizedString("generic.create", value: "Create", comment: "Create")
        case .edit:
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        case nil:
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
    }

    private var credentialTypeBinding: Binding<ClaudeCredentialType> {
        Binding(
            get: { draft?.credentialType ?? .authToken },
            set: { newValue in
                guard var draft else { return }
                draft.credentialType = newValue
                self.draft = draft
            }
        )
    }

    private func stringBinding(_ keyPath: WritableKeyPath<Draft, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { value in
                guard var draft else { return }
                draft[keyPath: keyPath] = value
                self.draft = draft
            }
        )
    }
}

private extension ProviderFetchKind {
    var nolonLabel: String {
        switch self {
        case .cli:
            return "CLI"
        case .web:
            return "Web"
        case .oauth:
            return "OAuth"
        case .apiToken:
            return "API Token"
        case .localProbe:
            return "Local Probe"
        case .webDashboard:
            return "Dashboard"
        }
    }
}

private extension ProviderFetchStrategyKind {
    var nolonLabel: String {
        switch self {
        case .direct:
            return NSLocalizedString("usage.fetch.strategy.direct", value: "Direct", comment: "Direct fetch strategy")
        case .fallback:
            return NSLocalizedString("usage.fetch.strategy.fallback", value: "Fallback", comment: "Fallback fetch strategy")
        }
    }
}

struct ProviderUsageView: View, DebugPageLocatable {
    let provider: Provider
    let isEmbedded: Bool
    @State private var rootViewModel: ProviderUsageRootViewModel
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

    var debugPageMarkerItems: [PageMarkerItem] { rootViewModel.debugPageMarkerItems }
    var tokenTrendDebugPageMarkerItems: [PageMarkerItem] { rootViewModel.tokenTrendDebugPageMarkerItems }

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
                    onCancel: { viewModel.codex.dismissConfigEditor() },
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
    func performMenuAction(in rootViewModel: ProviderUsageRootViewModel)
}

enum ProviderUsageMenuButtonAction: String, Identifiable {
    case refresh
    case claudeAddAccount
    case claudeMigrateCurrent
    case claudeImportFromCCSwitch
    case codexEnterMultiSelection
    case codexNewAPIKey

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
        case .claudeAddAccount, .codexEnterMultiSelection, .codexNewAPIKey:
            return true
        }
    }

    func performMenuAction(in rootViewModel: ProviderUsageRootViewModel) {
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

    @ViewBuilder
    private var codexManagementCard: some View {
        if let status = viewModel.codex.managementStatus, status.needsEnable || status.needsMigration {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    NSLocalizedString(
                        "codex.accounts.management.title",
                        value: "Codex 本地账号托管",
                        comment: "Codex management card title"
                    )
                )
                .font(.headline)

                Text(codexManagementSummary(status: status))
                    .font(.subheadline)
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)

                HStack(spacing: 8) {
                    if status.needsEnable {
                        Button(
                            NSLocalizedString(
                                "codex.accounts.management.enable",
                                value: "启用托管",
                                comment: "Enable Codex management"
                            )
                        ) {
                            Task { await viewModel.codex.enableManagement() }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if status.needsMigration {
                        Button(
                            NSLocalizedString(
                                "codex.accounts.management.migrate",
                                value: "迁移现有数据",
                                comment: "Migrate Codex management data"
                            )
                        ) {
                            Task { await viewModel.codex.migrateManagementData() }
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

    @ViewBuilder
    private var codexAccountsSection: some View {
        let sections = viewModel.codex.accountDisplaySections

        if viewModel.isLoading && sections.isEmpty {
            codexOutcomesContainer(viewModel.codex.accountOutcomes)
        } else if sections.isEmpty {
            ProviderUsageEmptyStateCard(
                title: LocalizedStringKey("codex.accounts.empty.title"),
                systemImage: "person.crop.circle.badge.exclamationmark",
                descriptionText: Text(
                    NSLocalizedString(
                        "codex.accounts.empty.desc",
                        value: "No Codex accounts are currently available.",
                        comment: "Codex accounts empty description"
                    )
                )
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = section.title, !title.isEmpty {
                            Button {
                                viewModel.codex.toggleSection(section.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.codex.isSectionCollapsed(section.id) ? "chevron.right" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                    Text(title)
                                        .font(.headline)
                                    Spacer(minLength: 0)
                                    Text("\(section.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if !viewModel.codex.isSectionCollapsed(section.id) {
                            codexOutcomesContainer(section.items)
                        }
                    }
                }
            }
        }
    }

    private var tokenTrendSection: some View {
        ProviderTokenTrendSection(
            snapshot: tokenTrendViewModel.tokenTrendSnapshot,
            isLoading: tokenTrendViewModel.isLoadingTokenTrend,
            errorMessage: tokenTrendViewModel.tokenTrendErrorMessage,
            range: tokenTrendViewModel.tokenTrendRange,
            onRangeChange: { tokenTrendViewModel.setRange($0) },
            onRefresh: { tokenTrendViewModel.refreshNow() },
            debugPageMarkerItems: tokenTrendDebugPageMarkerItems
        )
    }

    private func codexManagementSummary(status: CodexAuthManager.CodexManagementStatus) -> String {
        let authState = status.providerAuthIsSymlink
            ? NSLocalizedString("codex.accounts.management.auth_linked", value: "已接管 auth.json", comment: "Provider auth linked")
            : NSLocalizedString("codex.accounts.management.auth_unmanaged", value: "auth.json 未接管", comment: "Provider auth unmanaged")

        return [
            String(
                format: NSLocalizedString(
                    "codex.accounts.management.snapshot_count",
                    value: "已发现 %d 个快照",
                    comment: "Codex snapshot count"
                ),
                status.snapshotCount
            ),
            authState
        ].joined(separator: " · ")
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
        ProviderQuotaSectionDataBuilder.build(
            provider: provider,
            accountTitle: nil,
            usage: usage,
            credits: credits,
            syncText: nil,
            isLoading: viewModel.isLoading,
            errorMessage: nil,
            showsEmptyState: true,
            usesCardChrome: true,
            showsHeader: true
        )
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
        return TextNormalizationSupport.joinedNonEmpty([
            identity?.accountOrganization,
            identity?.loginMethod,
        ])
    }

    private func genericOutcomeIdentityDetails(
        outcome: ProviderAccountUsageOutcome,
        result: ProviderFetchResult
    ) -> (account: String?, plan: String?) {
        let identity = result.usage.identity?.scoped(to: outcome.provider)
        return (
            account: TextNormalizationSupport.trimmed(identity?.accountEmail),
            plan: TextNormalizationSupport.trimmed(identity?.plan)
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
        [.codexNewAPIKey]
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
        action.performMenuAction(in: currentRootViewModel)
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
                    .performMenuAction(in: currentRootViewModel)
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
    typealias CodexListUsageWindow = ProviderUsageAccountsViewModel.CodexState.ListUsageWindow

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
        let models = outcomes.map {
            accountsViewModel.codex.makeUsageCardModel(
                outcome: $0,
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
                handleCodexAccountCardTap(accountID: model.accountID)
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
        let model = accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            isRunningCLILogin: loginFlowViewModel.isRunningCLILogin
        )
        let cardView = codexCompactSnapshotView(model: model)

        if let accountId = model.accountID, accountsViewModel.codex.isMultiSelectionEnabled {
            NolonUI.GenericSelectionControl(
                value: IDBox(accountId),
                selections: selectedCodexAccountIDBoxesBinding
            ) { _ in
                cardView
            }
            .applyCodexAccountDraggable(accountID: accountId)
        } else {
            let tappableCardView = cardView.onTapGesture {
                handleCodexAccountCardTap(accountID: model.accountID)
            }

            tappableCardView.applyCodexAccountDraggable(accountID: model.accountID)
        }
    }

    private func handleCodexAccountCardTap(accountID: UUID?) {
        guard let accountID else { return }
        let shouldActivate = accountsViewModel.codex.shouldActivateAccountOnTap(id: accountID)
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

    func compactUsageWindows(from data: AccountCardViewData) -> [CodexListUsageWindow] {
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
        case .active, .transitioning, .selected:
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
    func applyCodexAccountDraggable(accountID _: UUID?) -> some View {
        self
    }
}
