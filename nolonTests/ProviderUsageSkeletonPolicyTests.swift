import Testing
import ProviderCatalog
@testable import nolon

struct ProviderUsageSkeletonPolicyTests {
    @Test("BDD: Given Gemini provider when resolving generic skeleton count then returns three cards")
    func testBDD_GivenGeminiProvider_WhenResolvingGenericSkeletonCount_ThenReturnsThreeCards() {
        let provider = Provider(
            id: "gemini",
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            templateId: ProviderTemplate.gemini.rawValue
        )

        #expect(ProviderUsageSkeletonPolicy.genericCardCount(for: provider) == 3)
    }

    @Test("BDD: Given Codex provider when resolving generic skeleton count then matches Gemini count")
    func testBDD_GivenCodexProvider_WhenResolvingGenericSkeletonCount_ThenMatchesGeminiCount() {
        let provider = Provider(
            id: "codex",
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            templateId: ProviderTemplate.codex.rawValue
        )

        #expect(ProviderUsageSkeletonPolicy.genericCardCount(for: provider) == 3)
    }

    @Test("BDD: Given non Gemini provider when resolving generic skeleton count then returns three cards")
    func testBDD_GivenNonGeminiProvider_WhenResolvingGenericSkeletonCount_ThenReturnsThreeCards() {
        let provider = Provider(
            id: "claude",
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/prompts",
            templateId: ProviderTemplate.claudeCode.rawValue
        )

        #expect(ProviderUsageSkeletonPolicy.genericCardCount(for: provider) == 3)
    }

    @Test("BDD: Given shared loading sections when resolving static skeleton counts then uses stable defaults")
    func testBDD_GivenSharedLoadingSections_WhenResolvingStaticSkeletonCounts_ThenUsesStableDefaults() {
        #expect(ProviderUsageSkeletonPolicy.tokenTrendSummaryCount == 4)
        #expect(ProviderUsageSkeletonPolicy.tokenTrendChartBarCount == 7)
        #expect(ProviderUsageSkeletonPolicy.tokenTrendTableRowCount == 5)
    }
}
