import Observation
import ProviderUsage
import Foundation
import CodexBarProviderCatalog
import SwiftUI
import NolonUIFoundation

@MainActor
@Observable
final class ProviderUsageAccountsViewModel {
    @MainActor
    final class CodexState {
        enum ActiveSheet: String, Identifiable {
            case configEditor

            var id: String { rawValue }
        }

        struct ListUsageWindow: Identifiable {
            let id: String
            let title: String
            let remainingPercent: Double
        }

        static let listPlanColumnWidth: CGFloat = 96
        static let listUsageColumnWidth: CGFloat = 232

        fileprivate let state: ProviderUsageStateStore

        init(state: ProviderUsageStateStore) {
            self.state = state
        }

        private var engine: any ProviderUsageCodexEngineProtocol { state.codexEngine }

        var accounts: [CodexAuthAccount] { engine.codexAccounts }
        var accountOutcomes: [ProviderAccountUsageOutcome] { engine.codexAccountOutcomes }
        var listPlanColumnWidth: CGFloat { Self.listPlanColumnWidth }
        var listUsageColumnWidth: CGFloat { Self.listUsageColumnWidth }
        var accountSummaries: [UUID: CodexAuthSummary] { engine.codexAccountSummaries }
        var accountCreditsRefreshedAt: [UUID: Date] { engine.codexAccountCreditsRefreshedAt }
        var accountDisplaySections: [CodexAccountDisplaySection] { engine.codexAccountDisplaySections }
        var accountSectionTotalCountByID: [String: Int] { engine.codexAccountSectionTotalCountByID }
        var primaryHeaderActions: [CodexPrimaryHeaderAction] { engine.codexPrimaryHeaderActions }
        var sortMenuOptions: [CodexAccountSortOption] { engine.codexSortMenuOptions }
        var authFilePath: String? { engine.codexAuthFilePath }
        var activeAccountId: UUID? { engine.activeCodexAccountId }
        var refreshingAccountIds: Set<UUID> { engine.codexRefreshingAccountIds }
        var isMultiSelectionEnabled: Bool { engine.isCodexMultiSelectionEnabled }
        var selectedAccountIDs: Set<UUID> {
            get { engine.selectedCodexAccountIDs }
            set { engine.selectedCodexAccountIDs = newValue }
        }
        var selectedAccountIDBoxes: Set<IDBox<UUID>> {
            get { Set(engine.selectedCodexAccountIDs.map(IDBox.init)) }
            set { engine.selectedCodexAccountIDs = Set(newValue.map(\.rawValue)) }
        }
        var hasSelectedAccounts: Bool { !engine.selectedCodexAccountIDs.isEmpty }
        var selectedAccountIDsInDisplayOrder: [UUID] {
            engine.selectedCodexAccountIDsInDisplayOrder()
        }
        var selectedAccountCount: Int { engine.codexSelectedAccountCount }
        var pendingActivateAccount: CodexAuthAccount? {
            get { engine.pendingActivateCodexAccount }
            set { engine.pendingActivateCodexAccount = newValue }
        }
        var managementStatus: CodexAuthManager.CodexManagementStatus? { engine.codexManagementStatus }
        var configEditorDraft: CodexConfigEditorDraft? {
            get { engine.codexConfigEditorDraft }
            set { engine.codexConfigEditorDraft = newValue }
        }
        var configEditorModelProviderOptions: [String] {
            engine.codexConfigEditorModelProviderOptions
        }
        var configEditorErrorMessage: String? { engine.codexConfigEditorErrorMessage }
        var usageQueryTestSuccessMessage: String? { engine.codexUsageQueryTestSuccessMessage }
        var usageQueryTestErrorMessage: String? { engine.codexUsageQueryTestErrorMessage }
        var isTestingUsageQuery: Bool { engine.isTestingCodexUsageQuery }
        var isShowingConfigEditor: Bool {
            get { engine.isShowingCodexConfigEditor }
            set { engine.isShowingCodexConfigEditor = newValue }
        }
        var activeSheet: ActiveSheet? {
            get { isShowingConfigEditor ? .configEditor : nil }
            set { isShowingConfigEditor = (newValue == .configEditor) }
        }
        var activeSheetBinding: Binding<ActiveSheet?> {
            Binding(
                get: { self.activeSheet },
                set: { self.activeSheet = $0 }
            )
        }
        var hideZeroQuotaAccounts: Bool { engine.codexHideZeroQuotaAccounts }
        var hideErroredAccounts: Bool { engine.codexHideErroredAccounts }
        var hasActiveAccountFilters: Bool { engine.hasActiveCodexAccountFilters }
        var accountGroupingOption: CodexAccountGroupingOption {
            get { engine.codexAccountGroupingOption }
            set { engine.setCodexAccountGroupingOption(newValue) }
        }
        var accountSortOption: CodexAccountSortOption {
            get { engine.codexAccountSortOption }
            set { engine.codexAccountSortOption = newValue }
        }
        var accountLayoutMode: UsageAccountLayoutMode { state.commonEngine.accountLayoutMode }
        var usesCompactListRows: Bool { Self.usesCompactListRows(layoutMode: accountLayoutMode) }
        var enablesTextSelection: Bool { Self.enablesTextSelection(layoutMode: accountLayoutMode) }
        var collapsedSectionIDs: Set<String> { engine.collapsedCodexSectionIDs }
        var isHeaderRefreshing: Bool { engine.isCodexHeaderRefreshing }
        var canExportSelectedAccounts: Bool { engine.canExportSelectedCodexAccounts }
        var canAddSelectedToGatewayCard: Bool { engine.canAddSelectedToGatewayCard }
        var gatewayMemberDisplayLimit: Int { Self.gatewayMemberDisplayLimit(layoutMode: accountLayoutMode) }
        var gatewayMemberRowMaxHeight: CGFloat { Self.gatewayMemberRowMaxHeight(layoutMode: accountLayoutMode) }
        var isShowingActivateConfirm: Bool {
            get { engine.isShowingActivateConfirm }
            set { engine.isShowingActivateConfirm = newValue }
        }
        var isShowingDeleteConfirm: Bool {
            get { engine.isShowingDeleteConfirm }
            set { engine.isShowingDeleteConfirm = newValue }
        }
        var pendingDeleteAccount: CodexAuthAccount? {
            get { engine.pendingDeleteCodexAccount }
            set { engine.pendingDeleteCodexAccount = newValue }
        }
        var isShowingGatewayCardPicker: Bool { engine.isShowingGatewayCardPicker }
        var cliLoginPreferredAccountId: UUID? { engine.cliLoginPreferredAccountId }
        var hasPendingActivateAccount: Bool { engine.pendingActivateCodexAccount != nil }

        func requestActivateAccount(id: UUID) {
            engine.requestActivateCodexAccount(id: id)
        }

        static func visiblePrimaryHeaderActions(
            from actions: [CodexPrimaryHeaderAction],
            isMultiSelectionEnabled: Bool
        ) -> [CodexPrimaryHeaderAction] {
            guard !isMultiSelectionEnabled else { return [] }
            return Array(actions.prefix(3))
        }

        static func shouldShowActivateGatewayContextAction(isActiveGateway: Bool) -> Bool {
            !isActiveGateway
        }

        static func usesCompactListRows(layoutMode: UsageAccountLayoutMode) -> Bool {
            layoutMode == .list
        }

        static func enablesTextSelection(layoutMode: UsageAccountLayoutMode) -> Bool {
            !usesCompactListRows(layoutMode: layoutMode)
        }

        static func gatewayMemberDisplayLimit(layoutMode: UsageAccountLayoutMode) -> Int {
            usesCompactListRows(layoutMode: layoutMode) ? 8 : 12
        }

        static func gatewayMemberRowMaxHeight(layoutMode: UsageAccountLayoutMode) -> CGFloat {
            usesCompactListRows(layoutMode: layoutMode) ? 48 : 70
        }

        func confirmActivate() async {
            await engine.confirmActivate()
        }

        @discardableResult
        func activateAccount(id: UUID) async -> Bool {
            requestActivateAccount(id: id)
            guard hasPendingActivateAccount else { return false }
            await confirmActivate()
            return true
        }

        func requestDeleteAccount(id: UUID) {
            engine.requestDeleteCodexAccount(id: id)
        }

        func confirmDeleteAccount() async {
            await engine.confirmDeleteCodexAccount()
        }

        func refreshAccountImmediately(id: UUID) async {
            await engine.refreshCodexAccountImmediately(id: id)
        }

        func isAccountSelected(id: UUID?) -> Bool {
            engine.isCodexAccountSelected(id: id)
        }

        func shouldActivateAccountOnTap(id: UUID, hasActiveGatewayCardSelection: Bool) -> Bool {
            engine.shouldActivateCodexAccountOnTap(id: id, hasActiveGatewayCardSelection: hasActiveGatewayCardSelection)
        }

        func setMultiSelectionEnabled(_ enabled: Bool) {
            engine.setCodexMultiSelectionEnabled(enabled)
        }

        func clearSelectedAccounts() {
            engine.selectedCodexAccountIDs.removeAll()
        }

        func isActiveAccount(_ account: CodexAuthAccount) -> Bool {
            engine.isActiveCodexAccount(account)
        }

        func accountSupportsLogin(accountID: UUID?) -> Bool {
            engine.codexAccountSupportsLogin(accountID: accountID)
        }

        func requestLoginForAccount(id: UUID) {
            engine.requestLoginForCodexAccount(id: id)
        }

        func refreshAccount(id: UUID) {
            engine.refreshCodexAccount(id: id)
        }

        func activateAccountImmediately(id: UUID) async {
            await engine.activateCodexAccountImmediately(id: id)
        }

        func exportSelectedAccountsAsZIP() async {
            await engine.exportSelectedCodexAccountsAsZIP()
        }

        func beginEditActiveConfiguredAccount() {
            engine.beginEditActiveCodexConfiguredAccount()
        }

        func validateActiveConfiguredAccount() {
            engine.validateActiveCodexConfiguredAccount()
        }

        func accountSupportsEditing(accountID: UUID?) -> Bool {
            engine.codexAccountSupportsEditing(accountID: accountID)
        }

        func testUsageQueryDraft() async {
            await engine.testCodexUsageQueryDraft()
        }

        func validateConnectionDraft() async {
            await engine.validateCodexConnectionDraft()
        }

        func dismissConfigEditor() {
            engine.dismissCodexConfigEditor()
        }

        func saveConfigEditor() async {
            await engine.saveCodexConfigEditor()
        }

        func beginNewAPIKeyAccount() {
            engine.beginNewCodexAPIKeyAccount()
        }

        func selectSortOption(_ option: CodexAccountSortOption) {
            engine.selectCodexSortOption(option)
        }

        func toggleSection(_ sectionID: String) {
            engine.toggleCodexSection(sectionID)
        }

        func toggleSectionSelection(_ sectionID: String) {
            guard let section = engine.codexAccountDisplaySections.first(where: { $0.id == sectionID }) else { return }
            engine.toggleCodexSectionSelection(section)
        }

        func toggleSectionSelection(_ section: CodexAccountDisplaySection) {
            engine.toggleCodexSectionSelection(section)
        }

        func toggleMultiSelectionMode() {
            engine.setCodexMultiSelectionEnabled(!engine.isCodexMultiSelectionEnabled)
        }

        func setHideZeroQuotaAccounts(_ hidden: Bool) {
            engine.setCodexHideZeroQuotaAccounts(hidden)
        }

        func setHideErroredAccounts(_ hidden: Bool) {
            engine.setCodexHideErroredAccounts(hidden)
        }

        func enableManagement() async {
            await engine.enableCodexManagement()
        }

        func migrateManagementData() async {
            await engine.migrateCodexManagementData()
        }

        func revealAccountInFinder(id: UUID) {
            engine.revealCodexAccountInFinder(id: id)
        }

        func copyAccountAuthJSON(id: UUID) {
            engine.copyCodexAccountAuthJSON(id: id)
        }

        func editAccountAuthJSON(id: UUID) {
            engine.editCodexAccountAuthJSON(id: id)
        }

        func setAccountLayoutMode(_ mode: UsageAccountLayoutMode) {
            state.commonEngine.setAccountLayoutMode(mode)
        }

        func isSectionCollapsed(_ sectionID: String) -> Bool {
            engine.isCodexSectionCollapsed(sectionID)
        }

        func isSectionFullySelected(_ section: CodexAccountDisplaySection) -> Bool {
            engine.isCodexSectionFullySelected(section)
        }

        func direction(for option: CodexAccountSortOption) -> CodexSortDirection? {
            engine.codexDirection(for: option)
        }

        func addSelectedToGatewayCard() {
            engine.addSelectedToGatewayCard()
        }

        func beginImportAuthFiles() {
            engine.beginImportAuthFiles()
        }

        func copyErrorText(_ text: String) {
            engine.copyErrorText(text)
        }

        func gatewayMembers(for card: CodexGatewayCard) -> [CodexGatewayMemberDisplay] {
            engine.gatewayMembers(for: card)
        }
    }

    @MainActor
    @Observable
    final class ClaudeState {
        struct AccountEditorDraft: Equatable {
            enum Mode: Equatable {
                case create
                case edit
            }

            let mode: Mode
            let accountID: UUID
            var name: String
            var credentialType: ClaudeCredentialType
            var credentialValue: String
            var baseURL: String
            var anthropicModel: String
            var anthropicReasoningModel: String
            var anthropicDefaultHaikuModel: String
            var anthropicDefaultSonnetModel: String
            var anthropicDefaultOpusModel: String
        }

        fileprivate let state: ProviderUsageStateStore
        var isShowingEditor = false
        var editorDraft: AccountEditorDraft?
        var editorErrorMessage: String?

        init(state: ProviderUsageStateStore) {
            self.state = state
        }

        private var engine: any ProviderUsageClaudeEngineProtocol { state.claudeEngine }

        var accounts: [ClaudeAccount] { engine.claudeAccounts }

        func migrateFromCurrentSettings() async {
            await engine.migrateClaudeFromCurrentSettings()
        }

        func importFromCCSwitch() async {
            await engine.importClaudeFromCCSwitch()
        }

        func activateAccount(id: UUID) async {
            await engine.activateClaudeAccount(id: id)
        }

        func beginEditAccount(id: UUID) {
            guard let account = accounts.first(where: { $0.id == id }) else { return }
            editorDraft = AccountEditorDraft(
                mode: .edit,
                accountID: account.id,
                name: account.name,
                credentialType: account.credentialType,
                credentialValue: account.credentialValue,
                baseURL: account.baseURL,
                anthropicModel: account.anthropicModel,
                anthropicReasoningModel: account.anthropicReasoningModel,
                anthropicDefaultHaikuModel: account.anthropicDefaultHaikuModel,
                anthropicDefaultSonnetModel: account.anthropicDefaultSonnetModel,
                anthropicDefaultOpusModel: account.anthropicDefaultOpusModel
            )
            editorErrorMessage = nil
            isShowingEditor = true
        }

        func beginCreateAccount() {
            editorDraft = AccountEditorDraft(
                mode: .create,
                accountID: UUID(),
                name: "",
                credentialType: .authToken,
                credentialValue: "",
                baseURL: "https://api.anthropic.com",
                anthropicModel: "gpt-5",
                anthropicReasoningModel: "",
                anthropicDefaultHaikuModel: "gpt-5(minimal)",
                anthropicDefaultSonnetModel: "gpt-5(medium)",
                anthropicDefaultOpusModel: "gpt-5(high)"
            )
            editorErrorMessage = nil
            isShowingEditor = true
        }

        func dismissEditor() {
            editorErrorMessage = nil
            editorDraft = nil
            isShowingEditor = false
        }

        func saveEditor() async {
            guard let draft = editorDraft else { return }

            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCredential = draft.credentialValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBaseURL = draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedModel = draft.anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedReasoningModel = draft.anthropicReasoningModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHaiku = draft.anthropicDefaultHaikuModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSonnet = draft.anthropicDefaultSonnetModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedOpus = draft.anthropicDefaultOpusModel.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedCredential.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_credential",
                    value: "Credential cannot be empty.",
                    comment: "Claude account editor empty credential error"
                )
                return
            }
            guard !trimmedBaseURL.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_base_url",
                    value: "Base URL cannot be empty.",
                    comment: "Claude account editor empty base url error"
                )
                return
            }
            guard !trimmedModel.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_model",
                    value: "Model cannot be empty.",
                    comment: "Claude account editor empty model error"
                )
                return
            }
            guard !trimmedHaiku.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_haiku_model",
                    value: "Default Haiku model cannot be empty.",
                    comment: "Claude account editor empty default haiku model error"
                )
                return
            }
            guard !trimmedSonnet.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_sonnet_model",
                    value: "Default Sonnet model cannot be empty.",
                    comment: "Claude account editor empty default sonnet model error"
                )
                return
            }
            guard !trimmedOpus.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_opus_model",
                    value: "Default Opus model cannot be empty.",
                    comment: "Claude account editor empty default opus model error"
                )
                return
            }
            do {
                switch draft.mode {
                case .create:
                    var newAccount = ClaudeAccount(
                        id: draft.accountID,
                        name: trimmedName,
                        credentialType: draft.credentialType,
                        credentialValue: trimmedCredential,
                        baseURL: trimmedBaseURL,
                        anthropicModel: trimmedModel,
                        anthropicReasoningModel: trimmedReasoningModel,
                        anthropicDefaultHaikuModel: trimmedHaiku,
                        anthropicDefaultSonnetModel: trimmedSonnet,
                        anthropicDefaultOpusModel: trimmedOpus,
                        source: .manual
                    )
                    newAccount.createdAt = Date()
                    newAccount.updatedAt = Date()
                    try await engine.createClaudeAccount(newAccount)
                case .edit:
                    guard let account = accounts.first(where: { $0.id == draft.accountID }) else {
                        editorErrorMessage = NSLocalizedString(
                            "claude.accounts.editor.error.not_found",
                            value: "The account no longer exists. Please refresh and try again.",
                            comment: "Claude account editor missing account error"
                        )
                        return
                    }

                    var updated = account
                    updated.name = trimmedName
                    updated.credentialType = draft.credentialType
                    updated.credentialValue = trimmedCredential
                    updated.baseURL = trimmedBaseURL
                    updated.anthropicModel = trimmedModel
                    updated.anthropicReasoningModel = trimmedReasoningModel
                    updated.anthropicDefaultHaikuModel = trimmedHaiku
                    updated.anthropicDefaultSonnetModel = trimmedSonnet
                    updated.anthropicDefaultOpusModel = trimmedOpus
                    try await engine.updateClaudeAccount(updated)
                }
                dismissEditor()
            } catch {
                editorErrorMessage = error.localizedDescription
            }
        }

        func isActiveAccount(_ account: ClaudeAccount) -> Bool {
            engine.isActiveClaudeAccount(account)
        }
    }

    @MainActor
    final class GeminiState {
        fileprivate let state: ProviderUsageStateStore

        init(state: ProviderUsageStateStore) {
            self.state = state
        }

        private var engine: any ProviderUsageGeminiEngineProtocol { state.geminiEngine }

        var accounts: [GeminiAuthAccount] { engine.geminiAccounts }
        var shouldShowImportAction: Bool { engine.shouldShowGeminiImportAction }
        var isShowingImportConfirm: Bool {
            get { engine.isShowingGeminiImportConfirm }
            set { engine.isShowingGeminiImportConfirm = newValue }
        }
        var pendingImportCandidate: GeminiCLIGlobalSessionImportCandidate? { engine.pendingGeminiImportCandidate }
        
        func activateAccount(id: UUID) async {
            await engine.activateGeminiAccount(id: id)
        }

        func deleteAccount(id: UUID) async {
            await engine.deleteGeminiAccount(id: id)
        }

        func presentImportConfirmation() {
            engine.presentGeminiImportConfirmation()
        }

        func continueOAuthLoginWithoutImport() {
            engine.continueGeminiOAuthLoginWithoutImport()
        }

        func importGlobalSessionAfterConfirmation() async {
            await engine.importGeminiGlobalSessionAfterConfirmation()
        }

        func isActiveAccount(_ account: GeminiAuthAccount) -> Bool {
            engine.isActiveGeminiAccount(account)
        }
    }

    private let state: ProviderUsageStateStore
    let codex: CodexState
    let claude: ClaudeState
    let gemini: GeminiState

    init(state: ProviderUsageStateStore) {
        self.state = state
        self.codex = CodexState(state: state)
        self.claude = ClaudeState(state: state)
        self.gemini = GeminiState(state: state)
    }

    private var engine: any ProviderUsageCommonEngineProtocol { state.commonEngine }
    var outcomes: [ProviderAccountUsageOutcome] { engine.outcomes }
    var usageProvider: UsageProvider? { state.usageProvider }
    var settings: UsageMonitorProviderSettings {
        get { engine.settings }
        set { engine.settings = newValue }
    }
    var isLoading: Bool { engine.isLoading }
    var accountLayoutMode: UsageAccountLayoutMode { engine.accountLayoutMode }
    var isShowingCopyToast: Bool { engine.isShowingCopyToast }
    var copyToastMessage: String? { engine.copyToastMessage }
    var alertTitle: String? {
        get { engine.alertTitle }
        set { engine.alertTitle = newValue }
    }
    var alertMessage: String? {
        get { engine.alertMessage }
        set { engine.alertMessage = newValue }
    }

    func load() async {
        await engine.load()
    }

    func loadIfNeeded() async -> Bool {
        await engine.loadIfNeeded()
    }

    func performAutoRefresh() async {
        await engine.performAutoRefresh()
    }

    func performScheduledRefreshTick(now: Date = Date()) async {
        await engine.performScheduledRefresh(now: now)
    }

    func scheduledRefreshPollInterval(now: Date = Date()) -> TimeInterval {
        engine.scheduledRefreshPollInterval(now: now)
    }

    func updateSettings(_ settings: UsageMonitorProviderSettings) {
        engine.updateSettings(settings)
    }

    func handleHeaderRefreshButtonTap() {
        engine.handleHeaderRefreshButtonTap()
    }

    func setAccountLayoutMode(_ mode: UsageAccountLayoutMode) {
        engine.setAccountLayoutMode(mode)
    }

    static func shouldUseCompactUnifiedListRows(
        layoutMode: UsageAccountLayoutMode,
        accountCount: Int
    ) -> Bool {
        layoutMode == .list && accountCount > 0
    }

}

@MainActor
@Observable
final class ProviderTokenTrendViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    private var engine: any ProviderUsageCommonEngineProtocol { state.commonEngine }
    var tokenTrendRange: UsageEngineTokenTrendRange { engine.tokenTrendRange }
    var tokenTrendSnapshot: ProviderTokenTrendSnapshot? { engine.tokenTrendSnapshot }
    var tokenTrendErrorMessage: String? { engine.tokenTrendErrorMessage }
    var isLoadingTokenTrend: Bool { engine.isLoadingTokenTrend }
    var shouldShowLoadingSkeleton: Bool { engine.shouldShowTokenTrendLoadingSkeleton }

    func setRange(_ range: UsageEngineTokenTrendRange) {
        engine.setTokenTrendRange(range)
    }

    func refreshNow() {
        engine.refreshTokenTrendNow()
    }
}

@MainActor
@Observable
final class ProviderUsageCodexImportSheetViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var sections: [CodexImportCandidateSection] {
        state.codexEngine.codexImportCandidateSections
    }

    var hasAnyCandidates: Bool { state.codexEngine.hasCodexImportCandidates }
    var canImport: Bool { state.codexEngine.canImportSelectedCodexCandidates }
    var isRunningValidation: Bool { state.codexEngine.isRunningCodexImportValidation }
    var isRunningConnectionTests: Bool { state.codexEngine.isRunningCodexImportConnectionTests }
    var isTargetingDropZone: Bool {
        get { state.codexEngine.isTargetingCodexImportDropZone }
        set { state.codexEngine.isTargetingCodexImportDropZone = newValue }
    }
    var searchText: String {
        get { state.codexEngine.codexImportSearchText }
        set { state.codexEngine.codexImportSearchText = newValue }
    }
    var globalErrorMessage: String? { state.codexEngine.codexImportGlobalErrorMessage }
    var importDestinationOption: CodexImportDestinationOption {
        get { state.codexEngine.codexImportDestinationOption }
        set { state.codexEngine.codexImportDestinationOption = newValue }
    }
    var customSQLiteGroupName: String {
        get { state.codexEngine.codexImportCustomGroupName }
        set { state.codexEngine.codexImportCustomGroupName = newValue }
    }

    func pickFiles() {
        Task { await state.codexEngine.presentCodexImportFilePicker() }
    }

    func pasteFromClipboard() {
        Task { await state.codexEngine.pasteCodexImportFromClipboard() }
    }

    func handleDropFiles(_ urls: [URL]) {
        Task { await state.codexEngine.handleCodexImportURLs(urls) }
    }

    func setCandidateSelected(_ selected: Bool, id: UUID) {
        state.codexEngine.setCodexImportCandidateSelected(selected, id: id)
    }

    func setGroupSelected(_ selected: Bool, sourceGroupID: String) {
        state.codexEngine.setCodexImportCandidatesSelected(selected, sourceGroupID: sourceGroupID)
    }

    func selectAll() {
        state.codexEngine.setAllCodexImportCandidatesSelected(true)
    }

    func deselectAll() {
        state.codexEngine.setAllCodexImportCandidatesSelected(false)
    }

    func retryConnectionTest(id: UUID) {
        Task { await state.codexEngine.retryCodexImportConnectionTest(id: id) }
    }

    func retryAllConnectionTests() {
        Task { await state.codexEngine.retryAllCodexImportConnectionTests() }
    }

    func removeCandidate(id: UUID) {
        state.codexEngine.removeCodexImportCandidate(id: id)
    }

    func exportSelectedAsZIP() {
        Task { await state.codexEngine.exportSelectedCodexImportCandidatesAsZIP() }
    }

    func applySelectedImports() {
        Task { await state.codexEngine.applySelectedCodexImports() }
    }
}

@MainActor
@Observable
final class CodexImportExportViewModel {
    private let state: ProviderUsageStateStore
    let sheetViewModel: ProviderUsageCodexImportSheetViewModel

    init(state: ProviderUsageStateStore) {
        self.state = state
        self.sheetViewModel = ProviderUsageCodexImportSheetViewModel(state: state)
    }

    var isShowingCodexImportSheet: Bool {
        get { state.codexEngine.isShowingCodexImportSheet }
        set { state.codexEngine.isShowingCodexImportSheet = newValue }
    }
    var isShowingCodexImportSheetBinding: Binding<Bool> {
        Binding(
            get: { self.isShowingCodexImportSheet },
            set: { self.isShowingCodexImportSheet = $0 }
        )
    }

    func dismissCodexImportSheet() {
        state.codexEngine.dismissCodexImportSheet()
    }
}

@MainActor
@Observable
final class ProviderLoginFlowViewModel {
    private let state: ProviderUsageStateStore
    private var engine: any ProviderUsageCommonEngineProtocol { state.commonEngine }

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var isRunningCLILogin: Bool { engine.isRunningCLILogin }
    var isShowingLogin: Bool {
        get { engine.isShowingLogin }
        set { engine.isShowingLogin = newValue }
    }
    var isShowingLoginBinding: Binding<Bool> {
        Binding(
            get: { self.isShowingLogin },
            set: { self.isShowingLogin = $0 }
        )
    }
    var dashboardURL: URL? { engine.dashboardURL }
    var loginModeForSheet: String? { engine.loginModeForSheet }
    var isShowingLoginURLSheet: Bool {
        get { engine.isShowingLoginURLSheet }
        set { engine.isShowingLoginURLSheet = newValue }
    }
    var isShowingLoginURLSheetBinding: Binding<Bool> {
        Binding(
            get: { self.isShowingLoginURLSheet },
            set: { self.isShowingLoginURLSheet = $0 }
        )
    }
    var loginURLForSheet: URL? { engine.loginURLForSheet }

    func startLoginFlow() {
        engine.startLoginFlow()
    }

    func cancelCLILoginIfNeeded() {
        engine.cancelCLILoginIfNeeded()
    }

    func handleLoginURLSheetDismissed() {
        engine.handleLoginURLSheetDismissed()
    }

    func copyLoginURL() {
        engine.copyLoginURL()
    }

    func reopenLoginURLInBrowser() {
        engine.reopenLoginURLInBrowser()
    }
}

@MainActor
@Observable
final class CodexGatewayCardsViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var gatewayCards: [CodexGatewayCard] { state.codexEngine.gatewayCards }
    var gatewayCardsState: CodexGatewayCardsState { state.codexEngine.gatewayCardsState }
    var isGatewayCardsSectionCollapsed: Bool { state.codexEngine.isGatewayCardsSectionCollapsed }
    var hasActiveGatewayCardSelection: Bool { state.codexEngine.hasActiveGatewayCardSelection }
    var pendingGatewaySelectionAccountIDs: [UUID] { state.codexEngine.pendingGatewaySelectionAccountIDs }

    func clearActiveGatewayCardSelection() {
        state.codexEngine.clearActiveGatewayCardSelection()
    }

    func toggleGatewayCardsSectionCollapsed() {
        state.codexEngine.toggleGatewayCardsSectionCollapsed()
    }

    func activateGatewayCard(cardID: UUID) -> Bool {
        state.codexEngine.activateGatewayCard(cardID: cardID)
    }

    func startGatewayForCardSelection(cardID: UUID) async {
        await state.codexEngine.startGatewayForCardSelection(cardID: cardID)
    }

    func renameGatewayCard(cardID: UUID, name: String) {
        state.codexEngine.renameGatewayCard(cardID: cardID, name: name)
    }

    func deleteGatewayCard(cardID: UUID) {
        state.codexEngine.deleteGatewayCard(cardID: cardID)
    }

    func confirmAddPendingAccounts(to cardID: UUID) {
        state.codexEngine.confirmAddPendingAccounts(to: cardID)
    }

    func dismissGatewayCardPicker() {
        state.codexEngine.dismissGatewayCardPicker()
    }

    func gatewayCandidateAccounts(for cardID: UUID) -> [CodexAuthAccount] {
        state.codexEngine.gatewayCandidateAccounts(for: cardID)
    }

    func gatewayCandidateSections(for cardID: UUID) -> [CodexGatewayCandidateSection] {
        state.codexEngine.gatewayCandidateSections(for: cardID)
    }

    func addAccountsToGatewayCard(accountIDs: [UUID], cardID: UUID) {
        state.codexEngine.addAccountsToGatewayCard(accountIDs: accountIDs, cardID: cardID)
    }

    @discardableResult
    func createGatewayCard(name: String) -> CodexGatewayCard? {
        state.codexEngine.createGatewayCard(name: name)
    }
}
