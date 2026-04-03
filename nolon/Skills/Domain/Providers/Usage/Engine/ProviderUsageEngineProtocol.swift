import Foundation
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
protocol ProviderUsageCommonEngineProtocol: AnyObject {
    var outcomes: [ProviderAccountUsageOutcome] { get set }
    var settings: UsageMonitorProviderSettings { get set }
    var isLoading: Bool { get set }
    var isShowingCopyToast: Bool { get set }
    var copyToastMessage: String { get set }
    var alertTitle: String? { get set }
    var alertMessage: String? { get set }
    var tokenTrendRange: UsageEngineTokenTrendRange { get set }
    var tokenTrendSnapshot: ProviderTokenTrendSnapshot? { get set }
    var tokenTrendErrorMessage: String? { get set }
    var isLoadingTokenTrend: Bool { get set }
    var shouldShowTokenTrendLoadingSkeleton: Bool { get }
    var accountLayoutMode: UsageAccountLayoutMode { get set }
    var isRunningCLILogin: Bool { get set }
    var isShowingLogin: Bool { get set }
    var dashboardURL: URL? { get }
    var loginModeForSheet: String? { get set }
    var isShowingLoginURLSheet: Bool { get set }
    var loginURLForSheet: URL? { get set }

    func load() async
    func loadIfNeeded() async -> Bool
    func performAutoRefresh() async
    func performScheduledRefresh(now: Date) async
    func scheduledRefreshPollInterval(now: Date) -> TimeInterval
    func updateSettings(_ settings: UsageMonitorProviderSettings)
    func handleHeaderRefreshButtonTap()
    func setTokenTrendRange(_ range: UsageEngineTokenTrendRange)
    func refreshTokenTrendNow()
    func setAccountLayoutMode(_ mode: UsageAccountLayoutMode)
    func startLoginFlow()
    func cancelCLILoginIfNeeded()
    func handleLoginURLSheetDismissed()
    func copyLoginURL()
    func reopenLoginURLInBrowser()
}

@MainActor
protocol ProviderUsageCodexEngineProtocol: AnyObject {
    var codexAccounts: [CodexAuthAccount] { get set }
    var codexAccountOutcomes: [ProviderAccountUsageOutcome] { get set }
    var codexAccountSummaries: [UUID: CodexAuthSummary] { get set }
    var codexAccountCreditsRefreshedAt: [UUID: Date] { get set }
    var codexAccountDisplaySections: [CodexAccountDisplaySection] { get }
    var codexAccountSectionTotalCountByID: [String: Int] { get }
    var codexPrimaryHeaderActions: [CodexPrimaryHeaderAction] { get }
    var codexSortMenuOptions: [CodexAccountSortOption] { get }
    var codexAuthFilePath: String? { get set }
    var activeCodexAccountId: UUID? { get set }
    var codexRefreshingAccountIds: Set<UUID> { get set }
    var isCodexMultiSelectionEnabled: Bool { get set }
    var selectedCodexAccountIDs: Set<UUID> { get set }
    var codexSelectedAccountCount: Int { get }
    var pendingActivateCodexAccount: CodexAuthAccount? { get set }
    var codexManagementStatus: CodexAuthManager.CodexManagementStatus? { get set }
    var codexConfigEditorDraft: CodexConfigEditorDraft? { get set }
    var codexConfigEditorModelProviderOptions: [String] { get set }
    var codexConfigEditorErrorMessage: String? { get set }
    var codexUsageQueryTestSuccessMessage: String? { get set }
    var codexUsageQueryTestErrorMessage: String? { get set }
    var isTestingCodexUsageQuery: Bool { get set }
    var isShowingCodexConfigEditor: Bool { get set }
    var codexHideZeroQuotaAccounts: Bool { get set }
    var codexHideErroredAccounts: Bool { get set }
    var hasActiveCodexAccountFilters: Bool { get }
    var codexAccountGroupingOption: CodexAccountGroupingOption { get set }
    var codexAccountSortOption: CodexAccountSortOption { get set }
    var collapsedCodexSectionIDs: Set<String> { get set }
    var isCodexHeaderRefreshing: Bool { get set }
    var canExportSelectedCodexAccounts: Bool { get }
    var canAddSelectedToGatewayCard: Bool { get }
    var isShowingActivateConfirm: Bool { get set }
    var isShowingDeleteConfirm: Bool { get set }
    var pendingDeleteCodexAccount: CodexAuthAccount? { get set }
    var isShowingGatewayCardPicker: Bool { get set }
    var cliLoginPreferredAccountId: UUID? { get set }
    var codexImportCandidateSections: [CodexImportCandidateSection] { get }
    var hasCodexImportCandidates: Bool { get }
    var canImportSelectedCodexCandidates: Bool { get }
    var isRunningCodexImportValidation: Bool { get set }
    var isRunningCodexImportConnectionTests: Bool { get set }
    var isTargetingCodexImportDropZone: Bool { get set }
    var codexImportSearchText: String { get set }
    var codexImportGlobalErrorMessage: String? { get set }
    var codexImportDestinationOption: CodexImportDestinationOption { get set }
    var codexImportCustomGroupName: String { get set }
    var isShowingCodexImportSheet: Bool { get set }
    var gatewayCards: [CodexGatewayCard] { get }
    var gatewayCardsState: CodexGatewayCardsState { get set }
    var isGatewayCardsSectionCollapsed: Bool { get set }
    var hasActiveGatewayCardSelection: Bool { get }
    var pendingGatewaySelectionAccountIDs: [UUID] { get set }

    func selectedCodexAccountIDsInDisplayOrder() -> [UUID]
    func requestActivateCodexAccount(id: UUID)
    func confirmActivate() async
    func requestDeleteCodexAccount(id: UUID)
    func confirmDeleteCodexAccount() async
    func refreshCodexAccountImmediately(id: UUID) async
    func isCodexAccountSelected(id: UUID?) -> Bool
    func shouldActivateCodexAccountOnTap(id: UUID, hasActiveGatewayCardSelection: Bool) -> Bool
    func setCodexMultiSelectionEnabled(_ enabled: Bool)
    func isActiveCodexAccount(_ account: CodexAuthAccount) -> Bool
    func codexAccountSupportsLogin(accountID: UUID?) -> Bool
    func requestLoginForCodexAccount(id: UUID)
    func refreshCodexAccount(id: UUID)
    func activateCodexAccountImmediately(id: UUID) async
    func exportSelectedCodexAccountsAsZIP() async
    func beginEditActiveCodexConfiguredAccount()
    func validateActiveCodexConfiguredAccount()
    func codexAccountSupportsEditing(accountID: UUID?) -> Bool
    func testCodexUsageQueryDraft() async
    func validateCodexConnectionDraft() async
    func dismissCodexConfigEditor()
    func saveCodexConfigEditor() async
    func beginNewCodexAPIKeyAccount()
    func selectCodexSortOption(_ option: CodexAccountSortOption)
    func toggleCodexSection(_ sectionID: String)
    func toggleCodexSectionSelection(_ section: CodexAccountDisplaySection)
    func setCodexHideZeroQuotaAccounts(_ hidden: Bool)
    func setCodexHideErroredAccounts(_ hidden: Bool)
    func setCodexAccountGroupingOption(_ option: CodexAccountGroupingOption)
    func enableCodexManagement() async
    func migrateCodexManagementData() async
    func revealCodexAccountInFinder(id: UUID)
    func copyCodexAccountAuthJSON(id: UUID)
    func editCodexAccountAuthJSON(id: UUID)
    func isCodexSectionCollapsed(_ sectionID: String) -> Bool
    func isCodexSectionFullySelected(_ section: CodexAccountDisplaySection) -> Bool
    func codexDirection(for option: CodexAccountSortOption) -> CodexSortDirection
    func addSelectedToGatewayCard()
    func beginImportAuthFiles()
    func copyErrorText(_ text: String)
    func gatewayMembers(for card: CodexGatewayCard) -> [CodexGatewayMemberDisplay]
    func presentCodexImportFilePicker() async
    func pasteCodexImportFromClipboard() async
    func handleCodexImportURLs(_ urls: [URL]) async
    func setCodexImportCandidateSelected(_ selected: Bool, id: UUID)
    func setCodexImportCandidatesSelected(_ selected: Bool, sourceGroupID: String)
    func setAllCodexImportCandidatesSelected(_ selected: Bool)
    func retryCodexImportConnectionTest(id: UUID) async
    func retryAllCodexImportConnectionTests() async
    func removeCodexImportCandidate(id: UUID)
    func exportSelectedCodexImportCandidatesAsZIP() async
    func applySelectedCodexImports() async
    func dismissCodexImportSheet()
    func clearActiveGatewayCardSelection()
    func toggleGatewayCardsSectionCollapsed()
    func activateGatewayCard(cardID: UUID) -> Bool
    func startGatewayForCardSelection(cardID: UUID) async
    func renameGatewayCard(cardID: UUID, name: String)
    func deleteGatewayCard(cardID: UUID)
    func confirmAddPendingAccounts(to cardID: UUID)
    func dismissGatewayCardPicker()
    func gatewayCandidateAccounts(for cardID: UUID) -> [CodexAuthAccount]
    func gatewayCandidateSections(for cardID: UUID) -> [CodexGatewayCandidateSection]
    func addAccountsToGatewayCard(accountIDs: [UUID], cardID: UUID)
    func createGatewayCard(name: String) -> CodexGatewayCard?
}

@MainActor
protocol ProviderUsageClaudeEngineProtocol: AnyObject {
    var claudeAccounts: [ClaudeAccount] { get set }
    var activeClaudeAccountId: UUID? { get set }

    func migrateClaudeFromCurrentSettings() async
    func importClaudeFromCCSwitch() async
    func activateClaudeAccount(id: UUID) async
    func createClaudeAccount(_ account: ClaudeAccount) async throws
    func updateClaudeAccount(_ account: ClaudeAccount) async throws
    func isActiveClaudeAccount(_ account: ClaudeAccount) -> Bool
}

@MainActor
protocol ProviderUsageGeminiEngineProtocol: AnyObject {
    var geminiAccounts: [GeminiAuthAccount] { get set }
    var activeGeminiAccountId: UUID? { get set }
    var shouldShowGeminiImportAction: Bool { get }
    var isShowingGeminiImportConfirm: Bool { get set }
    var pendingGeminiImportCandidate: GeminiCLIGlobalSessionImportCandidate? { get set }

    func activateGeminiAccount(id: UUID) async
    func deleteGeminiAccount(id: UUID) async
    func presentGeminiImportConfirmation()
    func continueGeminiOAuthLoginWithoutImport()
    func importGeminiGlobalSessionAfterConfirmation() async
    func isActiveGeminiAccount(_ account: GeminiAuthAccount) -> Bool
}

extension ProviderUsageEngine:
    ProviderUsageCommonEngineProtocol,
    ProviderUsageCodexEngineProtocol,
    ProviderUsageClaudeEngineProtocol,
    ProviderUsageGeminiEngineProtocol {}
