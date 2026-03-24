import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
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

    func testBDD_GivenCodexHeaderActions_WhenResolvingVisibleActions_ThenShowsRefreshAndLoginInTopBar() {
        let visibleActions = ProviderUsageView.visibleCodexPrimaryHeaderActions(
            from: [.refreshAll, .login, .importAuth],
            isCodexMultiSelectionEnabled: false
        )

        XCTAssertEqual(visibleActions, [.refreshAll, .login])
    }

    func testBDD_GivenCodexAccountActivationState_WhenResolvingContextMenuPolicy_ThenOnlyInactiveShowsActivateAction() {
        XCTAssertTrue(ProviderUsageView.shouldShowActivateAccountContextAction(isActiveAccount: false))
        XCTAssertFalse(ProviderUsageView.shouldShowActivateAccountContextAction(isActiveAccount: true))
    }

    func testBDD_GivenGatewayActivationState_WhenResolvingContextMenuPolicy_ThenOnlyInactiveShowsActivateAction() {
        XCTAssertTrue(ProviderUsageView.shouldShowActivateGatewayContextAction(isActiveGateway: false))
        XCTAssertFalse(ProviderUsageView.shouldShowActivateGatewayContextAction(isActiveGateway: true))
    }

    func testBDD_GivenCodexLayoutMode_WhenResolvingListPresentationStyle_ThenListUsesCompactRowsAndCardsUseCardStyle() {
        XCTAssertTrue(
            ProviderUsageView.shouldUseCompactCodexListRows(layoutMode: .list)
        )
        XCTAssertFalse(
            ProviderUsageView.shouldUseCompactCodexListRows(layoutMode: .cards)
        )
    }

    func testBDD_GivenCodexLayoutMode_WhenResolvingTextSelectionPolicy_ThenListDisablesSelectionToKeepTapSwitching() {
        XCTAssertFalse(
            ProviderUsageView.shouldEnableCodexTextSelection(layoutMode: .list)
        )
        XCTAssertTrue(
            ProviderUsageView.shouldEnableCodexTextSelection(layoutMode: .cards)
        )
    }

    func testBDD_GivenGatewayMemberRows_WhenResolvingCompactMetrics_ThenListModeUsesTighterLimitsThanCards() {
        XCTAssertEqual(
            ProviderUsageView.gatewayMemberDisplayLimit(layoutMode: .list),
            8
        )
        XCTAssertEqual(
            ProviderUsageView.gatewayMemberDisplayLimit(layoutMode: .cards),
            12
        )
        XCTAssertLessThan(
            ProviderUsageView.gatewayMemberRowMaxHeight(layoutMode: .list),
            ProviderUsageView.gatewayMemberRowMaxHeight(layoutMode: .cards)
        )
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

    func testBDD_GivenOneDayTokenTrendRange_WhenResolvingPresentation_ThenUsesOneDayWindow() {
        XCTAssertEqual(ProviderUsageViewModel.TokenTrendRange.days1.trailingDays, 1)
        XCTAssertEqual(
            ProviderUsageViewModel.TokenTrendRange.days1.title,
            NSLocalizedString("codex.usage.range.1d", value: "1D", comment: "Codex usage trend range 1 day")
        )
    }

    func testBDD_GivenTokenTrendSection_WhenResolvingQuickActions_ThenCardsCoverAllRangesWithoutHeaderSegment() {
        XCTAssertEqual(ProviderTokenTrendSection.quickActionRanges, ProviderUsageViewModel.TokenTrendRange.allCases)
        XCTAssertFalse(ProviderTokenTrendSection.usesHeaderRangePicker)
        XCTAssertTrue(ProviderTokenTrendSection.usesFullCardTapTarget)
        XCTAssertEqual(ProviderTokenTrendSection.summaryCardMinHeight, 84)
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

    func testBDD_GivenChatGPTSummaryWithEmail_WhenResolvingCardDisplayName_ThenEmailWinsOverLegacyDefaultName() {
        let title = CodexAccountDisplayNameResolver.resolve(
            summary: CodexAuthSummary(
                email: "vpn2linhey@gmail.com",
                accountID: "acct-123",
                name: "Legacy Name",
                cardKind: .chatgptAccount
            ),
            relativeAuthPath: "auth/personal.json",
            defaultName: "Personal",
            accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )

        XCTAssertEqual(title, "vpn2linhey@gmail.com")
    }

    func testBDD_GivenConfiguredCardWithoutEmail_WhenResolvingCardDisplayName_ThenUsesProviderOrFileStemInsteadOfStoredName() {
        let relayTitle = CodexAccountDisplayNameResolver.resolve(
            summary: CodexAuthSummary(
                name: "Stored Relay Name",
                cardKind: .relayProfile,
                relayBaseURL: "https://openrouter.ai/api/v1",
                relayModelProvider: "OpenRouter"
            ),
            relativeAuthPath: "auth/work-relay.json",
            defaultName: "Work Relay",
            accountID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")
        )
        XCTAssertEqual(relayTitle, "OpenRouter")

        let apiKeyFallbackTitle = CodexAccountDisplayNameResolver.resolve(
            summary: CodexAuthSummary(
                name: "Stored API Key Name",
                cardKind: .officialAPIKey
            ),
            relativeAuthPath: "auth/openai-direct.json",
            defaultName: "OpenAI Direct",
            accountID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")
        )
        XCTAssertEqual(apiKeyFallbackTitle, "openai-direct")
    }

    func testBDD_GivenImportSheetOpened_WhenInitialized_ThenStartsWithEmptyCandidates() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        viewModel.beginImportAuthFiles()

        XCTAssertTrue(viewModel.isShowingCodexImportSheet)
        XCTAssertEqual(viewModel.codexImportCandidates.count, 0)
        XCTAssertFalse(viewModel.hasCodexImportCandidates)
        XCTAssertFalse(viewModel.isRunningCodexImportValidation)
        XCTAssertFalse(viewModel.isRunningCodexImportConnectionTests)
        XCTAssertEqual(CodexImportSheet.minimumSheetHeight(hasAnyCandidates: false), 320)
        XCTAssertEqual(CodexImportSheet.minimumSheetHeight(hasAnyCandidates: true), 560)
    }

    func testBDD_GivenImportSheetDismissed_WhenReopened_ThenDraftStateIsReset() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        viewModel.beginImportAuthFiles()
        viewModel.codexImportSearchText = "demo"
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
        XCTAssertEqual(viewModel.codexImportSearchText, "")
    }

    func testBDD_GivenImportCandidatesAcrossGroups_WhenSearching_ThenOnlyMatchingSectionsRemainVisible() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/team-alpha/oauth.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/team-alpha/oauth.json"),
                    sourceGroupID: "group-alpha",
                    sourceGroupLabel: "Alpha.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "Alpha OAuth",
                    email: "alpha@example.com",
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/team-beta/relay.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/team-beta/relay.json"),
                    sourceGroupID: "group-beta",
                    sourceGroupLabel: "Beta.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "Beta Relay",
                    email: "relay@example.com",
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            )
        ]

        viewModel.codexImportSearchText = "alpha@example.com"

        XCTAssertEqual(viewModel.codexImportCandidateSections.count, 1)
        XCTAssertEqual(viewModel.codexImportCandidateSections.first?.title, "Alpha.zip")
        XCTAssertEqual(viewModel.codexImportCandidateSections.first?.items.count, 1)
        XCTAssertEqual(viewModel.codexImportCandidateSections.first?.items.first?.validation.suggestedName, "Alpha OAuth")

        viewModel.codexImportSearchText = "relay.json"

        XCTAssertEqual(viewModel.codexImportCandidateSections.count, 1)
        XCTAssertEqual(viewModel.codexImportCandidateSections.first?.title, "Beta.zip")
        XCTAssertEqual(viewModel.codexImportCandidateSections.first?.items.first?.validation.suggestedName, "Beta Relay")

        viewModel.codexImportSearchText = ""

        XCTAssertEqual(viewModel.codexImportCandidateSections.count, 2)
        XCTAssertEqual(viewModel.codexImportSearchResultCount, 2)
        XCTAssertTrue(viewModel.hasCodexImportCandidates)
    }

    func testBDD_GivenImportCandidatesExist_WhenSearchHasNoMatch_ThenSearchResultsBecomeEmpty() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/demo.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/demo.json"),
                    sourceGroupID: "group-demo",
                    sourceGroupLabel: "Demo.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "Demo OAuth",
                    email: "demo@example.com",
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            )
        ]

        viewModel.codexImportSearchText = "missing-keyword"

        XCTAssertTrue(viewModel.codexImportCandidateSections.isEmpty)
        XCTAssertEqual(viewModel.codexImportSearchResultCount, 0)
    }

    func testBDD_GivenImportSheetPickerReturnsFiles_WhenPresentingPicker_ThenStartsValidationWithSelectedURLs() async {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        XCTAssertNoThrow(try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true))
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let firstURL = tempDirectory.appendingPathComponent("first.json")
        let secondURL = tempDirectory.appendingPathComponent("second.zip")
        XCTAssertNoThrow(try "{}".write(to: firstURL, atomically: true, encoding: .utf8))
        XCTAssertNoThrow(try Data("PK".utf8).write(to: secondURL))

        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexImportConnectionTestAction: { validationResult, _ in
                ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .default,
                    outcome: .init(
                        fetchKind: .cli,
                        result: .failure(CodexImportPanelTestError.connection)
                    )
                )
            },
            codexImportOpenPanelAction: { [firstURL, secondURL] }
        )

        await viewModel.presentCodexImportFilePicker()

        XCTAssertEqual(viewModel.importedAuthFileURLs, [firstURL, secondURL])
        XCTAssertEqual(viewModel.codexImportCandidates.count, 2)
    }

    func testBDD_GivenImportSheetPickerCancelled_WhenPresentingPicker_ThenKeepsCandidatesUnchanged() async {
        let existingURL = URL(fileURLWithPath: "/tmp/existing.json")
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexImportOpenPanelAction: { [] }
        )
        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: existingURL,
                validation: .init(
                    fileURL: existingURL,
                    isValid: true,
                    reason: nil,
                    suggestedName: "Existing",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .idle,
                testSummary: nil,
                testDetail: nil
            )
        ]

        await viewModel.presentCodexImportFilePicker()

        XCTAssertEqual(viewModel.codexImportCandidates.count, 1)
        XCTAssertEqual(viewModel.importedAuthFileURLs, [])
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

    func testBDD_GivenPastedOAuthWithoutExplicitHTTPUsageQuery_WhenHandled_ThenSkipsOnlineTestInsteadOfFallingBackToCLI() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-paste-no-http-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        let raw = """
        {
          "auth_mode":"chatgpt",
          "email":"skip-http@example.com",
          "tokens":{
            "id_token":"\(Self.makeJWT(email: "skip-http@example.com", accountID: "acct-skip-http"))",
            "access_token":"access-demo"
          }
        }
        """

        await viewModel.handleCodexImportText(raw, preferredSourceURL: tempURL)

        XCTAssertEqual(viewModel.codexImportCandidates.count, 1)
        XCTAssertEqual(viewModel.codexImportCandidates[0].testStatus, .failure)
        XCTAssertTrue(viewModel.codexImportCandidates[0].testSummary?.contains("HTTP") == true)
        XCTAssertTrue(viewModel.codexImportCandidates[0].testSummary?.contains("跳过") == true)
        XCTAssertFalse(viewModel.codexImportCandidates[0].testSummary?.contains("JSON-RPC") == true)
    }

    func testBDD_GivenSelectedImportCandidates_WhenExportingZIP_ThenOnlySelectedValidCandidatesAreForwarded() async {
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-import-export-\(UUID().uuidString).zip")
        var capturedResults: [CodexAuthManager.CodexImportValidationResult] = []
        var capturedDestinationURL: URL?
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexExportSavePanelAction: { _, _ in destinationURL },
            codexImportExportArchiveAction: { results, url in
                capturedResults = results
                capturedDestinationURL = url
                return results.count
            }
        )

        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/selected.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/selected.json"),
                    isValid: true,
                    reason: nil,
                    suggestedName: "Selected",
                    email: "selected@example.com",
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/unselected.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/unselected.json"),
                    isValid: true,
                    reason: nil,
                    suggestedName: "Unselected",
                    email: "unselected@example.com",
                    authJSONString: "{}"
                ),
                isSelected: false,
                testStatus: .idle,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/invalid.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/invalid.json"),
                    isValid: false,
                    reason: "Missing required credentials",
                    suggestedName: nil,
                    email: nil,
                    authJSONString: nil
                ),
                isSelected: true,
                testStatus: .failure,
                testSummary: nil,
                testDetail: nil
            )
        ]

        await viewModel.exportSelectedCodexImportCandidatesAsZIP()

        XCTAssertEqual(capturedResults.count, 1)
        XCTAssertEqual(capturedResults.first?.email, "selected@example.com")
        XCTAssertEqual(capturedDestinationURL, destinationURL)
        XCTAssertEqual(viewModel.alertMessage, "已导出 1 个候选账号到 ZIP。")
    }

    func testBDD_GivenSelectedImportCandidatesContainRelay_WhenExportingSub2API_ThenAlertIncludesSkippedRelayCount() async {
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-import-export-\(UUID().uuidString).json")
        var capturedResults: [CodexAuthManager.CodexImportValidationResult] = []
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            codexExportSavePanelAction: { _, _ in destinationURL },
            codexImportExportSub2APIAction: { results, _ in
                capturedResults = results
                return Sub2APIExportResult(exportedCount: 1, skippedRelayCount: 1, skippedUnsupportedCount: 0)
            }
        )

        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/oauth.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/oauth.json"),
                    isValid: true,
                    reason: nil,
                    suggestedName: "OAuth",
                    email: "oauth@example.com",
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/relay.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/relay.json"),
                    isValid: true,
                    reason: nil,
                    suggestedName: "Relay",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: true,
                testStatus: .success,
                testSummary: nil,
                testDetail: nil
            )
        ]

        await viewModel.exportSelectedCodexImportCandidatesAsSub2API()

        XCTAssertEqual(capturedResults.count, 2)
        XCTAssertEqual(
            viewModel.alertMessage,
            "已导出 1 个候选账号为 sub2api，跳过 1 个 relay 账号。"
        )
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

    func testBDD_GivenGeminiAccountCount_WhenResolvingCardLayout_ThenSingleCardUsesFullWidth() {
        XCTAssertTrue(ProviderUsageView.shouldUseFullWidthGeminiCardLayout(accountCount: 1))
        XCTAssertFalse(ProviderUsageView.shouldUseFullWidthGeminiCardLayout(accountCount: 2))
        XCTAssertFalse(ProviderUsageView.shouldUseFullWidthGeminiCardLayout(accountCount: 0))
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

    func testBDD_GivenGeminiAccountsPresent_WhenResolvingDisplayedGenericUsageOutcomes_ThenHidesDuplicateOutcomeCards() {
        let outcome = ProviderAccountUsageOutcome(
            provider: .gemini,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .oauth,
                result: .success(
                    ProviderFetchResult(
                        usage: UsageSnapshot(
                            identity: UsageIdentity(
                                accountEmail: "dev@example.com",
                                accountOrganization: nil,
                                loginMethod: "oauth"
                            ),
                            primary: nil,
                            secondary: nil,
                            tertiary: nil,
                            updatedAt: Date()
                        ),
                        credits: nil,
                        cost: nil,
                        sourceLabel: "OAuth",
                        fetchKind: .oauth,
                        strategyKind: .direct
                    )
                )
            )
        )

        let displayed = ProviderUsageViewModel.displayedGenericUsageOutcomes(
            usageProvider: .gemini,
            hasGeminiAccounts: true,
            outcomes: [outcome]
        )

        XCTAssertTrue(displayed.isEmpty)
    }

    func testBDD_GivenGeminiWithoutAccounts_WhenResolvingDisplayedGenericUsageOutcomes_ThenKeepsOutcomeCardsForEmptyState() {
        let outcome = ProviderAccountUsageOutcome(
            provider: .gemini,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.missingAccount(.gemini))
            )
        )

        let displayed = ProviderUsageViewModel.displayedGenericUsageOutcomes(
            usageProvider: .gemini,
            hasGeminiAccounts: false,
            outcomes: [outcome]
        )

        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed.first?.id, outcome.id)
    }

    func testBDD_GivenClaudeWithoutAccounts_WhenResolvingDisplayedClaudeUsageOutcomes_ThenSuppressesMissingAccountCard() {
        let outcome = ProviderAccountUsageOutcome(
            provider: .claude,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .web,
                result: .failure(ProviderUsageError.missingAccount(.claude))
            )
        )

        let displayed = ProviderUsageViewModel.displayedClaudeUsageOutcomes(
            hasClaudeAccounts: false,
            outcomes: [outcome]
        )

        XCTAssertTrue(displayed.isEmpty)
    }

    func testBDD_GivenClaudeWithAccounts_WhenResolvingDisplayedClaudeUsageOutcomes_ThenKeepsMissingAccountCardForDiagnosis() {
        let outcome = ProviderAccountUsageOutcome(
            provider: .claude,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .web,
                result: .failure(ProviderUsageError.missingAccount(.claude))
            )
        )

        let displayed = ProviderUsageViewModel.displayedClaudeUsageOutcomes(
            hasClaudeAccounts: true,
            outcomes: [outcome]
        )

        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed.first?.id, outcome.id)
    }

    func testBDD_GivenCodexInitialSettingsOverride_WhenInitializingViewModel_ThenHideZeroQuotaStateFollowsSettings() {
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 30,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30,
                codexHideZeroQuotaAccounts: true
            )
        )

        XCTAssertTrue(viewModel.codexHideZeroQuotaAccounts)
        XCTAssertTrue(viewModel.settings.codexHideZeroQuotaAccounts)
    }

    func testBDD_GivenCodexUsageViewModel_WhenTogglingHideZeroQuota_ThenSettingsAreUpdated() {
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 30,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30,
                codexHideZeroQuotaAccounts: false
            )
        )

        viewModel.setCodexHideZeroQuotaAccounts(true)

        XCTAssertTrue(viewModel.codexHideZeroQuotaAccounts)
        XCTAssertTrue(viewModel.settings.codexHideZeroQuotaAccounts)
    }

    func testBDD_GivenCodexInitialSettingsOverride_WhenInitializingViewModel_ThenLayoutModeFollowsSettings() {
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 30,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30,
                codexHideZeroQuotaAccounts: false,
                codexUseListLayout: true
            )
        )

        XCTAssertEqual(viewModel.codexAccountLayoutMode, .list)
        XCTAssertTrue(viewModel.settings.codexUseListLayout)
    }

    func testBDD_GivenCodexUsageViewModel_WhenSwitchingLayoutMode_ThenSettingsAreUpdated() {
        let viewModel = ProviderUsageViewModel(
            provider: Self.makeCodexProvider(),
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 30,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30,
                codexHideZeroQuotaAccounts: false,
                codexUseListLayout: false
            )
        )

        viewModel.setCodexAccountLayoutMode(.list)
        XCTAssertEqual(viewModel.codexAccountLayoutMode, .list)
        XCTAssertTrue(viewModel.settings.codexUseListLayout)

        viewModel.setCodexAccountLayoutMode(.cards)
        XCTAssertEqual(viewModel.codexAccountLayoutMode, .cards)
        XCTAssertFalse(viewModel.settings.codexUseListLayout)
    }

    func testBDD_GivenCodexAutoSwitchSettingsOverride_WhenInitializingViewModel_ThenAutoSwitchConfigFollowsStore() {
        let suiteName = "codex-usage-auto-switch-init-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let provider = Self.makeCodexProvider()
        let store = CodexAutoSwitchSettingsStore(userDefaults: userDefaults)
        store.update(
            settings: CodexAutoSwitchConfig(
                enabled: true,
                thresholdPercent: 15,
                minimumCandidateRemainingPercent: 30,
                skipRelayAccounts: false,
                cooldown: 900
            ),
            for: provider
        )

        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexAutoSwitchSettingsStore: store
        )

        XCTAssertTrue(viewModel.codexAutoSwitchConfig.enabled)
        XCTAssertEqual(viewModel.codexAutoSwitchConfig.thresholdPercent, 15)
        XCTAssertEqual(viewModel.codexAutoSwitchConfig.minimumCandidateRemainingPercent, 30)
        XCTAssertFalse(viewModel.codexAutoSwitchConfig.skipRelayAccounts)
    }

    func testBDD_GivenCodexUsageViewModel_WhenUpdatingAutoSwitchConfig_ThenStoreIsUpdated() {
        let suiteName = "codex-usage-auto-switch-update-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let provider = Self.makeCodexProvider()
        let store = CodexAutoSwitchSettingsStore(userDefaults: userDefaults)
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexAutoSwitchSettingsStore: store
        )

        viewModel.setCodexAutoSwitchEnabled(true)
        viewModel.setCodexAutoSwitchThresholdPercent(20)
        viewModel.setCodexAutoSwitchMinimumCandidateRemainingPercent(40)
        viewModel.setCodexAutoSwitchSkipRelay(false)

        XCTAssertTrue(viewModel.codexAutoSwitchConfig.enabled)
        XCTAssertEqual(viewModel.codexAutoSwitchConfig.thresholdPercent, 20)
        XCTAssertEqual(viewModel.codexAutoSwitchConfig.minimumCandidateRemainingPercent, 40)
        XCTAssertFalse(viewModel.codexAutoSwitchConfig.skipRelayAccounts)
        XCTAssertEqual(store.settings(for: provider), viewModel.codexAutoSwitchConfig)
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

    func testBDD_GivenCodexNeedsReauthRecord_WhenMappingCard_ThenShowsWarningBadgeAndFailureMessage() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_600_000)
        let usageError = ProviderUsageError.authExpired(.codex)
        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                    label: "Work",
                    token: "redacted",
                    addedAt: updatedAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .cli, result: .failure(usageError))
        )
        let summary = CodexAuthSummary(
            email: "work@example.com",
            plan: "pro",
            lastLoginAt: updatedAt,
            lastSyncFailureMessage: "Authentication expired"
        )

        let record = AccountRecordBuilder.codexUsage(
            outcome: outcome,
            summary: summary,
            presentation: .codex(
                isActive: false,
                isPending: false,
                isBatchSelected: false,
                selectableAccountCount: 1
            ),
            title: "Work",
            creditsRefreshedAt: nil,
            isRefreshing: false,
            canRelogin: true
        )
        let card = AccountCardViewDataMapper.map(record: record)

        XCTAssertEqual(card.header.badge?.tone, .warning)
        XCTAssertEqual(
            card.header.badge?.text,
            NSLocalizedString("codex.accounts.status.reauth_needed", value: "Needs re-login", comment: "Account status reauth")
        )
        XCTAssertEqual(
            card.detailRows.first?.value,
            NSLocalizedString(
                "codex.accounts.error.auth_expired",
                value: "Authentication expired. Please sign in again.",
                comment: "Codex auth expired summary"
            )
        )
    }
}

private enum CodexImportPanelTestError: LocalizedError {
    case connection
}
