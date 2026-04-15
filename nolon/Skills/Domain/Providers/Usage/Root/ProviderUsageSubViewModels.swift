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
        var hasSelectedAccounts: Bool { engine.codexSelectedAccountCount > 0 }
        var selectedAccountIDsInDisplayOrder: [UUID] {
            engine.selectedCodexAccountIDsInDisplayOrder()
        }
        var selectedAccountCount: Int { engine.codexSelectedAccountCount }
        var pendingActivateAccount: CodexAuthAccount? {
            get { engine.pendingActivateCodexAccount }
            set { engine.pendingActivateCodexAccount = newValue }
        }
        var activatingAccountId: UUID? { engine.activatingCodexAccountId }
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
        var accountLayoutMode: UsageAccountLayoutMode { state.accountsEngine.accountLayoutMode }
        var usesCompactListRows: Bool { Self.usesCompactListRows(layoutMode: accountLayoutMode) }
        var enablesTextSelection: Bool { Self.enablesTextSelection(layoutMode: accountLayoutMode) }
        var collapsedSectionIDs: Set<String> { engine.collapsedCodexSectionIDs }
        var isHeaderRefreshing: Bool { engine.isCodexHeaderRefreshing }
        var canExportSelectedAccounts: Bool { engine.canExportSelectedCodexAccounts }
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

        static func usesCompactListRows(layoutMode: UsageAccountLayoutMode) -> Bool {
            layoutMode == .list
        }

        static func enablesTextSelection(layoutMode: UsageAccountLayoutMode) -> Bool {
            !usesCompactListRows(layoutMode: layoutMode)
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

        func interactionState(accountID: UUID?) -> CodexAccountInteractionState {
            engine.codexInteractionState(accountID: accountID)
        }

        func shouldActivateAccountOnTap(id: UUID) -> Bool {
            engine.shouldActivateCodexAccountOnTap(id: id)
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
            state.accountsEngine.setAccountLayoutMode(mode)
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

        func beginImportAuthFiles() {
            engine.beginImportAuthFiles()
        }

        func copyErrorText(_ text: String) {
            engine.copyErrorText(text)
        }

    }

    @MainActor
    @Observable
    final class ClaudeState {
        struct AccountEditorDraft: Equatable, Identifiable {
            enum Mode: Equatable {
                case create
                case edit
            }

            enum JSONSyncError: LocalizedError, Equatable {
                case rootMustBeObject
                case envMustBeObject
                case unsupportedTopLevelKeys([String])
                case unsupportedEnvKeys([String])
                case ambiguousCredential
                case invalidEnvValue(key: String)

                var errorDescription: String? {
                    switch self {
                    case .rootMustBeObject:
                        return NSLocalizedString(
                            "claude.accounts.editor.error.json_root_must_be_object",
                            value: "The JSON root must be an object containing the `env` fragment.",
                            comment: "Claude account editor json root must be object"
                        )
                    case .envMustBeObject:
                        return NSLocalizedString(
                            "claude.accounts.editor.error.json_env_must_be_object",
                            value: "`env` must be a JSON object.",
                            comment: "Claude account editor json env must be object"
                        )
                    case let .unsupportedTopLevelKeys(keys):
                        return NSLocalizedString(
                            "claude.accounts.editor.error.json_unsupported_top_level_prefix",
                            value: "Unsupported top-level keys: ",
                            comment: "Claude account editor unsupported top-level json keys prefix"
                        ) + keys.joined(separator: ", ") + "."
                    case let .unsupportedEnvKeys(keys):
                        return NSLocalizedString(
                            "claude.accounts.editor.error.json_unsupported_env_prefix",
                            value: "Unsupported env keys: ",
                            comment: "Claude account editor unsupported env json keys prefix"
                        ) + keys.joined(separator: ", ") + "."
                    case .ambiguousCredential:
                        return NSLocalizedString(
                            "claude.accounts.editor.error.json_ambiguous_credential",
                            value: "Use either `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_API_KEY`, not both.",
                            comment: "Claude account editor ambiguous credential json error"
                        )
                    case let .invalidEnvValue(key):
                        return "`\(key)` " + NSLocalizedString(
                            "claude.accounts.editor.error.json_invalid_env_value_suffix",
                            value: "must be a string or null.",
                            comment: "Claude account editor invalid env value suffix"
                        )
                    }
                }
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

            var id: UUID { accountID }

            var trimmedName: String {
                name.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedCredentialValue: String {
                credentialValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedBaseURL: String {
                baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedAnthropicModel: String {
                anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedAnthropicReasoningModel: String {
                anthropicReasoningModel.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedAnthropicDefaultHaikuModel: String {
                anthropicDefaultHaikuModel.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedAnthropicDefaultSonnetModel: String {
                anthropicDefaultSonnetModel.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var trimmedAnthropicDefaultOpusModel: String {
                anthropicDefaultOpusModel.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var hasRequiredFields: Bool {
                !trimmedCredentialValue.isEmpty &&
                !trimmedBaseURL.isEmpty
            }

            var settingsPreviewObject: [String: Any] {
                var env: [String: String] = [:]
                env["ANTHROPIC_BASE_URL"] = trimmedBaseURL

                switch credentialType {
                case .authToken:
                    env["ANTHROPIC_AUTH_TOKEN"] = trimmedCredentialValue
                case .apiKey:
                    env["ANTHROPIC_API_KEY"] = trimmedCredentialValue
                }

                Self.assign(trimmedAnthropicModel, for: "ANTHROPIC_MODEL", into: &env)
                Self.assign(trimmedAnthropicReasoningModel, for: "ANTHROPIC_REASONING_MODEL", into: &env)
                Self.assign(trimmedAnthropicDefaultHaikuModel, for: "ANTHROPIC_DEFAULT_HAIKU_MODEL", into: &env)
                Self.assign(trimmedAnthropicDefaultSonnetModel, for: "ANTHROPIC_DEFAULT_SONNET_MODEL", into: &env)
                Self.assign(trimmedAnthropicDefaultOpusModel, for: "ANTHROPIC_DEFAULT_OPUS_MODEL", into: &env)

                return ["env": env]
            }

            var settingsPreviewJSON: String {
                guard JSONSerialization.isValidJSONObject(settingsPreviewObject),
                      let data = try? JSONSerialization.data(
                        withJSONObject: settingsPreviewObject,
                        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                      ),
                      let output = String(data: data, encoding: .utf8)
                else {
                    return "{\n  \"env\" : {}\n}"
                }
                return output
            }

            func applyingSettingsPreviewJSON(_ text: String) throws -> Self {
                let data = Data(text.utf8)
                let object = try JSONSerialization.jsonObject(with: data)
                guard let root = object as? [String: Any] else {
                    throw JSONSyncError.rootMustBeObject
                }
                return try applyingSettingsPreviewObject(root)
            }

            func applyingSettingsPreviewObject(_ root: [String: Any]) throws -> Self {
                let unsupportedTopLevelKeys = Set(root.keys).subtracting(Self.supportedTopLevelKeys).sorted()
                guard unsupportedTopLevelKeys.isEmpty else {
                    throw JSONSyncError.unsupportedTopLevelKeys(unsupportedTopLevelKeys)
                }

                guard let envObject = root["env"] else {
                    return try applyingNormalizedEnv([:])
                }
                guard let env = envObject as? [String: Any] else {
                    throw JSONSyncError.envMustBeObject
                }
                return try applyingNormalizedEnv(env)
            }

            private func applyingNormalizedEnv(_ env: [String: Any]) throws -> Self {
                let unsupportedEnvKeys = Set(env.keys).subtracting(Self.supportedEnvKeys).sorted()
                guard unsupportedEnvKeys.isEmpty else {
                    throw JSONSyncError.unsupportedEnvKeys(unsupportedEnvKeys)
                }

                let authToken = try Self.optionalEnvString(Self.authTokenKey, from: env)
                let apiKey = try Self.optionalEnvString(Self.apiKeyKey, from: env)
                guard !(authToken != nil && apiKey != nil) else {
                    throw JSONSyncError.ambiguousCredential
                }

                var updated = self
                updated.baseURL = try Self.trimmedEnvString(Self.baseURLKey, from: env) ?? ""
                updated.anthropicModel = try Self.trimmedEnvString(Self.modelKey, from: env) ?? ""
                updated.anthropicReasoningModel = try Self.trimmedEnvString(Self.reasoningModelKey, from: env) ?? ""
                updated.anthropicDefaultHaikuModel = try Self.trimmedEnvString(Self.defaultHaikuModelKey, from: env) ?? ""
                updated.anthropicDefaultSonnetModel = try Self.trimmedEnvString(Self.defaultSonnetModelKey, from: env) ?? ""
                updated.anthropicDefaultOpusModel = try Self.trimmedEnvString(Self.defaultOpusModelKey, from: env) ?? ""

                if let apiKey {
                    updated.credentialType = .apiKey
                    updated.credentialValue = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let authToken {
                    updated.credentialType = .authToken
                    updated.credentialValue = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    updated.credentialValue = ""
                }

                return updated
            }

            private static func assign(_ value: String, for key: String, into env: inout [String: String]) {
                guard !value.isEmpty else { return }
                env[key] = value
            }

            private static let authTokenKey = "ANTHROPIC_AUTH_TOKEN"
            private static let apiKeyKey = "ANTHROPIC_API_KEY"
            private static let baseURLKey = "ANTHROPIC_BASE_URL"
            private static let modelKey = "ANTHROPIC_MODEL"
            private static let reasoningModelKey = "ANTHROPIC_REASONING_MODEL"
            private static let defaultHaikuModelKey = "ANTHROPIC_DEFAULT_HAIKU_MODEL"
            private static let defaultSonnetModelKey = "ANTHROPIC_DEFAULT_SONNET_MODEL"
            private static let defaultOpusModelKey = "ANTHROPIC_DEFAULT_OPUS_MODEL"
            private static let supportedTopLevelKeys: Set<String> = ["env"]
            private static let supportedEnvKeys: Set<String> = [
                authTokenKey,
                apiKeyKey,
                baseURLKey,
                modelKey,
                reasoningModelKey,
                defaultHaikuModelKey,
                defaultSonnetModelKey,
                defaultOpusModelKey
            ]

            private static func optionalEnvString(_ key: String, from env: [String: Any]) throws -> String? {
                guard let value = env[key] else { return nil }
                if value is NSNull {
                    return nil
                }
                guard let stringValue = value as? String else {
                    throw JSONSyncError.invalidEnvValue(key: key)
                }
                return stringValue
            }

            private static func trimmedEnvString(_ key: String, from env: [String: Any]) throws -> String? {
                try optionalEnvString(key, from: env)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        private static let defaultBaseURL = "https://api.anthropic.com"

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
                baseURL: Self.defaultBaseURL,
                anthropicModel: "",
                anthropicReasoningModel: "",
                anthropicDefaultHaikuModel: "",
                anthropicDefaultSonnetModel: "",
                anthropicDefaultOpusModel: ""
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

            guard !draft.trimmedCredentialValue.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_credential",
                    value: "Credential cannot be empty.",
                    comment: "Claude account editor empty credential error"
                )
                return
            }
            guard !draft.trimmedBaseURL.isEmpty else {
                editorErrorMessage = NSLocalizedString(
                    "claude.accounts.editor.error.empty_base_url",
                    value: "Base URL cannot be empty.",
                    comment: "Claude account editor empty base url error"
                )
                return
            }
            do {
                switch draft.mode {
                case .create:
                    var newAccount = ClaudeAccount(
                        id: draft.accountID,
                        name: draft.trimmedName,
                        credentialType: draft.credentialType,
                        credentialValue: draft.trimmedCredentialValue,
                        baseURL: draft.trimmedBaseURL,
                        anthropicModel: draft.trimmedAnthropicModel,
                        anthropicReasoningModel: draft.trimmedAnthropicReasoningModel,
                        anthropicDefaultHaikuModel: draft.trimmedAnthropicDefaultHaikuModel,
                        anthropicDefaultSonnetModel: draft.trimmedAnthropicDefaultSonnetModel,
                        anthropicDefaultOpusModel: draft.trimmedAnthropicDefaultOpusModel,
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
                    updated.name = draft.trimmedName
                    updated.credentialType = draft.credentialType
                    updated.credentialValue = draft.trimmedCredentialValue
                    updated.baseURL = draft.trimmedBaseURL
                    updated.anthropicModel = draft.trimmedAnthropicModel
                    updated.anthropicReasoningModel = draft.trimmedAnthropicReasoningModel
                    updated.anthropicDefaultHaikuModel = draft.trimmedAnthropicDefaultHaikuModel
                    updated.anthropicDefaultSonnetModel = draft.trimmedAnthropicDefaultSonnetModel
                    updated.anthropicDefaultOpusModel = draft.trimmedAnthropicDefaultOpusModel
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

    private var engine: any ProviderUsageAccountsEngineProtocol { state.accountsEngine }
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

    private var engine: any ProviderUsageMetricsEngineProtocol { state.metricsEngine }
    var tokenTrendRange: UsageEngineTokenTrendRange { engine.tokenTrendRange }
    var tokenTrendSnapshot: ProviderTokenTrendSnapshot? { engine.tokenTrendSnapshot }
    var tokenTrendErrorMessage: String? { engine.tokenTrendErrorMessage }
    var isLoadingTokenTrend: Bool { engine.isLoadingTokenTrend }
    var tokenTrendCapability: ProviderUsageCurveCapability { engine.tokenTrendCapability }
    var selectedDayKey: String? { engine.selectedTokenTrendDayKey }
    var intradayBucket: ProviderIntradayBucket { engine.intradayBucket }
    var intradaySnapshot: ProviderIntradayUsageSnapshot? { engine.intradaySnapshot }
    var intradayErrorMessage: String? { engine.intradayErrorMessage }
    var isLoadingIntraday: Bool { engine.isLoadingIntraday }
    var shouldShowLoadingSkeleton: Bool { engine.shouldShowTokenTrendLoadingSkeleton }

    func load() async {
        await engine.loadUsage()
    }

    func loadIfNeeded() async -> Bool {
        await engine.loadUsageIfNeeded()
    }

    func setRange(_ range: UsageEngineTokenTrendRange) {
        engine.setTokenTrendRange(range)
    }

    func refreshNow() {
        engine.refreshTokenTrendNow()
    }

    func selectDay(_ dayKey: String?) {
        engine.selectTokenTrendDay(dayKey)
    }

    func setIntradayBucket(_ bucket: ProviderIntradayBucket) {
        engine.setIntradayBucket(bucket)
    }

    func refreshIntradayNow() {
        engine.refreshIntradayNow()
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
    private var engine: any ProviderUsageAccountsEngineProtocol { state.accountsEngine }

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

enum ClaudeAccountEditorPreviewBuilder {
    typealias Draft = ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft

    static func settingsPreviewObject(from draft: Draft) -> [String: Any] {
        draft.settingsPreviewObject
    }

    static func settingsPreviewJSON(from draft: Draft) -> String {
        draft.settingsPreviewJSON
    }

    static func applyingSettingsPreviewJSON(_ text: String, to draft: Draft) throws -> Draft {
        try draft.applyingSettingsPreviewJSON(text)
    }
}
