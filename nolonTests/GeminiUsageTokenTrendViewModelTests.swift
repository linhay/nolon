import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class GeminiUsageTokenTrendViewModelTests: XCTestCase {
    func testBDD_GivenGeminiProvider_WhenRefreshingTokenTrend_ThenUsesSelectedRangeAndPublishesSnapshot() async throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()
        var receivedCalls: [(UsageProvider, Int?)] = []
        let expected = ProviderTokenTrendSnapshot(
            points: [
                ProviderTokenTrendPoint(
                    date: "2026-03-08",
                    totalTokens: 320,
                    inputTokens: 200,
                    outputTokens: 100,
                    cacheReadTokens: 20
                ),
            ],
            todayTokens: 320,
            last7DaysTokens: 320,
            last30DaysTokens: 320,
            allDaysTokens: 320,
            updatedAt: Date(timeIntervalSince1970: 1_709_900_000),
            sourceLabel: "session"
        )

        let viewModel = ProviderUsageViewModel(
            provider: provider,
            geminiTokenTrendFetchAction: { usageProvider, trailingDays in
                receivedCalls.append((usageProvider, trailingDays))
                return expected
            }
        )
        viewModel.tokenTrendRange = .days7

        await viewModel.refreshTokenTrendForTesting()

        XCTAssertEqual(receivedCalls.count, 1)
        XCTAssertEqual(receivedCalls.first?.0, .gemini)
        XCTAssertEqual(receivedCalls.first?.1, 7)
        XCTAssertEqual(viewModel.tokenTrendSnapshot, expected)
        XCTAssertNil(viewModel.tokenTrendErrorMessage)
        XCTAssertFalse(viewModel.isLoadingTokenTrend)
    }
}
