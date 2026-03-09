import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class CodexUsageTabPresentationTests: XCTestCase {
    func testBDD_GivenCodexProvider_WhenResolvingUsageTabName_ThenUsesAccountAndUsageLabel() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let title = ProviderContentTabType.usage.localizedName(for: provider)

        XCTAssertEqual(title, "账号与用量")
    }

    func testBDD_GivenCodexXcodeProvider_WhenResolvingUsageTabName_ThenUsesAccountAndUsageLabel() {
        let provider = Provider(
            name: "Codex Xcode",
            defaultSkillsPath: "~/Library/Developer/Xcode/CodingAssistant/codex/skills",
            workflowPath: "~/Library/Developer/Xcode/CodingAssistant/codex/prompts",
            installMethod: .symlink,
            templateId: "codexXcode"
        )

        let title = ProviderContentTabType.usage.localizedName(for: provider)

        XCTAssertEqual(title, "账号与用量")
    }

    func testBDD_GivenNonCodexProvider_WhenResolvingUsageTabName_ThenKeepsUsageLabel() {
        let provider = Provider(
            name: "Claude",
            defaultSkillsPath: "~/.claude/skills",
            workflowPath: "~/.claude/prompts",
            installMethod: .copy,
            templateId: "claudeCode"
        )

        let title = ProviderContentTabType.usage.localizedName(for: provider)

        XCTAssertEqual(title, NSLocalizedString("tab.usage", value: "Usage", comment: "Usage"))
    }

    func testBDD_GivenChatGPTCard_WhenResolvingCodexHeaderActions_ThenActionOrderIsRefreshLoginImport() {
        let actions = ProviderUsageViewModel.codexPrimaryHeaderActions(for: .chatgptAccount)

        XCTAssertEqual(actions, [.refreshAll, .login, .importAuth])
    }

    func testBDD_GivenRelayCard_WhenResolvingCodexHeaderActions_ThenActionOrderKeepsLoginImportAndConfigActions() {
        let actions = ProviderUsageViewModel.codexPrimaryHeaderActions(for: .relayProfile)

        XCTAssertEqual(actions, [.refreshAll, .login, .importAuth, .editConfig, .validateConfig])
    }

    func testBDD_GivenNewRelayMode_WhenResolvingConfigPresentation_ThenSubtitleAndPrimaryActionGuideMinimalSetup() {
        let subtitle = ProviderUsageViewModel.codexConfigEditorSubtitle(for: .newRelay)
        let actionTitle = ProviderUsageViewModel.codexConfigEditorPrimaryActionTitle(for: .newRelay)

        XCTAssertEqual(
            subtitle,
            NSLocalizedString(
                "codex.accounts.config.subtitle.relay",
                value: "Fill in Base URL and Provider first. Query, headers, and HTTP usage mapping are optional advanced details.",
                comment: "Relay config subtitle"
            )
        )
        XCTAssertEqual(
            actionTitle,
            NSLocalizedString("generic.create", value: "Create", comment: "Create")
        )
    }

    func testBDD_GivenEditMode_WhenResolvingConfigPresentation_ThenPrimaryActionUsesSave() {
        let title = ProviderUsageViewModel.codexConfigEditorTitle(for: .edit(accountID: UUID()))
        let subtitle = ProviderUsageViewModel.codexConfigEditorSubtitle(for: .edit(accountID: UUID()))
        let actionTitle = ProviderUsageViewModel.codexConfigEditorPrimaryActionTitle(for: .edit(accountID: UUID()))

        XCTAssertEqual(title, NSLocalizedString("codex.accounts.config.edit", value: "Edit Config", comment: "Edit config title"))
        XCTAssertTrue(subtitle.contains("HTTP"))
        XCTAssertEqual(actionTitle, NSLocalizedString("generic.save", value: "Save", comment: "Save"))
    }

    func testBDD_GivenCodexLoginURLSheet_WhenResolvingDismissAction_ThenUsesSingleCancelLoginLabel() {
        XCTAssertEqual(
            CodexLoginURLSheet.dismissActionTitle,
            NSLocalizedString("codex.login.sheet.cancel", value: "取消登录", comment: "Cancel login")
        )
    }

    func testBDD_GivenWindowUsageData_WhenResolvingSortMenuOptions_ThenIncludesQuotaWindowRemainingOptions() {
        let account = CodexAuthAccount(
            id: UUID(),
            name: "Relay",
            createdAt: .distantPast,
            relativeAuthPath: "auth/relay.json"
        )
        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(.init(id: account.id, label: "Relay", token: "", addedAt: 0, lastUsed: nil)),
            outcome: .init(
                fetchKind: .cli,
                result: .success(
                    .init(
                        usage: .init(
                            identity: nil,
                            primary: .init(usedPercent: 20, windowMinutes: 60),
                            secondary: .init(usedPercent: 30, windowMinutes: 1440),
                            tertiary: nil,
                            updatedAt: Date()
                        ),
                        credits: .init(remaining: 1),
                        cost: nil,
                        sourceLabel: "CLI",
                        fetchKind: .cli,
                        strategyKind: .direct
                    )
                )
            )
        )

        let options = ProviderUsageViewModel.codexSortMenuOptions(from: [outcome])

        XCTAssertEqual(
            options,
            [.remainingCredits, .expiryTime, .name, .quotaWindowRemaining(windowMinutes: 60), .quotaWindowRemaining(windowMinutes: 1440)]
        )
    }

    func testBDD_GivenSortOptionAndDirection_WhenResolvingMenuTitle_ThenOnlySelectedItemIncludesInlineDirectionIndicator() {
        XCTAssertEqual(
            ProviderUsageViewModel.codexSortMenuItemTitle(for: .remainingCredits, direction: .descending),
            "按剩余额度 ↓"
        )
        XCTAssertEqual(
            ProviderUsageViewModel.codexSortMenuItemTitle(for: .expiryTime, direction: nil),
            "按到期时间"
        )
        XCTAssertEqual(
            ProviderUsageViewModel.codexSortMenuItemTitle(for: .expiryTime, direction: .ascending),
            "按到期时间 ↑"
        )
        XCTAssertEqual(
            ProviderUsageViewModel.codexSortMenuItemTitle(for: .quotaWindowRemaining(windowMinutes: 60), direction: nil),
            "按 1h 剩余比例"
        )
        XCTAssertEqual(
            ProviderUsageViewModel.codexSortMenuItemTitle(for: .quotaWindowRemaining(windowMinutes: 60), direction: .descending),
            "按 1h 剩余比例 ↓"
        )
    }

    func testBDD_GivenNewRelayDraft_WhenOpeningConfigEditor_ThenHTTPUsageDefaultsAreInitialized() {
        let viewModel = ProviderUsageViewModel(provider: Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        ))

        viewModel.beginNewCodexRelayAccount()

        XCTAssertEqual(viewModel.codexConfigEditorDraft?.httpUsageEnabled, false)
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.httpUsageMethod, .get)
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.httpUsageTimeoutSeconds, "15")
    }

    func testBDD_GivenNewAPIKeyDraft_WhenOpeningConfigEditor_ThenOfficialBaseURLIsPreloaded() {
        let viewModel = ProviderUsageViewModel(provider: Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        ))

        viewModel.beginNewCodexAPIKeyAccount()

        XCTAssertEqual(viewModel.codexConfigEditorDraft?.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.apiKey, "")
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.name, "")
    }

    func testBDD_GivenNewAPIKeyMode_WhenResolvingConfigPresentation_ThenSubtitleExplainsOptionalDefaults() {
        let subtitle = ProviderUsageViewModel.codexConfigEditorSubtitle(for: .newAPIKey)

        XCTAssertEqual(
            subtitle,
            NSLocalizedString(
                "codex.accounts.config.subtitle.api_key",
                value: "先填名称和 API Key。Base URL 默认官方地址，其他配置都是可选的。",
                comment: "API key config subtitle"
            )
        )
    }

    func testBDD_GivenAPIKeyDraftWithoutName_WhenSavingConfig_ThenShowsNameRequiredError() async {
        let viewModel = ProviderUsageViewModel(provider: Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        ))
        viewModel.codexConfigEditorDraft = .init(
            mode: .newAPIKey,
            name: "   ",
            apiKey: "sk-live-123",
            baseURL: "https://api.openai.com/v1",
            modelProvider: "",
            queryParamsText: "",
            headersText: "",
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

        await viewModel.saveCodexConfigEditor()

        XCTAssertEqual(
            viewModel.codexConfigEditorErrorMessage,
            NSLocalizedString(
                "codex.accounts.config.error.name_required",
                value: "Name is required.",
                comment: "Codex config missing name"
            )
        )
    }

    func testBDD_GivenHTTPUsageDraft_WhenTesting_ThenUsesDraftConfigurationAndStoresSummary() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        var capturedURL: String?
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexUsageQueryTestAction: { resolved, _ in
                capturedURL = resolved.query.request?.url
                return ProviderFetchResult(
                    usage: UsageSnapshot(
                        identity: UsageIdentity(accountEmail: nil, accountOrganization: nil, loginMethod: "relay", plan: "Enterprise"),
                        primary: RateWindow(usedPercent: 20),
                        secondary: nil,
                        tertiary: nil,
                        updatedAt: Date()
                    ),
                    credits: CreditsSnapshot(remaining: 99),
                    cost: nil,
                    sourceLabel: "HTTP",
                    fetchKind: .web,
                    strategyKind: .direct
                )
            }
        )
        viewModel.codexConfigEditorDraft = .init(
            mode: .newRelay,
            name: "Work Relay",
            apiKey: "rk-live-123",
            baseURL: "https://relay.example.com/v1",
            modelProvider: "relay",
            queryParamsText: "",
            headersText: "",
            httpUsageEnabled: true,
            httpUsageMethod: .get,
            httpUsageURL: "{{baseURL}}/usage",
            httpUsageHeadersText: "",
            httpUsageBody: "",
            httpUsageTimeoutSeconds: "15",
            httpUsageOverrideBaseURL: "",
            httpUsageOverrideAPIKey: "",
            httpUsageOverrideAccessToken: "",
            httpUsageOverrideUserID: "",
            httpUsagePlanPath: "data.plan",
            httpUsageCreditsRemainingPath: "data.credits",
            httpUsageUsedPath: "",
            httpUsageTotalPath: "",
            httpUsageCostTodayPath: "",
            httpUsageCostLast30DaysPath: "",
            httpUsageErrorMessagePath: ""
        )

        await viewModel.testCodexUsageQueryDraft()

        XCTAssertEqual(capturedURL, "{{baseURL}}/usage")
        XCTAssertTrue(viewModel.codexUsageQueryTestSuccessMessage?.contains("Enterprise") == true)
        XCTAssertNil(viewModel.codexUsageQueryTestErrorMessage)
    }

    func testBDD_GivenImportSheetOpened_WhenInitialized_ThenStartsWithEmptyCandidates() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        viewModel.beginImportAuthFiles()

        XCTAssertTrue(viewModel.isShowingCodexImportSheet)
        XCTAssertEqual(viewModel.codexImportCandidates.count, 0)
        XCTAssertFalse(viewModel.isRunningCodexImportValidation)
        XCTAssertFalse(viewModel.isRunningCodexImportConnectionTests)
    }

    func testBDD_GivenImportSheetDismissed_WhenReopened_ThenDraftStateIsReset() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        viewModel.beginImportAuthFiles()
        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/demo.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/demo.json"),
                    isValid: true,
                    reason: nil,
                    suggestedName: "Demo",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: "CLI · Plus",
                testDetail: nil
            )
        ]

        viewModel.dismissCodexImportSheet()
        viewModel.beginImportAuthFiles()

        XCTAssertTrue(viewModel.isShowingCodexImportSheet)
        XCTAssertTrue(viewModel.codexImportCandidates.isEmpty)
    }

    func testBDD_GivenValidAndInvalidCandidates_WhenSelectionChanges_ThenOnlyValidRemainSelectable() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        let validID = UUID()
        let invalidID = UUID()
        viewModel.codexImportCandidates = [
            .init(
                id: validID,
                sourceFileURL: URL(fileURLWithPath: "/tmp/valid.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/valid.json"),
                    isValid: true,
                    reason: nil,
                    suggestedName: "Valid",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                id: invalidID,
                sourceFileURL: URL(fileURLWithPath: "/tmp/invalid.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/invalid.json"),
                    isValid: false,
                    reason: "Missing required credentials",
                    suggestedName: nil,
                    email: nil,
                    authJSONString: nil
                ),
                isSelected: false,
                testStatus: .failure,
                testSummary: "Missing required credentials",
                testDetail: nil
            )
        ]

        viewModel.setCodexImportCandidateSelected(false, id: validID)
        viewModel.setCodexImportCandidateSelected(true, id: invalidID)

        XCTAssertFalse(viewModel.codexImportCandidates[0].isSelected)
        XCTAssertFalse(viewModel.codexImportCandidates[1].isSelected)
    }

    func testBDD_GivenPastedAuthJSON_WhenHandled_ThenCandidateListAppearsAndConnectionTestRuns() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-paste-auth-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexImportConnectionTestAction: { validation, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(.init(id: UUID(), label: validation.suggestedName ?? "Imported", token: "", addedAt: Date().timeIntervalSince1970, lastUsed: nil)),
                    outcome: .init(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: .init(identity: .init(accountEmail: validation.email, accountOrganization: nil, loginMethod: "chatgpt", plan: "Plus"), primary: nil, secondary: nil, tertiary: nil, updatedAt: Date()),
                                credits: nil,
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )

        let raw = """
        {
          "auth_mode":"chatgpt",
          "email":"paste-json@example.com",
          "tokens":{
            "id_token":"\(Self.makeJWT(email: "paste-json@example.com", accountID: "acct-json"))",
            "access_token":"access-demo"
          }
        }
        """

        await viewModel.handleCodexImportText(raw, preferredSourceURL: tempURL)

        XCTAssertEqual(viewModel.codexImportCandidates.count, 1)
        XCTAssertTrue(viewModel.codexImportCandidates[0].isSelected)
        XCTAssertEqual(viewModel.codexImportCandidates[0].validation.email, "paste-json@example.com")
        XCTAssertEqual(viewModel.codexImportCandidates[0].testStatus, .success)
    }

    func testBDD_GivenPastedSuccessCallbackURL_WhenHandled_ThenCandidateListAppears() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-paste-callback-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexImportConnectionTestAction: { validation, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(.init(id: UUID(), label: validation.suggestedName ?? "Imported", token: "", addedAt: Date().timeIntervalSince1970, lastUsed: nil)),
                    outcome: .init(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: .init(identity: .init(accountEmail: validation.email, accountOrganization: nil, loginMethod: "chatgpt", plan: "Team"), primary: nil, secondary: nil, tertiary: nil, updatedAt: Date()),
                                credits: nil,
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )

        let callback = "http://localhost:1455/success?id_token=\(Self.makeJWT(email: "paste-callback@example.com", accountID: "acct-callback"))"

        await viewModel.handleCodexImportText(callback, preferredSourceURL: tempURL)

        XCTAssertEqual(viewModel.codexImportCandidates.count, 1)
        XCTAssertEqual(viewModel.codexImportCandidates[0].validation.email, "paste-callback@example.com")
        XCTAssertEqual(viewModel.codexImportCandidates[0].testStatus, .success)
    }

    func testBDD_GivenPastedAuthCallbackURLOnDifferentLoopbackHost_WhenHandled_ThenCandidateListAppears() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-paste-callback-alt-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexImportConnectionTestAction: { validation, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(.init(id: UUID(), label: validation.suggestedName ?? "Imported", token: "", addedAt: Date().timeIntervalSince1970, lastUsed: nil)),
                    outcome: .init(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: .init(identity: .init(accountEmail: validation.email, accountOrganization: nil, loginMethod: "chatgpt", plan: "Team"), primary: nil, secondary: nil, tertiary: nil, updatedAt: Date()),
                                credits: nil,
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )

        let callback = "http://127.0.0.1:1789/auth/callback?id_token=\(Self.makeJWT(email: "paste-alt-callback@example.com", accountID: "acct-callback-alt"))"

        await viewModel.handleCodexImportText(callback, preferredSourceURL: tempURL)

        XCTAssertEqual(viewModel.codexImportCandidates.count, 1)
        XCTAssertEqual(viewModel.codexImportCandidates[0].validation.email, "paste-alt-callback@example.com")
        XCTAssertEqual(viewModel.codexImportCandidates[0].testStatus, .success)
    }

    private static func makeCodexProvider() -> Provider {
        Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
    }

    private static func makeJWT(email: String, accountID: String) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        let payload = """
        {
          "email":"\(email)",
          "https://api.openai.com/auth":{
            "chatgpt_account_id":"\(accountID)"
          }
        }
        """
        return "\(base64URLEncode(header)).\(base64URLEncode(payload))."
    }

    private static func base64URLEncode(_ raw: String) -> String {
        Data(raw.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func testBDD_GivenGeminiProvider_WhenResolvingDashboardLoginPolicy_ThenUsesRefreshInsteadOfSignIn() {
        let provider = Provider(
            name: "Gemini CLI",
            defaultSkillsPath: "~/.gemini/skills",
            workflowPath: "~/.gemini/workflows",
            installMethod: .copy,
            templateId: "gemini"
        )
        let shouldShowSignIn = ProviderUsageLoginPolicy.shouldShowDashboardSignIn(
            for: provider,
            dashboardURL: URL(string: "https://gemini.google.com")
        )
        XCTAssertFalse(shouldShowSignIn)
    }

    func testBDD_GivenCopilotProvider_WhenResolvingDashboardLoginPolicy_ThenKeepsSignIn() {
        let provider = Provider(
            name: "Copilot",
            defaultSkillsPath: "~/.copilot/skills",
            workflowPath: "~/.copilot/prompts",
            installMethod: .copy,
            templateId: "copilot"
        )
        let shouldShowSignIn = ProviderUsageLoginPolicy.shouldShowDashboardSignIn(
            for: provider,
            dashboardURL: URL(string: "https://github.com/settings/copilot")
        )
        XCTAssertTrue(shouldShowSignIn)
    }

    func testBDD_GivenGeminiProvider_WhenResolvingCLILoginPolicy_ThenShowsLoginAction() {
        let provider = Provider(
            name: "Gemini CLI",
            defaultSkillsPath: "~/.gemini/skills",
            workflowPath: "~/.gemini/workflows",
            installMethod: .copy,
            templateId: "gemini"
        )

        let shouldUseCLILogin = ProviderUsageLoginPolicy.shouldUseCLILogin(for: provider)

        XCTAssertTrue(shouldUseCLILogin)
    }

    func testBDD_GivenGeminiCandidate_WhenEvaluatingInlineImportPolicy_ThenShowsImportAction() {
        let shouldShow = ProviderUsageViewModel.shouldShowGeminiImportAction(
            usageProvider: .gemini,
            outcomes: [],
            candidateAvailable: true
        )

        XCTAssertTrue(shouldShow)
    }

    func testBDD_GivenGeminiWithoutCandidate_WhenEvaluatingInlineImportPolicy_ThenHidesImportAction() {
        let shouldShow = ProviderUsageViewModel.shouldShowGeminiImportAction(
            usageProvider: .gemini,
            outcomes: [],
            candidateAvailable: false
        )

        XCTAssertFalse(shouldShow)
    }

    func testBDD_GivenNonGeminiProvider_WhenEvaluatingInlineImportPolicy_ThenHidesImportAction() {
        let outcome = ProviderAccountUsageOutcome(
            provider: .antigravity,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.missingAccount(.antigravity))
            )
        )

        let shouldShow = ProviderUsageViewModel.shouldShowGeminiImportAction(
            usageProvider: .antigravity,
            outcomes: [outcome],
            candidateAvailable: true
        )

        XCTAssertFalse(shouldShow)
    }

    func testBDD_GivenFailedUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenForcesRefresh() {
        let failed = ProviderAccountUsageOutcome(
            provider: .antigravity,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.missingAccount(.antigravity))
            )
        )

        let shouldForce = ProviderUsageViewModel.shouldForceRefreshOnAppearForFailedOutcomes([failed])

        XCTAssertTrue(shouldForce)
    }

    func testBDD_GivenSuccessfulUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenDoesNotForceRefresh() {
        let success = ProviderAccountUsageOutcome(
            provider: .antigravity,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .success(
                    ProviderFetchResult(
                        usage: UsageSnapshot(
                            identity: UsageIdentity(accountEmail: nil, accountOrganization: nil, loginMethod: nil),
                            primary: nil,
                            secondary: nil,
                            tertiary: nil,
                            updatedAt: Date()
                        ),
                        credits: nil,
                        cost: nil,
                        sourceLabel: "CLI",
                        fetchKind: .cli,
                        strategyKind: .direct
                    )
                )
            )
        )

        let shouldForce = ProviderUsageViewModel.shouldForceRefreshOnAppearForFailedOutcomes([success])

        XCTAssertFalse(shouldForce)
    }
}
