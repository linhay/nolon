import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

actor ClaudeUsageCallRecorder {
    private var calls: [Int?] = []

    func record(trailingDays: Int?) {
        calls.append(trailingDays)
    }

    func allCalls() -> [Int?] {
        calls
    }
}

@MainActor
final class ClaudeUsageTokenTrendViewModelTests: XCTestCase {
    func testBDD_GivenClaudeUsageInitialLoad_WhenTrendDataIsStillEmpty_ThenShowsTokenTrendSkeleton() throws {
        let provider = ProviderTemplate.claudeCode.createProvider()
        let viewModel = ProviderUsageEngine(provider: provider)

        viewModel.isLoading = true

        XCTAssertTrue(viewModel.shouldShowTokenTrendLoadingSkeleton)
    }

    func testBDD_GivenClaudeProvider_WhenRefreshingTokenTrend_ThenUsesSelectedRangeAndPublishesSnapshot() async throws {
        let provider = ProviderTemplate.claudeCode.createProvider()
        let recorder = ClaudeUsageCallRecorder()
        let expected = ProviderTokenTrendSnapshot(
            points: [
                ProviderTokenTrendPoint(
                    date: "2026-03-08",
                    totalTokens: 225,
                    inputTokens: 130,
                    outputTokens: 90,
                    cacheReadTokens: 5
                ),
            ],
            todayTokens: 225,
            last7DaysTokens: 225,
            last30DaysTokens: 225,
            allDaysTokens: 225,
            updatedAt: Date(timeIntervalSince1970: 1_775_000_000),
            sourceLabel: "session"
        )

        let viewModel = ProviderUsageEngine(
            provider: provider,
            claudeTokenTrendFetchAction: { trailingDays in
                await recorder.record(trailingDays: trailingDays)
                return expected
            }
        )
        viewModel.tokenTrendRange = ProviderUsageEngine.TokenTrendRange.days7

        await viewModel.refreshTokenTrendForTesting()

        let receivedCalls = await recorder.allCalls()
        XCTAssertEqual(receivedCalls, [7])
        XCTAssertEqual(viewModel.tokenTrendSnapshot, expected)
        XCTAssertNil(viewModel.tokenTrendErrorMessage)
        XCTAssertFalse(viewModel.isLoadingTokenTrend)
    }

    func testBDD_GivenClaudeSelectedDay_WhenRefreshingIntraday_ThenPublishesIntradaySnapshot() async throws {
        let provider = ProviderTemplate.claudeCode.createProvider()
        let expected = ProviderIntradayUsageSnapshot(
            dayKey: "2026-03-08",
            timezoneIdentifier: TimeZone.current.identifier,
            bucket: .minute30,
            actualBucketCount: 2,
            rangeStart: Date(timeIntervalSince1970: 1_709_856_000),
            rangeEnd: Date(timeIntervalSince1970: 1_709_859_600),
            points: [
                ProviderIntradayUsagePoint(
                    start: Date(timeIntervalSince1970: 1_709_856_000),
                    end: Date(timeIntervalSince1970: 1_709_857_800),
                    totalTokens: 140,
                    inputTokens: 100,
                    outputTokens: 30,
                    cacheReadTokens: 10
                ),
                ProviderIntradayUsagePoint(
                    start: Date(timeIntervalSince1970: 1_709_857_800),
                    end: Date(timeIntervalSince1970: 1_709_859_600),
                    totalTokens: 90,
                    inputTokens: 60,
                    outputTokens: 20,
                    cacheReadTokens: 10
                ),
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_775_000_000),
            sourceLabel: "session"
        )

        let viewModel = ProviderUsageEngine(
            provider: provider,
            providerIntradayFetchAction: { usageProvider, dayKey, bucket in
                XCTAssertEqual(usageProvider, .claude)
                XCTAssertEqual(dayKey, expected.dayKey)
                XCTAssertEqual(bucket, .minute30)
                return expected
            }
        )
        viewModel.selectTokenTrendDay(expected.dayKey)

        await viewModel.refreshIntradayForTesting()

        XCTAssertEqual(viewModel.intradaySnapshot, expected)
        XCTAssertNil(viewModel.intradayErrorMessage)
        XCTAssertFalse(viewModel.isLoadingIntraday)
    }
}
