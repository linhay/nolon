import SwiftUI
import AppKit
import ProviderCatalog
import Observation
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers
import OSLog
import Combine
import NolonResourceKit
import NolonCoreCLIKit
import NolonUIFoundation
import GRDB
@preconcurrency import STFilePath
import STJSON

extension ProviderUsageEngine {
    enum CodexActiveRuntimeRefreshScope {
        case none
        case authOnly
        case authAndConfig
    }

    func beginImportAuthFiles() {
        codexImportConnectionTestsTask?.cancel()
        codexImportConnectionTestsTask = nil
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        codexImportGlobalErrorMessage = nil
        codexImportSearchText = ""
        codexImportCandidates = []
        codexImportDestinationOption = .managedSnapshots
        codexImportCustomGroupName = ""
        isTargetingCodexImportDropZone = false
        isRunningCodexImportValidation = false
        isRunningCodexImportConnectionTests = false
        isShowingCodexImportSheet = true
    }

    func dismissCodexImportSheet() {
        codexImportConnectionTestsTask?.cancel()
        codexImportConnectionTestsTask = nil
        isShowingCodexImportSheet = false
        isTargetingCodexImportDropZone = false
        isRunningCodexImportValidation = false
        isRunningCodexImportConnectionTests = false
        codexImportGlobalErrorMessage = nil
        codexImportSearchText = ""
        codexImportCandidates = []
        codexImportDestinationOption = .managedSnapshots
        codexImportCustomGroupName = ""
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        pendingImportValidationResults = []
        importValidationSummaryMessage = nil
        isShowingImportValidationConfirm = false
    }

    func presentCodexImportFilePicker() async {
        importedAuthFileURL = nil
        importedAuthFileURLs = []
        let urls = codexImportOpenPanelAction()
        guard !urls.isEmpty else { return }
        await handleCodexImportURLs(urls)
    }

    func pasteCodexImportFromClipboard() async {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            codexImportGlobalErrorMessage = NSLocalizedString(
                "codex.import.sheet.error.empty_pasteboard",
                value: "剪贴板里没有可解析的账号数据。",
                comment: "Empty clipboard import error"
            )
            return
        }
        await handleCodexImportText(raw)
    }

    func handleCodexImportText(_ raw: String, preferredSourceURL: URL? = nil) async {
        guard usageProvider == .codex else { return }
        let trimmed = Self.trimmed(raw)
        guard !trimmed.isEmpty else { return }

        do {
            let normalized = try normalizeCodexImportText(trimmed)
            let sourceURL = preferredSourceURL ?? makePastedCodexImportURL(for: normalized.fileExtension)
            try Data(normalized.authJSONString.utf8).write(to: sourceURL, options: .atomic)
            await handleCodexImportURLs([sourceURL])
        } catch {
            codexImportGlobalErrorMessage = error.localizedDescription
        }
    }

    func setCodexImportCandidateSelected(_ selected: Bool, id: UUID) {
        guard let index = codexImportCandidates.firstIndex(where: { $0.id == id }) else { return }
        guard codexImportCandidates[index].validation.isValid else { return }
        codexImportCandidates[index].isSelected = selected
    }

    func setAllCodexImportCandidatesSelected(_ selected: Bool) {
        codexImportCandidates = codexImportCandidates.map { candidate in
            guard candidate.validation.isValid else { return candidate }
            var updated = candidate
            updated.isSelected = selected
            return updated
        }
    }

    func setCodexImportCandidatesSelected(_ selected: Bool, sourceGroupID: String) {
        codexImportCandidates = codexImportCandidates.map { candidate in
            guard candidate.validation.sourceGroupID == sourceGroupID, candidate.validation.isValid else { return candidate }
            var updated = candidate
            updated.isSelected = selected
            return updated
        }
    }

    func removeCodexImportCandidate(id: UUID) {
        codexImportCandidates.removeAll { $0.id == id }
    }

    func handleCodexImportURLs(_ urls: [URL]) async {
        guard usageProvider == .codex else { return }
        guard !urls.isEmpty else { return }

        codexImportConnectionTestsTask?.cancel()
        codexImportConnectionTestsTask = nil
        importedAuthFileURLs = urls
        codexImportGlobalErrorMessage = nil
        isRunningCodexImportValidation = true
        let results = await codexAuthManager.validateImportAuthFiles(urls: urls)
        isRunningCodexImportValidation = false

        mergeCodexImportCandidates(results: results)
        let pendingTestIDs: [UUID] = codexImportCandidates.compactMap { candidate -> UUID? in
            guard candidate.validation.isValid, candidate.testStatus != .success else { return nil }
            return candidate.id
        }
        guard !pendingTestIDs.isEmpty else { return }

        // Show validated list immediately, then fill usage details one by one in the background.
        codexImportConnectionTestsTask = Task { [weak self] in
            guard let self else { return }
            await self.runCodexImportConnectionTests(for: pendingTestIDs)
            self.codexImportConnectionTestsTask = nil
        }
    }

    func setCodexMultiSelectionEnabled(_ enabled: Bool) {
        isCodexMultiSelectionEnabled = enabled
        if !enabled {
            selectedCodexAccountIDs.removeAll()
        }
    }

    func toggleCodexAccountSelection(id: UUID) {
        guard isCodexMultiSelectionEnabled else { return }
        selectedCodexAccountIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: selectedCodexAccountIDs,
            tapped: id
        )
    }

    func isCodexAccountSelected(id: UUID?) -> Bool {
        guard isCodexMultiSelectionEnabled, let id else { return false }
        return selectedCodexAccountIDs.contains(id)
    }

    func isCodexSectionFullySelected(_ section: CodexAccountDisplaySection) -> Bool {
        guard isCodexMultiSelectionEnabled else { return false }
        let sectionIDs = codexSectionAccountIDs(from: section.items)
        guard !sectionIDs.isEmpty else { return false }
        return sectionIDs.isSubset(of: selectedCodexAccountIDs)
    }

    func toggleCodexSectionSelection(_ section: CodexAccountDisplaySection) {
        guard isCodexMultiSelectionEnabled else { return }
        let sectionIDs = codexSectionAccountIDs(from: section.items)
        selectedCodexAccountIDs = GenericSelectionStateResolver.resolveBatchMultiSelection(
            current: selectedCodexAccountIDs,
            toggledValues: sectionIDs
        )
    }

    func codexSectionAccountIDs(from items: [ProviderAccountUsageOutcome]) -> Set<UUID> {
        Set(items.compactMap { outcome in
            guard case let .tokenAccount(account) = outcome.account else { return nil }
            return account.id
        })
    }

    func loadCodexConfigEditorModelProviderOptions(current: String) -> [String] {
        guard codexModelPreferenceService.supports(provider: provider) else { return [] }
        var options = codexModelPreferenceService.loadRelayModelProviderIDs(for: provider)
        let normalizedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedCurrent.isEmpty && !options.contains(normalizedCurrent) {
            options.insert(normalizedCurrent, at: 0)
        }
        return options
    }

    func beginNewCodexAPIKeyAccount() {
        let draft = CodexConfigEditorDraft(
            mode: .newAPIKey,
            name: "",
            apiKey: "",
            baseURL: "",
            modelProvider: Self.codexDefaultModelProvider,
            queryParamsText: "",
            httpUsageEnabled: false,
            httpUsageMethod: .get,
            httpUsageURL: "",
            httpUsageHeadersText: "",
            httpUsageBody: "",
            httpUsageTimeoutSeconds: "15",
            httpUsageOverrideBaseURL: "",
            httpUsageOverrideAPIKey: "",
            httpUsageOverrideAccessToken: "",
            httpUsageOverrideUserID: "",
            httpUsagePlanPath: "",
            httpUsageCreditsRemainingPath: "",
            httpUsageUsedPath: "",
            httpUsageTotalPath: "",
            httpUsageCostTodayPath: "",
            httpUsageCostLast30DaysPath: "",
            httpUsageErrorMessagePath: ""
        )
        codexConfigEditorDraft = draft
        codexConfigEditorModelProviderOptions = loadCodexConfigEditorModelProviderOptions(
            current: draft.modelProvider
        )
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isShowingCodexConfigEditor = true
    }

    func beginEditCodexConfiguredAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }),
              let summary = codexAccountSummaries[id]
        else { return }

        let draft = codexConfiguredAccountEditorDraft(account: account, summary: summary)
        codexConfigEditorDraft = draft
        codexConfigEditorModelProviderOptions = loadCodexConfigEditorModelProviderOptions(
            current: draft.modelProvider
        )
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isShowingCodexConfigEditor = true
    }

    func dismissCodexConfigEditor() {
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil
        isTestingCodexUsageQuery = false
        isSavingCodexConfigEditor = false
        codexConfigEditorDraft = nil
        codexConfigEditorModelProviderOptions = []
        isShowingCodexConfigEditor = false
    }

    func saveCodexConfigEditor() async {
        guard let draft = codexConfigEditorDraft else { return }
        guard !isSavingCodexConfigEditor else { return }

        let apiKey = Self.trimmed(draft.apiKey)
        guard !apiKey.isEmpty else {
            codexConfigEditorErrorMessage = NSLocalizedString(
                "codex.accounts.config.error.api_key_required",
                value: "API Key is required.",
                comment: "Codex config missing API key"
            )
            return
        }

        let relay: CodexAuthManager.ConfiguredRelay?
        do {
            relay = try makeCodexConfiguredRelay(from: draft)
        } catch {
            codexConfigEditorErrorMessage = error.localizedDescription
            return
        }

        isSavingCodexConfigEditor = true
        defer { isSavingCodexConfigEditor = false }

        do {
            let preferredName = resolvedConfiguredAccountName(
                userInputName: draft.name,
                baseURLText: draft.baseURL,
                apiKey: apiKey,
                editingAccountID: {
                    if case let .edit(accountID) = draft.mode { return accountID }
                    return nil
                }()
            )
            let savedAccount: CodexAuthAccount
            let refreshScope: CodexActiveRuntimeRefreshScope
            switch draft.mode {
            case .newAPIKey:
                savedAccount = try await codexAuthManager.addConfiguredAccount(
                    name: preferredName,
                    apiKey: apiKey,
                    relay: relay,
                    usageQuery: nil
                )
                refreshScope = .none
            case let .edit(accountID):
                guard let account = codexAccounts.first(where: { $0.id == accountID }) else { return }
                let existingDraft = codexConfiguredAccountEditorDraft(
                    account: account,
                    summary: codexAccountSummaries[accountID] ?? CodexAuthSummary()
                )
                try await codexAuthManager.updateConfiguredAccount(
                    account,
                    name: preferredName,
                    apiKey: apiKey,
                    relay: relay,
                    usageQuery: nil
                )
                savedAccount = CodexAuthAccount(
                    id: account.id,
                    name: preferredName,
                    createdAt: account.createdAt,
                    relativeAuthPath: account.relativeAuthPath
                )
                refreshScope = codexActiveRuntimeRefreshScope(
                    previous: existingDraft,
                    current: draft
                )
                switch refreshScope {
                case .none:
                    break
                case .authOnly:
                    try await codexAuthManager.refreshActiveProviderFilesIfNeeded(
                        for: savedAccount,
                        provider: provider,
                        syncRuntimeConfig: false
                    )
                case .authAndConfig:
                    try await codexAuthManager.refreshActiveProviderFilesIfNeeded(
                        for: savedAccount,
                        provider: provider,
                        syncRuntimeConfig: true
                    )
                }
            }
            await applySavedCodexConfiguredAccountLocally(savedAccount)
            activeCodexAccountId = await codexAuthManager.activeAccountId(for: provider, accounts: codexAccounts)
            if refreshScope != .none {
                codexAuthFilePath = await codexAuthManager.authFile(for: provider)?.url.path
                currentCodexAuthHashHex = await codexAuthManager.currentAuthHashHex(for: provider)
            }
            dismissCodexConfigEditor()
        } catch {
            codexConfigEditorErrorMessage = error.localizedDescription
        }
    }

    func codexConfiguredAccountEditorDraft(
        account: CodexAuthAccount,
        summary: CodexAuthSummary
    ) -> CodexConfigEditorDraft {
        let rawJSON: JSON? = {
            guard let data = codexAuthManager.accountAuthData(for: account) else { return nil }
            return try? JSON(data: data)
        }()
        let relayObject: [String: String] = Self.stringDictionary(from: rawJSON?["nolon"]["relay"]["query_params"])
        let usageQuery: CodexHTTPUsageQuery? = {
            guard let usageObject = rawJSON?["nolon"]["usage_query"].dictionaryObject,
                  let data = try? JSONSerialization.data(withJSONObject: usageObject)
            else {
                return nil
            }
            return try? JSONDecoder().decode(CodexHTTPUsageQuery.self, from: data)
        }()

        return CodexConfigEditorDraft(
            mode: .edit(accountID: account.id),
            name: account.name,
            apiKey: rawJSON?["OPENAI_API_KEY"].string ?? "",
            baseURL: summary.relayBaseURL ?? "",
            modelProvider: summary.relayModelProvider ?? Self.codexDefaultModelProvider,
            queryParamsText: Self.serializeKeyValueLines(relayObject),
            httpUsageEnabled: usageQuery?.enabled ?? false,
            httpUsageMethod: usageQuery?.request?.method ?? .get,
            httpUsageURL: usageQuery?.request?.url ?? "",
            httpUsageHeadersText: Self.serializeKeyValueLines(usageQuery?.request?.headers ?? [:]),
            httpUsageBody: usageQuery?.request?.body ?? "",
            httpUsageTimeoutSeconds: usageQuery?.timeoutSeconds.map { Self.formatTimeoutSeconds($0) } ?? "15",
            httpUsageOverrideBaseURL: usageQuery?.credentials?.baseURL ?? "",
            httpUsageOverrideAPIKey: usageQuery?.credentials?.apiKey ?? "",
            httpUsageOverrideAccessToken: usageQuery?.credentials?.accessToken ?? "",
            httpUsageOverrideUserID: usageQuery?.credentials?.userID ?? "",
            httpUsagePlanPath: usageQuery?.mapping?.planPath ?? "",
            httpUsageCreditsRemainingPath: usageQuery?.mapping?.creditsRemainingPath ?? "",
            httpUsageUsedPath: usageQuery?.mapping?.usageUsedPath ?? "",
            httpUsageTotalPath: usageQuery?.mapping?.usageTotalPath ?? "",
            httpUsageCostTodayPath: usageQuery?.mapping?.costTodayUSDPath ?? "",
            httpUsageCostLast30DaysPath: usageQuery?.mapping?.costLast30DaysUSDPath ?? "",
            httpUsageErrorMessagePath: usageQuery?.mapping?.errorMessagePath ?? ""
        )
    }

    func codexActiveRuntimeRefreshScope(
        previous: CodexConfigEditorDraft,
        current: CodexConfigEditorDraft
    ) -> CodexActiveRuntimeRefreshScope {
        if (try? makeCodexConfiguredRelay(from: previous)) != (try? makeCodexConfiguredRelay(from: current)) {
            return .authAndConfig
        }
        if Self.trimmed(previous.apiKey) != Self.trimmed(current.apiKey) {
            return .authOnly
        }
        return .none
    }

    func applySavedCodexConfiguredAccountLocally(_ account: CodexAuthAccount) async {
        if let index = codexAccounts.firstIndex(where: { $0.id == account.id }) {
            codexAccounts[index] = account
        } else {
            codexAccounts.append(account)
        }

        if let authData = codexAuthManager.accountAuthDataWithoutMaterialization(for: account) {
            codexAccountSummaries[account.id] = CodexAuthSummary.fromJSONData(authData)
        } else {
            codexAccountSummaries.removeValue(forKey: account.id)
        }

        let (updatedOutcome, refreshedAt) = await buildCachedCodexAccountOutcome(
            for: account,
            summary: codexAccountSummaries[account.id]
        )
        if let index = codexAccountOutcomes.firstIndex(where: { outcome in
            guard case let .tokenAccount(tokenAccount) = outcome.account else { return false }
            return tokenAccount.id == account.id
        }) {
            codexAccountOutcomes[index] = updatedOutcome
        } else {
            codexAccountOutcomes.append(updatedOutcome)
        }

        if let refreshedAt {
            codexAccountCreditsRefreshedAt[account.id] = refreshedAt
        } else {
            codexAccountCreditsRefreshedAt.removeValue(forKey: account.id)
        }

        normalizeCodexGroupingOptionIfNeeded()
        reorderCodexAccountOutcomesForDisplay()
    }

    static func resolvedCodexModelProvider(_ raw: String) -> String {
        let trimmed = trimmed(raw)
        return trimmed.isEmpty ? codexDefaultModelProvider : trimmed
    }

    func resolvedConfiguredAccountName(
        userInputName: String,
        baseURLText: String,
        apiKey: String,
        editingAccountID: UUID?
    ) -> String {
        let explicitName = Self.trimmed(userInputName)
        if !explicitName.isEmpty {
            return explicitName
        }

        let baseURLHost = Self.hostFromBaseURLText(baseURLText) ?? "api.openai.com"
        let existingNames = Set(
            codexAccounts
                .filter { account in
                    if let editingAccountID {
                        return account.id != editingAccountID
                    }
                    return true
                }
                .map { Self.trimmed($0.name).lowercased() }
        )

        if !existingNames.contains(baseURLHost.lowercased()) {
            return baseURLHost
        }

        let suffix = Self.apiKeySuffix(apiKey)
        var candidate = "\(baseURLHost)-\(suffix)"
        var counter = 2
        while existingNames.contains(candidate.lowercased()) {
            candidate = "\(baseURLHost)-\(suffix)-\(counter)"
            counter += 1
        }
        return candidate
    }

    static func hostFromBaseURLText(_ baseURLText: String) -> String? {
        let raw = trimmed(baseURLText)
        guard !raw.isEmpty else { return nil }
        guard let host = URL(string: raw)?.host else { return nil }
        let normalized = trimmed(host).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    static func apiKeySuffix(_ apiKey: String) -> String {
        let normalized = trimmed(apiKey)
        guard normalized.count >= 4 else { return "key" }
        return String(normalized.suffix(4)).lowercased()
    }

    func makeCodexConfiguredRelay(
        from draft: CodexConfigEditorDraft
    ) throws -> CodexAuthManager.ConfiguredRelay? {
        let baseURL = Self.trimmed(draft.baseURL)
        let queryParams = try Self.parseKeyValueLines(draft.queryParamsText)
        guard !baseURL.isEmpty || !queryParams.isEmpty else {
            return nil
        }
        guard !baseURL.isEmpty else {
            throw NSError(
                domain: "ProviderUsageEngine.CodexConfig",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                    "codex.accounts.config.error.base_url_required_for_relay_extras",
                    value: "Base URL is required when relay query params are configured.",
                    comment: "Codex relay extras require base url"
                )]
            )
        }

        return .init(
            baseURL: baseURL,
            modelProvider: Self.resolvedCodexModelProvider(draft.modelProvider),
            queryParams: queryParams
        )
    }

    func testCodexUsageQueryDraft() async {
        guard let draft = codexConfigEditorDraft else { return }
        codexConfigEditorErrorMessage = nil
        codexUsageQueryTestSuccessMessage = nil
        codexUsageQueryTestErrorMessage = nil

        let resolved: CodexHTTPUsageQueryResolvedConfiguration
        do {
            guard let query = try makeCodexUsageQuery(from: draft) else {
                throw NSError(
                    domain: "ProviderUsageEngine.CodexUsageQuery",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                        "codex.accounts.http_usage.test.missing",
                        value: "Enable HTTP usage query and fill the request before testing.",
                        comment: "Missing HTTP usage query test config"
                    )]
                )
            }
            resolved = try makeCodexUsageQueryResolvedConfiguration(from: draft, query: query)
        } catch {
            codexUsageQueryTestErrorMessage = error.localizedDescription
            return
        }

        isTestingCodexUsageQuery = true
        defer { isTestingCodexUsageQuery = false }

        do {
            let result = try await codexUsageQueryTestAction(resolved, settings.includeCredits)
            codexUsageQueryTestSuccessMessage = Self.codexUsageQueryTestSummary(result: result)
        } catch {
            codexUsageQueryTestErrorMessage = Self.errorSummaryText(error: error, maxLength: 220)
        }
    }

    func validateCodexConnectionDraft() async {
        guard let draft = codexConfigEditorDraft else { return }

        let apiKey = Self.trimmed(draft.apiKey)
        guard !apiKey.isEmpty else {
            codexConfigEditorErrorMessage = NSLocalizedString(
                "codex.accounts.config.error.api_key_required",
                value: "API Key is required.",
                comment: "Codex config missing API key"
            )
            return
        }

        do {
            var authObject: [String: Any] = [
                "auth_mode": "apikey",
                "OPENAI_API_KEY": apiKey,
            ]
            if let relay = try makeCodexConfiguredRelay(from: draft) {
                authObject["base_url"] = relay.baseURL

                var relayObject: [String: Any] = [
                    "base_url": relay.baseURL,
                    "model_provider": relay.modelProvider,
                ]
                if !relay.queryParams.isEmpty {
                    relayObject["query_params"] = relay.queryParams
                }
                authObject["nolon"] = ["relay": relayObject]
            }

            let authData = try JSONSerialization.data(withJSONObject: authObject, options: [])
            let message = try await CodexAccountValidationService.validate(authData: authData)
            alertTitle = NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
            alertMessage = message
        } catch {
            codexConfigEditorErrorMessage = Self.errorSummaryText(error: error)
        }
    }

    func validateImportedAuthFiles(_ urls: [URL]) async {
        await handleCodexImportURLs(urls)
    }

    func applyValidatedImports() async {
        await applySelectedCodexImports()
    }

    func retryAllCodexImportConnectionTests() async {
        await runCodexImportConnectionTests(for: codexImportCandidates.compactMap { candidate in
            candidate.validation.isValid ? candidate.id : nil
        })
    }

    func retryCodexImportConnectionTest(id: UUID) async {
        await runCodexImportConnectionTests(for: [id])
    }

    func applySelectedCodexImports() async {
        guard usageProvider == .codex else { return }
        let selectedResults = codexImportCandidates
            .filter { $0.validation.isValid && $0.isSelected }
            .map(\.validation)

        guard !selectedResults.isEmpty else {
            codexImportGlobalErrorMessage = NSLocalizedString(
                "codex.import.sheet.error.none_selected",
                value: "请先选择至少一个可导入的账号。",
                comment: "No selected import candidates"
            )
            return
        }

        if codexImportDestinationOption == .customSQLiteGroup,
           !Self.isNotBlank(codexImportCustomGroupName)
        {
            codexImportGlobalErrorMessage = NSLocalizedString(
                "codex.import.sheet.error.custom_group_required",
                value: "请先填写自定义分组名称。",
                comment: "Custom SQLite group name required"
            )
            return
        }

        let destination: CodexAuthManager.ImportDestination = {
            switch codexImportDestinationOption {
            case .managedSnapshots:
                return .managedSnapshots
            case .customSQLiteGroup:
                return .customSQLiteGroup(name: Self.trimmed(codexImportCustomGroupName))
            }
        }()

        do {
            _ = try await codexAuthManager.importValidatedAuthFiles(
                results: selectedResults,
                destination: destination
            )
            dismissCodexImportSheet()
            await load()
        } catch {
            codexImportGlobalErrorMessage = error.localizedDescription
        }
    }

    func exportSelectedCodexImportCandidatesAsZIP() async {
        guard canExportSelectedCodexImportCandidates else {
            alertTitle = NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title")
            alertMessage = NSLocalizedString(
                "codex.import.sheet.export.error.none_selected",
                value: "请先选择至少一个可导出的账号。",
                comment: "No selected import candidates for export"
            )
            return
        }

        guard let destinationURL = codexExportSavePanelAction(.zip, Self.defaultCodexImportExportArchiveName()) else { return }
        let selectedResults = codexImportCandidates
            .filter { $0.validation.isValid && $0.isSelected }
            .map(\.validation)

        do {
            let exportedCount = try await codexImportExportArchiveAction(selectedResults, destinationURL)
            alertTitle = NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title")
            alertMessage = String(
                format: NSLocalizedString(
                    "codex.import.sheet.export_zip.success",
                    value: "已导出 %d 个候选账号到 ZIP。",
                    comment: "Codex import ZIP export success"
                ),
                exportedCount
            )
        } catch {
            alertTitle = NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title")
            alertMessage = error.localizedDescription
        }
    }

    func exportSelectedCodexAccountsAsZIP() async {
        guard canExportSelectedCodexAccounts else {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = NSLocalizedString(
                "codex.accounts.export.error.no_selection",
                value: "请先选择要导出的账号卡片。",
                comment: "No selected Codex accounts for export"
            )
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = Self.defaultCodexExportArchiveName()

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else { return }

        do {
            let exportedCount = try await codexAuthManager.exportAccountsArchive(
                accountIDs: Array(selectedCodexAccountIDs),
                destinationURL: destinationURL
            )
            setCodexMultiSelectionEnabled(false)
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = String(
                format: NSLocalizedString(
                    "codex.accounts.export.success",
                    value: "已导出 %d 个账号到 ZIP。",
                    comment: "Codex export success"
                ),
                exportedCount
            )
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = error.localizedDescription
        }
    }

}
