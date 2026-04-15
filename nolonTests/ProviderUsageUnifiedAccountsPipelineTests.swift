import Foundation
import Observation
import Testing
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
@testable import nolon

private final class BoolSink: @unchecked Sendable {
    var value = false
}

@MainActor
struct ProviderUsageUnifiedAccountsPipelineTests {
    @Test("BDD: Given Claude provider account state when building unified cards then emits Claude card models")
    func testBDD_GivenClaudeProviderState_WhenBuildingUnifiedCards_ThenEmitsClaudeCards() {
        let provider = Provider(
            id: "claude",
            kind: .vendor,
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.claudeCode.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = ClaudeAccount(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Claude Main",
            credentialType: .authToken,
            credentialValue: "token",
            baseURL: "https://api.anthropic.com",
            source: .manual
        )
        root.state.claudeEngine.claudeAccounts = [account]
        root.state.claudeEngine.activeClaudeAccountId = account.id

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: nil,
            isLoading: false
        )

        #expect(cards.count == 1)
        #expect(cards.first?.provider == .claude)
        #expect(cards.first?.isActive == true)
        #expect(cards.first?.data.menuActions.contains(where: { $0.actionID == .refresh }) == true)
        #expect(cards.first?.data.menuActions.contains(where: { $0.actionID == .edit }) == true)
        #expect(root.accountsViewModel.unifiedAccountEmptyState != nil)
    }

    @Test("BDD: Given Claude account card when invoking edit action then opens account editor with selected account")
    func testBDD_GivenClaudeCard_WhenInvokingEditAction_ThenOpensEditorForSelectedAccount() async throws {
        let provider = Provider(
            id: "claude",
            kind: .vendor,
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.claudeCode.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = ClaudeAccount(
            id: UUID(uuidString: "aaaaaaaa-1111-1111-1111-111111111111")!,
            name: "Claude Editor",
            credentialType: .apiKey,
            credentialValue: "sk-ant-1",
            baseURL: "https://api.anthropic.com",
            source: .manual
        )
        root.state.claudeEngine.claudeAccounts = [account]

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: nil,
            isLoading: false
        )
        let card = try #require(cards.first)
        await card.onAction(.edit)

        #expect(root.accountsViewModel.claude.isShowingEditor == true)
        #expect(root.accountsViewModel.claude.editorDraft?.accountID == account.id)
        #expect(root.accountsViewModel.claude.editorDraft?.anthropicModel == "gpt-5")
        #expect(root.accountsViewModel.claude.editorDraft?.anthropicReasoningModel == "")
        #expect(root.accountsViewModel.claude.editorDraft?.anthropicDefaultHaikuModel == "gpt-5(minimal)")
        #expect(root.accountsViewModel.claude.editorDraft?.anthropicDefaultSonnetModel == "gpt-5(medium)")
        #expect(root.accountsViewModel.claude.editorDraft?.anthropicDefaultOpusModel == "gpt-5(high)")
    }

    @Test("BDD: Given Claude card edit action when opening editor then Claude state emits observation change")
    func testBDD_GivenClaudeCardEdit_WhenOpeningEditor_ThenClaudeStateObservationUpdates() throws {
        let provider = Provider(
            id: "claude",
            kind: .vendor,
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.claudeCode.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = ClaudeAccount(
            id: UUID(uuidString: "bbbbbbbb-1111-1111-1111-111111111111")!,
            name: "Claude Observe",
            credentialType: .apiKey,
            credentialValue: "sk-ant-observe",
            baseURL: "https://api.anthropic.com",
            source: .manual
        )
        root.state.claudeEngine.claudeAccounts = [account]

        let didObserveChange = BoolSink()
        withObservationTracking {
            _ = root.accountsViewModel.claude.isShowingEditor
            _ = root.accountsViewModel.claude.editorDraft
        } onChange: {
            didObserveChange.value = true
        }

        root.accountsViewModel.claude.beginEditAccount(id: account.id)

        #expect(didObserveChange.value == true)
        #expect(root.accountsViewModel.claude.isShowingEditor == true)
        #expect(root.accountsViewModel.claude.editorDraft?.accountID == account.id)
    }

    @Test("BDD: Given Claude menu add action when invoked then opens editor in create mode")
    func testBDD_GivenClaudeMenuAddAction_WhenInvoked_ThenOpensCreateEditor() {
        let provider = Provider(
            id: "claude",
            kind: .vendor,
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.claudeCode.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)

        root.accountsViewModel.claude.beginCreateAccount()

        #expect(root.accountsViewModel.claude.isShowingEditor == true)
        #expect(root.accountsViewModel.claude.editorDraft?.mode == .create)
        #expect(root.accountsViewModel.claude.editorDraft?.baseURL == "https://api.anthropic.com")
        #expect(root.accountsViewModel.claude.editorDraft?.anthropicModel == "gpt-5")
    }

    @Test("BDD: Given Gemini provider account state when building unified cards then emits Gemini card models")
    func testBDD_GivenGeminiProviderState_WhenBuildingUnifiedCards_ThenEmitsGeminiCards() {
        let provider = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            providerID: .gemini,
            name: "Gemini Main",
            method: .oauthPersonal,
            createdAt: Date(),
            lastUsedAt: nil,
            lastLoginAt: Date(),
            email: "gemini@example.com",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: ".gemini"
        )
        root.state.geminiEngine.geminiAccounts = [account]
        root.state.geminiEngine.activeGeminiAccountId = account.id

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: nil,
            isLoading: false
        )

        #expect(cards.count == 1)
        #expect(cards.first?.provider == .gemini)
        #expect(cards.first?.isActive == true)
        #expect(cards.first?.data.menuActions.contains(where: { $0.actionID == .refresh }) == true)
        #expect(root.accountsViewModel.unifiedAccountEmptyState == nil)
    }

    @Test("BDD: Given Gemini usage windows when building active card then exposes per-model usage")
    func testBDD_GivenGeminiUsageWindows_WhenBuildingCard_ThenExposesModelUsages() {
        let provider = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            providerID: .gemini,
            name: "Gemini Active",
            method: .oauthPersonal,
            createdAt: Date(),
            lastUsedAt: nil,
            lastLoginAt: Date(),
            email: "active@gemini.dev",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: ".gemini"
        )
        root.state.geminiEngine.geminiAccounts = [account]
        root.state.geminiEngine.activeGeminiAccountId = account.id

        let usage = UsageSnapshot(
            identity: nil,
            windows: [
                .init(id: "gemini-2.5-flash", title: "gemini-2.5-flash", window: .init(usedPercent: 20)),
                .init(id: "gemini-3.1-pro-preview", title: "gemini-3.1-pro-preview", window: .init(usedPercent: 35)),
            ],
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let fetchResult = ProviderFetchResult(
            usage: usage,
            credits: nil,
            cost: nil,
            sourceLabel: "OAuth",
            fetchKind: .oauth,
            strategyKind: .direct
        )
        let liveOutcome = ProviderAccountUsageOutcome(
            provider: .gemini,
            account: .default,
            outcome: .init(fetchKind: .oauth, result: .success(fetchResult))
        )

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: liveOutcome,
            isLoading: false
        )

        #expect(cards.count == 1)
        guard case let .quota(quota)? = cards.first?.data.body else {
            Issue.record("Expected quota body for Gemini active account card")
            return
        }
        #expect(quota.modelUsages?.count == 2)
        #expect(quota.modelUsages?.map(\.title) == ["gemini-2.5-flash", "gemini-3.1-pro-preview"])
        #expect(quota.modelUsages?.map(\.remainingPercent) == [80.0, 65.0])
    }

    @Test("BDD: Given Gemini live failure when building unified card then exposes shared error text and standard actions")
    func testBDD_GivenGeminiLiveFailure_WhenBuildingUnifiedCard_ThenUsesSharedPresentationAndActionFactory() {
        let provider = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            providerID: .gemini,
            name: "Gemini Failed",
            method: .oauthPersonal,
            createdAt: Date(),
            lastUsedAt: nil,
            lastLoginAt: Date(),
            email: "failed@gemini.dev",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: ".gemini"
        )
        root.state.geminiEngine.geminiAccounts = [account]
        root.state.geminiEngine.activeGeminiAccountId = account.id

        let liveOutcome = ProviderAccountUsageOutcome(
            provider: .gemini,
            account: .default,
            outcome: .init(
                fetchKind: .oauth,
                result: .failure(ProviderUsageError.missingAccount(.gemini))
            )
        )

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: liveOutcome,
            isLoading: true
        )

        let card = try! #require(cards.first)
        #expect(card.isActive == true)
        #expect(card.data.primaryActions.isEmpty)
        #expect(card.data.menuActions.map(\.actionID) == [.refresh, .delete])
        guard case let .quota(quota) = card.data.body else {
            Issue.record("Expected quota body for Gemini failure account card")
            return
        }
        #expect(quota.errorMessage?.isEmpty == false)
    }

    @Test("BDD: Given official API key Codex failure when building usage card then omits relogin and error actions")
    func testBDD_GivenOfficialAPIKeyCodexFailure_WhenBuildingUsageCard_ThenOmitsFailureActions() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = CodexAuthAccount(
            id: UUID(uuidString: "55555555-4444-3333-2222-111111111111")!,
            name: "Configured",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            relativeAuthPath: "auth/configured.json"
        )
        root.state.codexEngine.codexAccounts = [account]
        root.state.codexEngine.codexAccountSummaries = [
            account.id: CodexAuthSummary(
                email: "api@example.com",
                cardKind: .officialAPIKey,
                lastSyncFailureMessage: "OpenAI API key rejected"
            )
        ]

        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(
                fetchKind: .web,
                result: .failure(
                    NSError(
                        domain: "ProviderUsageUnifiedAccountsPipelineTests",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "OpenAI API key rejected"]
                    )
                )
            )
        )

        let model = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            isRunningCLILogin: false
        )

        #expect(model.data.primaryActions.isEmpty)
        #expect(model.data.menuActions.contains(where: { $0.actionID == .relogin }) == false)
        #expect(model.data.menuActions.contains(where: { $0.actionID == .refresh }) == true)
        #expect(model.data.detailRows.isEmpty)
    }

    @Test("BDD: Given relay profile Codex failure when building usage card then omits relogin and error actions")
    func testBDD_GivenRelayProfileCodexFailure_WhenBuildingUsageCard_ThenOmitsFailureActions() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = CodexAuthAccount(
            id: UUID(uuidString: "66666666-5555-4444-3333-222222222222")!,
            name: "Relay",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            relativeAuthPath: "auth/relay.json"
        )
        root.state.codexEngine.codexAccounts = [account]
        root.state.codexEngine.codexAccountSummaries = [
            account.id: CodexAuthSummary(
                cardKind: .relayProfile,
                relayModelProvider: "nolon",
                lastSyncFailureMessage: "Codex protocol error: -32600: chatgpt authentication required to read rate limits"
            )
        ]

        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(
                fetchKind: .web,
                result: .failure(
                    NSError(
                        domain: "ProviderUsageUnifiedAccountsPipelineTests",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Codex protocol error: -32600: chatgpt authentication required to read rate limits"]
                    )
                )
            )
        )

        let model = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            isRunningCLILogin: false
        )

        #expect(model.data.primaryActions.isEmpty)
        #expect(model.data.menuActions.contains(where: { $0.actionID == .relogin }) == false)
        #expect(model.data.menuActions.contains(where: { $0.actionID == .refresh }) == true)
        #expect(model.data.detailRows.isEmpty)
    }

    @Test("BDD: Given pending Codex activation confirmation when building usage card then keeps card neutral until confirmed")
    func testBDD_GivenPendingCodexActivationConfirmation_WhenBuildingUsageCard_ThenKeepsNeutralPresentation() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = CodexAuthAccount(
            id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            name: "API Key",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            relativeAuthPath: "auth/apikey.json"
        )
        root.state.codexEngine.codexAccounts = [account]
        root.state.codexEngine.pendingActivateCodexAccount = account

        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )

        let model = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            isRunningCLILogin: false
        )

        #expect(model.presentation.selectionStyle == .neutral)
    }

    @Test("BDD: Given Codex account switch in progress when building usage cards then only transitioning target stays highlighted")
    func testBDD_GivenCodexSwitchInProgress_WhenBuildingUsageCards_ThenOnlyTransitioningTargetIsHighlighted() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let activeAccount = CodexAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "OAuth",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            relativeAuthPath: "auth/oauth.json"
        )
        let targetAccount = CodexAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            name: "API Key",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            relativeAuthPath: "auth/apikey.json"
        )
        root.state.codexEngine.codexAccounts = [activeAccount, targetAccount]
        root.state.codexEngine.activeCodexAccountId = activeAccount.id
        root.state.codexEngine.activatingCodexAccountId = targetAccount.id

        let activeOutcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: activeAccount.id,
                    label: activeAccount.name,
                    token: "",
                    addedAt: activeAccount.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .oauth, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )
        let targetOutcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: targetAccount.id,
                    label: targetAccount.name,
                    token: "",
                    addedAt: targetAccount.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )

        let activeModel = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: activeOutcome,
            isRunningCLILogin: false
        )
        let targetModel = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: targetOutcome,
            isRunningCLILogin: false
        )

        #expect(activeModel.presentation.selectionStyle == .neutral)
        #expect(targetModel.presentation.selectionStyle == .transitioning)
    }

    @Test("BDD: Given stale Codex selection residue outside multi-selection when building usage cards then ignores selected styling")
    func testBDD_GivenStaleCodexSelectionResidueOutsideMultiSelection_WhenBuildingUsageCards_ThenOnlyActiveCardStaysHighlighted() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let staleSelectedAccount = CodexAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "OAuth",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            relativeAuthPath: "auth/oauth.json"
        )
        let activeAccount = CodexAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            name: "API Key",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            relativeAuthPath: "auth/apikey.json"
        )
        root.state.codexEngine.codexAccounts = [staleSelectedAccount, activeAccount]
        root.state.codexEngine.activeCodexAccountId = activeAccount.id
        root.state.codexEngine.selectedCodexAccountIDs = [staleSelectedAccount.id]
        root.state.codexEngine.isCodexMultiSelectionEnabled = false

        let staleSelectedOutcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: staleSelectedAccount.id,
                    label: staleSelectedAccount.name,
                    token: "",
                    addedAt: staleSelectedAccount.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .oauth, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )
        let activeOutcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: activeAccount.id,
                    label: activeAccount.name,
                    token: "",
                    addedAt: activeAccount.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )

        let staleSelectedModel = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: staleSelectedOutcome,
            isRunningCLILogin: false
        )
        let activeModel = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: activeOutcome,
            isRunningCLILogin: false
        )

        #expect(staleSelectedModel.presentation.selectionStyle == .neutral)
        #expect(staleSelectedModel.presentation.showsSelectionBadge == false)
        #expect(activeModel.presentation.selectionStyle == .active)
    }

    @Test("BDD: Given Codex account switch in progress when building usage card then does not show switching badge")
    func testBDD_GivenCodexSwitchInProgress_WhenBuildingUsageCard_ThenDoesNotShowSwitchingBadge() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let account = CodexAuthAccount(
            id: UUID(uuidString: "12121212-3434-5656-7878-909090909090")!,
            name: "API Key",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            relativeAuthPath: "auth/apikey.json"
        )
        root.state.codexEngine.codexAccounts = [account]
        root.state.codexEngine.activatingCodexAccountId = account.id

        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: account.name,
                    token: "",
                    addedAt: account.createdAt.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )

        let model = root.accountsViewModel.codex.makeUsageCardModel(
            outcome: outcome,
            isRunningCLILogin: false
        )

        #expect(model.presentation.selectionStyle == .transitioning)
        #expect(model.data.header.badge == nil)
    }

    @Test("BDD: Given mixed outcomes when selecting unified card live outcome then prefers success result")
    func testBDD_GivenMixedOutcomes_WhenSelectingUnifiedCardLiveOutcome_ThenPrefersSuccess() {
        let provider = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)
        let failureOutcome = ProviderAccountUsageOutcome(
            provider: .gemini,
            account: .default,
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingAccount(.gemini)))
        )
        let successUsage = UsageSnapshot(
            identity: nil,
            windows: [.init(id: "model-a", title: "model-a", window: .init(usedPercent: 10))],
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let successOutcome = ProviderAccountUsageOutcome(
            provider: .gemini,
            account: .default,
            outcome: .init(
                fetchKind: .oauth,
                result: .success(
                    .init(
                        usage: successUsage,
                        credits: nil,
                        cost: nil,
                        sourceLabel: "OAuth",
                        fetchKind: .oauth,
                        strategyKind: .direct
                    )
                )
            )
        )
        root.state.accountsEngine.outcomes = [failureOutcome, successOutcome]

        guard let selected = root.accountsViewModel.preferredUnifiedCardLiveOutcome else {
            Issue.record("Expected preferred unified card live outcome")
            return
        }
        if case .success = selected.outcome.result {
            #expect(true)
        } else {
            Issue.record("Expected success outcome to be preferred")
        }
    }
}
