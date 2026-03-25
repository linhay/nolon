import Foundation
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
        root.state.engine.claudeAccounts = [account]
        root.state.engine.activeClaudeAccountId = account.id

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: nil,
            isLoading: false
        )

        #expect(cards.count == 1)
        #expect(cards.first?.provider == .claude)
        #expect(cards.first?.isActive == true)
        #expect(root.accountsViewModel.unifiedAccountEmptyState != nil)
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
        root.state.engine.geminiAccounts = [account]
        root.state.engine.activeGeminiAccountId = account.id

        let cards = root.accountsViewModel.unifiedAccountCards(
            providerName: provider.name,
            liveOutcome: nil,
            isLoading: false
        )

        #expect(cards.count == 1)
        #expect(cards.first?.provider == .gemini)
        #expect(cards.first?.isActive == true)
        #expect(root.accountsViewModel.unifiedAccountEmptyState == nil)
    }
}
