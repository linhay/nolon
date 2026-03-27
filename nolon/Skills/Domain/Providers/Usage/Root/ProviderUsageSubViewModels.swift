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

        static let autoSwitchThresholdOptions: [Double] = [5, 10, 15, 20, 30]
        static let autoSwitchCandidateOptions: [Double] = [10, 20, 30, 40, 50]
        static let listPlanColumnWidth: CGFloat = 96
        static let listUsageColumnWidth: CGFloat = 232

        fileprivate let state: ProviderUsageStateStore

        init(state: ProviderUsageStateStore) {
            self.state = state
        }

        private var engine: ProviderUsageEngine { state.engine }

        var accounts: [CodexAuthAccount] { engine.codexAccounts }
        var accountOutcomes: [ProviderAccountUsageOutcome] { engine.codexAccountOutcomes }
        var autoSwitchThresholdOptions: [Double] { Self.autoSwitchThresholdOptions }
        var autoSwitchCandidateOptions: [Double] { Self.autoSwitchCandidateOptions }
        var listPlanColumnWidth: CGFloat { Self.listPlanColumnWidth }
        var listUsageColumnWidth: CGFloat { Self.listUsageColumnWidth }
        var accountSummaries: [UUID: CodexAuthSummary] { engine.codexAccountSummaries }
        var accountCreditsRefreshedAt: [UUID: Date] { engine.codexAccountCreditsRefreshedAt }
        var accountDisplaySections: [ProviderUsageEngine.CodexAccountDisplaySection] { engine.codexAccountDisplaySections }
        var accountSectionTotalCountByID: [String: Int] { engine.codexAccountSectionTotalCountByID }
        var primaryHeaderActions: [ProviderUsageEngine.CodexPrimaryHeaderAction] { engine.codexPrimaryHeaderActions }
        var sortMenuOptions: [ProviderUsageEngine.CodexAccountSortOption] { engine.codexSortMenuOptions }
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
            engine.selectedCodexAccountIDsInCurrentDisplayOrder()
        }
        var selectedAccountCount: Int { engine.codexSelectedAccountCount }
        var pendingActivateAccount: CodexAuthAccount? {
            get { engine.pendingActivateCodexAccount }
            set { engine.pendingActivateCodexAccount = newValue }
        }
        var managementStatus: CodexAuthManager.CodexManagementStatus? { engine.codexManagementStatus }
        var configEditorDraft: ProviderUsageEngine.CodexConfigEditorDraft? {
            get { engine.codexConfigEditorDraft }
            set { engine.codexConfigEditorDraft = newValue }
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
        var autoSwitchConfig: CodexAutoSwitchConfig { engine.codexAutoSwitchConfig }
        var accountGroupingOption: ProviderUsageEngine.CodexAccountGroupingOption {
            get { engine.codexAccountGroupingOption }
            set { engine.codexAccountGroupingOption = newValue }
        }
        var accountSortOption: ProviderUsageEngine.CodexAccountSortOption {
            get { engine.codexAccountSortOption }
            set { engine.codexAccountSortOption = newValue }
        }
        var accountLayoutMode: ProviderUsageEngine.CodexAccountLayoutMode { engine.codexAccountLayoutMode }
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
            from actions: [ProviderUsageEngine.CodexPrimaryHeaderAction],
            isMultiSelectionEnabled: Bool
        ) -> [ProviderUsageEngine.CodexPrimaryHeaderAction] {
            guard !isMultiSelectionEnabled else { return [] }
            return Array(actions.prefix(2))
        }

        func visiblePrimaryHeaderActions() -> [ProviderUsageEngine.CodexPrimaryHeaderAction] {
            Self.visiblePrimaryHeaderActions(
                from: primaryHeaderActions,
                isMultiSelectionEnabled: isMultiSelectionEnabled
            )
        }

        static func shouldShowActivateAccountContextAction(isActiveAccount: Bool) -> Bool {
            !isActiveAccount
        }

        static func shouldShowActivateGatewayContextAction(isActiveGateway: Bool) -> Bool {
            !isActiveGateway
        }

        func shouldShowActivateAccountContextAction(isActiveAccount: Bool) -> Bool {
            Self.shouldShowActivateAccountContextAction(isActiveAccount: isActiveAccount)
        }

        func shouldShowActivateGatewayContextAction(isActiveGateway: Bool) -> Bool {
            Self.shouldShowActivateGatewayContextAction(isActiveGateway: isActiveGateway)
        }

        static func usesCompactListRows(layoutMode: ProviderUsageEngine.CodexAccountLayoutMode) -> Bool {
            layoutMode == .list
        }

        static func enablesTextSelection(layoutMode: ProviderUsageEngine.CodexAccountLayoutMode) -> Bool {
            !usesCompactListRows(layoutMode: layoutMode)
        }

        static func gatewayMemberDisplayLimit(layoutMode: ProviderUsageEngine.CodexAccountLayoutMode) -> Int {
            usesCompactListRows(layoutMode: layoutMode) ? 8 : 12
        }

        static func gatewayMemberRowMaxHeight(layoutMode: ProviderUsageEngine.CodexAccountLayoutMode) -> CGFloat {
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

        func toggleAccountSelection(id: UUID) {
            engine.toggleCodexAccountSelection(id: id)
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

        func exportSelectedAccountsAsSub2API() async {
            await engine.exportSelectedCodexAccountsAsSub2API()
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

        func dismissConfigEditor() {
            engine.dismissCodexConfigEditor()
        }

        func saveConfigEditor() async {
            await engine.saveCodexConfigEditor()
        }

        func beginNewRelayAccount() {
            engine.beginNewCodexRelayAccount()
        }

        func beginNewAPIKeyAccount() {
            engine.beginNewCodexAPIKeyAccount()
        }

        func selectSortOption(_ option: ProviderUsageEngine.CodexAccountSortOption) {
            engine.selectCodexSortOption(option)
        }

        func toggleSection(_ sectionID: String) {
            engine.toggleCodexSection(sectionID)
        }

        func toggleSectionSelection(_ sectionID: String) {
            guard let section = engine.codexAccountDisplaySections.first(where: { $0.id == sectionID }) else { return }
            engine.toggleCodexSectionSelection(section)
        }

        func toggleSectionSelection(_ section: ProviderUsageEngine.CodexAccountDisplaySection) {
            engine.toggleCodexSectionSelection(section)
        }

        func toggleMultiSelectionMode() {
            engine.toggleCodexMultiSelectionMode()
        }

        func setHideZeroQuotaAccounts(_ hidden: Bool) {
            engine.setCodexHideZeroQuotaAccounts(hidden)
        }

        func setHideErroredAccounts(_ hidden: Bool) {
            engine.setCodexHideErroredAccounts(hidden)
        }

        func setAutoSwitchEnabled(_ enabled: Bool) {
            engine.setCodexAutoSwitchEnabled(enabled)
        }

        func setAutoSwitchThresholdPercent(_ percent: Int) {
            engine.setCodexAutoSwitchThresholdPercent(percent)
        }

        func setAutoSwitchMinimumCandidateRemainingPercent(_ percent: Int) {
            engine.setCodexAutoSwitchMinimumCandidateRemainingPercent(percent)
        }

        func setAutoSwitchSkipRelay(_ skipRelay: Bool) {
            engine.setCodexAutoSwitchSkipRelay(skipRelay)
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

        func setAccountLayoutMode(_ mode: ProviderUsageEngine.CodexAccountLayoutMode) {
            engine.setCodexAccountLayoutMode(mode)
        }

        func isSectionCollapsed(_ sectionID: String) -> Bool {
            engine.isCodexSectionCollapsed(sectionID)
        }

        func isSectionFullySelected(_ section: ProviderUsageEngine.CodexAccountDisplaySection) -> Bool {
            engine.isCodexSectionFullySelected(section)
        }

        func direction(for option: ProviderUsageEngine.CodexAccountSortOption) -> ProviderUsageEngine.CodexSortDirection? {
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

        func gatewayMembers(for card: CodexGatewayCard) -> [ProviderUsageEngine.CodexGatewayMemberDisplay] {
            engine.gatewayMembers(for: card)
        }
    }

    @MainActor
    final class ClaudeState {
        fileprivate let state: ProviderUsageStateStore

        init(state: ProviderUsageStateStore) {
            self.state = state
        }

        private var engine: ProviderUsageEngine { state.engine }

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

        private var engine: ProviderUsageEngine { state.engine }

        var accounts: [GeminiAuthAccount] { engine.geminiAccounts }
        var shouldShowImportAction: Bool { engine.shouldShowGeminiImportAction }
        var isShowingImportConfirm: Bool {
            get { engine.isShowingGeminiImportConfirm }
            set { engine.isShowingGeminiImportConfirm = newValue }
        }
        var pendingImportCandidate: GeminiCLIGlobalSessionImportCandidate? { engine.pendingGeminiImportCandidate }
        
        static func shouldUseFullWidthCardLayout(accountCount: Int) -> Bool {
            accountCount == 1
        }

        func shouldUseFullWidthCardLayout(accountCount: Int) -> Bool {
            Self.shouldUseFullWidthCardLayout(accountCount: accountCount)
        }

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

    private var engine: ProviderUsageEngine { state.engine }
    var outcomes: [ProviderAccountUsageOutcome] { state.engine.outcomes }
    var usageProvider: UsageProvider? { state.engine.usageProvider }
    var settings: UsageMonitorProviderSettings {
        get { state.engine.settings }
        set { state.engine.settings = newValue }
    }
    var isLoading: Bool { state.engine.isLoading }
    var accountLayoutMode: ProviderUsageEngine.CodexAccountLayoutMode { state.engine.codexAccountLayoutMode }
    var isShowingCopyToast: Bool { state.engine.isShowingCopyToast }
    var copyToastMessage: String? { state.engine.copyToastMessage }
    var alertTitle: String? {
        get { state.engine.alertTitle }
        set { state.engine.alertTitle = newValue }
    }
    var alertMessage: String? {
        get { state.engine.alertMessage }
        set { state.engine.alertMessage = newValue }
    }

    func load() async {
        await state.engine.load()
    }

    func loadIfNeeded() async -> Bool {
        await state.engine.loadIfNeeded()
    }

    func performAutoRefresh() async {
        await engine.performAutoRefresh()
    }

    func updateSettings(_ settings: UsageMonitorProviderSettings) {
        engine.updateSettings(settings)
    }

    func handleHeaderRefreshButtonTap() {
        engine.handleHeaderRefreshButtonTap()
    }

    func setAccountLayoutMode(_ mode: ProviderUsageEngine.CodexAccountLayoutMode) {
        engine.setCodexAccountLayoutMode(mode)
    }

    static func shouldUseCompactUnifiedListRows(
        layoutMode: ProviderUsageEngine.CodexAccountLayoutMode,
        accountCount: Int
    ) -> Bool {
        layoutMode == .list && accountCount > 0
    }

    func shouldUseCompactUnifiedListRows(accountCount: Int) -> Bool {
        Self.shouldUseCompactUnifiedListRows(
            layoutMode: accountLayoutMode,
            accountCount: accountCount
        )
    }

}

@MainActor
@Observable
final class ProviderTokenTrendViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var tokenTrendRange: ProviderUsageEngine.TokenTrendRange { state.engine.tokenTrendRange }
    var tokenTrendSnapshot: ProviderTokenTrendSnapshot? { state.engine.tokenTrendSnapshot }
    var tokenTrendErrorMessage: String? { state.engine.tokenTrendErrorMessage }
    var isLoadingTokenTrend: Bool { state.engine.isLoadingTokenTrend }
    var shouldShowLoadingSkeleton: Bool { state.engine.shouldShowTokenTrendLoadingSkeleton }

    func setRange(_ range: ProviderUsageEngine.TokenTrendRange) {
        state.engine.setTokenTrendRange(range)
    }

    func refreshNow() {
        state.engine.refreshTokenTrendNow()
    }
}

@MainActor
@Observable
final class ProviderUsageCodexImportSheetViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var sections: [ProviderUsageEngine.CodexImportCandidateSection] {
        state.engine.codexImportCandidateSections
    }

    var hasAnyCandidates: Bool { state.engine.hasCodexImportCandidates }
    var isRunningValidation: Bool { state.engine.isRunningCodexImportValidation }
    var isRunningConnectionTests: Bool { state.engine.isRunningCodexImportConnectionTests }
    var isTargetingDropZone: Bool {
        get { state.engine.isTargetingCodexImportDropZone }
        set { state.engine.isTargetingCodexImportDropZone = newValue }
    }
    var searchText: String {
        get { state.engine.codexImportSearchText }
        set { state.engine.codexImportSearchText = newValue }
    }
    var globalErrorMessage: String? { state.engine.codexImportGlobalErrorMessage }

    func pickFiles() {
        Task { await state.engine.presentCodexImportFilePicker() }
    }

    func pasteFromClipboard() {
        Task { await state.engine.pasteCodexImportFromClipboard() }
    }

    func handleDropFiles(_ urls: [URL]) {
        Task { await state.engine.handleCodexImportURLs(urls) }
    }

    func setCandidateSelected(_ selected: Bool, id: UUID) {
        state.engine.setCodexImportCandidateSelected(selected, id: id)
    }

    func setGroupSelected(_ selected: Bool, sourceGroupID: String) {
        state.engine.setCodexImportCandidatesSelected(selected, sourceGroupID: sourceGroupID)
    }

    func selectAll() {
        state.engine.setAllCodexImportCandidatesSelected(true)
    }

    func deselectAll() {
        state.engine.setAllCodexImportCandidatesSelected(false)
    }

    func retryConnectionTest(id: UUID) {
        Task { await state.engine.retryCodexImportConnectionTest(id: id) }
    }

    func retryAllConnectionTests() {
        Task { await state.engine.retryAllCodexImportConnectionTests() }
    }

    func removeCandidate(id: UUID) {
        state.engine.removeCodexImportCandidate(id: id)
    }

    func exportSelectedAsZIP() {
        Task { await state.engine.exportSelectedCodexImportCandidatesAsZIP() }
    }

    func exportSelectedAsSub2API() {
        Task { await state.engine.exportSelectedCodexImportCandidatesAsSub2API() }
    }

    func applySelectedImports() {
        Task { await state.engine.applySelectedCodexImports() }
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
        get { state.engine.isShowingCodexImportSheet }
        set { state.engine.isShowingCodexImportSheet = newValue }
    }
    var isShowingCodexImportSheetBinding: Binding<Bool> {
        Binding(
            get: { self.isShowingCodexImportSheet },
            set: { self.isShowingCodexImportSheet = $0 }
        )
    }

    func dismissCodexImportSheet() {
        state.engine.dismissCodexImportSheet()
    }
}

@MainActor
@Observable
final class ProviderLoginFlowViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var isRunningCLILogin: Bool { state.engine.isRunningCLILogin }
    var isShowingLogin: Bool {
        get { state.engine.isShowingLogin }
        set { state.engine.isShowingLogin = newValue }
    }
    var isShowingLoginBinding: Binding<Bool> {
        Binding(
            get: { self.isShowingLogin },
            set: { self.isShowingLogin = $0 }
        )
    }
    var dashboardURL: URL? { state.engine.dashboardURL }
    var loginModeForSheet: String? { state.engine.loginModeForSheet }
    var isShowingLoginURLSheet: Bool {
        get { state.engine.isShowingLoginURLSheet }
        set { state.engine.isShowingLoginURLSheet = newValue }
    }
    var isShowingLoginURLSheetBinding: Binding<Bool> {
        Binding(
            get: { self.isShowingLoginURLSheet },
            set: { self.isShowingLoginURLSheet = $0 }
        )
    }
    var loginURLForSheet: URL? { state.engine.loginURLForSheet }

    func startLoginFlow() {
        state.engine.startLoginFlow()
    }

    func cancelCLILoginIfNeeded() {
        state.engine.cancelCLILoginIfNeeded()
    }

    func handleLoginURLSheetDismissed() {
        state.engine.handleLoginURLSheetDismissed()
    }

    func copyLoginURL() {
        state.engine.copyLoginURL()
    }

    func reopenLoginURLInBrowser() {
        state.engine.reopenLoginURLInBrowser()
    }
}

@MainActor
@Observable
final class CodexGatewayCardsViewModel {
    private let state: ProviderUsageStateStore

    init(state: ProviderUsageStateStore) {
        self.state = state
    }

    var gatewayCards: [CodexGatewayCard] { state.engine.gatewayCards }
    var gatewayCardsState: CodexGatewayCardsState { state.engine.gatewayCardsState }
    var isGatewayCardsSectionCollapsed: Bool { state.engine.isGatewayCardsSectionCollapsed }
    var hasActiveGatewayCardSelection: Bool { state.engine.hasActiveGatewayCardSelection }
    var pendingGatewaySelectionAccountIDs: [UUID] { state.engine.pendingGatewaySelectionAccountIDs }

    func clearActiveGatewayCardSelection() {
        state.engine.clearActiveGatewayCardSelection()
    }

    func toggleGatewayCardsSectionCollapsed() {
        state.engine.toggleGatewayCardsSectionCollapsed()
    }

    func activateGatewayCard(cardID: UUID) -> Bool {
        state.engine.activateGatewayCard(cardID: cardID)
    }

    func startGatewayForCardSelection(cardID: UUID) async {
        await state.engine.startGatewayForCardSelection(cardID: cardID)
    }

    func renameGatewayCard(cardID: UUID, name: String) {
        state.engine.renameGatewayCard(cardID: cardID, name: name)
    }

    func deleteGatewayCard(cardID: UUID) {
        state.engine.deleteGatewayCard(cardID: cardID)
    }

    func confirmAddPendingAccounts(to cardID: UUID) {
        state.engine.confirmAddPendingAccounts(to: cardID)
    }

    func dismissGatewayCardPicker() {
        state.engine.dismissGatewayCardPicker()
    }

    func gatewayCandidateAccounts(for cardID: UUID) -> [CodexAuthAccount] {
        state.engine.gatewayCandidateAccounts(for: cardID)
    }

    func gatewayCandidateSections(for cardID: UUID) -> [ProviderUsageEngine.CodexGatewayCandidateSection] {
        state.engine.gatewayCandidateSections(for: cardID)
    }

    func addAccountsToGatewayCard(accountIDs: [UUID], cardID: UUID) {
        state.engine.addAccountsToGatewayCard(accountIDs: accountIDs, cardID: cardID)
    }

    @discardableResult
    func createGatewayCard(name: String) -> CodexGatewayCard? {
        state.engine.createGatewayCard(name: name)
    }
}
