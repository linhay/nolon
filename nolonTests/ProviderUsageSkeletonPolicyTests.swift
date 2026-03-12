import Testing
import ProviderCatalog
@testable import nolon

struct ProviderUsageSkeletonPolicyTests {
    @Test("BDD: Given Gemini provider when resolving generic skeleton count then returns two cards")
    func testBDD_GivenGeminiProvider_WhenResolvingGenericSkeletonCount_ThenReturnsTwoCards() {
        let provider = Provider(
            id: "gemini",
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            templateId: ProviderTemplate.gemini.rawValue
        )

        #expect(ProviderUsageSkeletonPolicy.genericCardCount(for: provider) == 2)
    }

    @Test("BDD: Given non Gemini provider when resolving generic skeleton count then returns one card")
    func testBDD_GivenNonGeminiProvider_WhenResolvingGenericSkeletonCount_ThenReturnsOneCard() {
        let provider = Provider(
            id: "claude",
            name: "Claude",
            defaultSkillsPath: "/tmp/claude/skills",
            workflowPath: "/tmp/claude/prompts",
            templateId: ProviderTemplate.claudeCode.rawValue
        )

        #expect(ProviderUsageSkeletonPolicy.genericCardCount(for: provider) == 1)
    }

    @Test("BDD: Given shared loading sections when resolving static skeleton counts then uses stable defaults")
    func testBDD_GivenSharedLoadingSections_WhenResolvingStaticSkeletonCounts_ThenUsesStableDefaults() {
        #expect(ProviderUsageSkeletonPolicy.codexCardCount == 3)
        #expect(ProviderUsageSkeletonPolicy.tokenTrendSummaryCount == 4)
        #expect(ProviderUsageSkeletonPolicy.tokenTrendChartBarCount == 7)
    }
}
