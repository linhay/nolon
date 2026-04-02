import Foundation
import Observation
import Testing
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

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

        var didObserveChange = false
        withObservationTracking {
            _ = root.accountsViewModel.claude.isShowingEditor
            _ = root.accountsViewModel.claude.editorDraft
        } onChange: {
            didObserveChange = true
        }

        root.accountsViewModel.claude.beginEditAccount(id: account.id)

        #expect(didObserveChange == true)
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
        root.state.commonEngine.outcomes = [failureOutcome, successOutcome]

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
