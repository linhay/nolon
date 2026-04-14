import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

actor GeminiUsageCallRecorder {
    private var calls: [(UsageProvider, Int?)] = []

    func record(_ usageProvider: UsageProvider, trailingDays: Int?) {
        calls.append((usageProvider, trailingDays))
    }

    func allCalls() -> [(UsageProvider, Int?)] {
        calls
    }
}

@MainActor
final class GeminiUsageTokenTrendViewModelTests: XCTestCase {
    func testBDD_GivenGeminiUsageInitialLoad_WhenTrendDataIsStillEmpty_ThenShowsTokenTrendSkeleton() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()
        let viewModel = ProviderUsageEngine(provider: provider)

        viewModel.isLoading = true

        XCTAssertTrue(viewModel.shouldShowTokenTrendLoadingSkeleton)
    }

    func testBDD_GivenGeminiTrendSnapshot_WhenPageStillLoading_ThenKeepsRenderedTrendInsteadOfSkeleton() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.tokenTrendSnapshot = ProviderTokenTrendSnapshot(
            points: [],
            todayTokens: 10,
            last7DaysTokens: 20,
            last30DaysTokens: 30,
            allDaysTokens: 40,
            updatedAt: Date(timeIntervalSince1970: 1_709_900_000),
            sourceLabel: "session"
        )
        viewModel.isLoading = true

        XCTAssertFalse(viewModel.shouldShowTokenTrendLoadingSkeleton)
    }

    func testBDD_GivenGeminiProvider_WhenRefreshingTokenTrend_ThenUsesSelectedRangeAndPublishesSnapshot() async throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()
        let recorder = GeminiUsageCallRecorder()
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

        let viewModel = ProviderUsageEngine(
            provider: provider,
            geminiTokenTrendFetchAction: { usageProvider, trailingDays in
                await recorder.record(usageProvider, trailingDays: trailingDays)
                return expected
            }
        )
        viewModel.tokenTrendRange = .days7

        await viewModel.refreshTokenTrendForTesting()

        let receivedCalls = await recorder.allCalls()
        XCTAssertEqual(receivedCalls.count, 1)
        XCTAssertEqual(receivedCalls.first?.0, .gemini)
        XCTAssertEqual(receivedCalls.first?.1, 7)
        XCTAssertEqual(viewModel.tokenTrendSnapshot, expected)
        XCTAssertNil(viewModel.tokenTrendErrorMessage)
        XCTAssertFalse(viewModel.isLoadingTokenTrend)
    }

    func testBDD_GivenGeminiSelectedDay_WhenRefreshingIntraday_ThenPublishesIntradaySnapshot() async throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()
        let expected = ProviderIntradayUsageSnapshot(
            dayKey: "2026-03-08",
            timezoneIdentifier: TimeZone.current.identifier,
            bucket: .minute30,
            actualBucketCount: 48,
            rangeStart: Date(timeIntervalSince1970: 1_709_856_000),
            rangeEnd: Date(timeIntervalSince1970: 1_709_942_400),
            points: [
                ProviderIntradayUsagePoint(
                    start: Date(timeIntervalSince1970: 1_709_856_000),
                    end: Date(timeIntervalSince1970: 1_709_857_800),
                    totalTokens: 140,
                    inputTokens: 100,
                    outputTokens: 30,
                    cacheReadTokens: 10
                )
            ] + Array(
                repeating: ProviderIntradayUsagePoint(
                    start: Date(timeIntervalSince1970: 1_709_857_800),
                    end: Date(timeIntervalSince1970: 1_709_859_600),
                    totalTokens: 0,
                    inputTokens: 0,
                    outputTokens: 0,
                    cacheReadTokens: 0
                ),
                count: 47
            ),
            fetchedAt: Date(timeIntervalSince1970: 1_709_900_000),
            sourceLabel: "session"
        )

        let viewModel = ProviderUsageEngine(
            provider: provider,
            providerIntradayFetchAction: { usageProvider, dayKey, bucket in
                XCTAssertEqual(usageProvider, .gemini)
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
