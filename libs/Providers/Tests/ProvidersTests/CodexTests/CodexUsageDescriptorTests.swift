import Foundation
import Testing
import CodexProvider
@testable import ProviderUsage

@Suite("Codex Usage Descriptor")
struct CodexUsageDescriptorTests {
    @Test("Formats status reset descriptions into localized labels")
    func formatStatusResetDescription() {
        #expect(CodexUsageDescriptor.formatStatusResetDescription("in 4h 51m") == "Resets in 4h 51m")
        #expect(CodexUsageDescriptor.formatStatusResetDescription("at 11:00 AM") == "Resets 11:00 AM")
        #expect(CodexUsageDescriptor.formatStatusResetDescription("soon") == "Resets soon")
    }

    @Test("Falls back to status probe when rate-limits fetch fails")
    func fallbackToStatusProbeOnRateLimitsFailure() async {
        enum SampleError: Error { case failed }

        let descriptor = CodexUsageDescriptor(
            fetchRateLimitsAndAccountInfo: { _ in
                throw SampleError.failed
            },
            fetchStatusSnapshot: { _ in
                CodexStatusSnapshot(
                    credits: 1234,
                    fiveHourPercentLeft: 80,
                    weeklyPercentLeft: 65,
                    fiveHourResetDescription: "in 2h",
                    weeklyResetDescription: "at 11:00 AM",
                    rawText: "status"
                )
            }
        )

        let context = ProviderFetchContext(
            provider: .codex,
            sourceMode: .auto,
            includeCredits: false,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: nil
        )

        let outcome = await descriptor.fetchOutcome(context: context)
        switch outcome.result {
        case let .success(result):
            #expect(result.strategyKind == ProviderFetchStrategyKind.fallback)
            #expect(result.usage.primary?.usedPercent == 20)
            #expect(result.usage.secondary?.usedPercent == 35)
            #expect(result.usage.primary?.resetDescription == "Resets in 2h")
            #expect(result.usage.secondary?.resetDescription == "Resets 11:00 AM")
        case let .failure(error):
            Issue.record("Expected fallback success, got failure: \(error)")
        }
    }

    @Test("Prefers HTTP usage query when configured and skips CLI fetch")
    func prefersHTTPUsageQuery() async {
        let descriptor = CodexUsageDescriptor(
            fetchHTTPUsageResult: { _ in
                ProviderFetchResult(
                    usage: UsageSnapshot(
                        identity: UsageIdentity(accountEmail: nil, accountOrganization: nil, loginMethod: "relay", plan: "Enterprise"),
                        primary: RateWindow(usedPercent: 20),
                        secondary: nil,
                        tertiary: nil,
                        updatedAt: Date()
                    ),
                    credits: CreditsSnapshot(remaining: 12),
                    cost: nil,
                    sourceLabel: "HTTP",
                    fetchKind: .web,
                    strategyKind: .direct
                )
            },
            fetchRateLimitsAndAccountInfo: { _ in
                Issue.record("CLI rate-limit fetch should not run when HTTP query succeeds")
                throw ProviderUsageError.unsupported(.codex)
            },
            fetchStatusSnapshot: { _ in
                Issue.record("Status probe should not run when HTTP query succeeds")
                return CodexStatusSnapshot(credits: nil, fiveHourPercentLeft: nil, weeklyPercentLeft: nil, fiveHourResetDescription: nil, weeklyResetDescription: nil, rawText: "")
            }
        )

        let context = ProviderFetchContext(
            provider: .codex,
            sourceMode: .auto,
            includeCredits: true,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: nil
        )

        let outcome = await descriptor.fetchOutcome(context: context)
        switch outcome.result {
        case let .success(result):
            #expect(outcome.fetchKind == ProviderFetchKind.web)
            #expect(result.sourceLabel == "HTTP")
            #expect(result.usage.identity?.plan == "Enterprise")
            #expect(result.credits?.remaining == 12)
        case let .failure(error):
            Issue.record("Expected HTTP success, got failure: \(error)")
        }
    }

    @Test("Returns HTTP failure without falling back to CLI when query is enabled")
    func returnsHTTPFailureWithoutCLIFallback() async {
        let descriptor = CodexUsageDescriptor(
            fetchHTTPUsageResult: { _ in
                throw CodexHTTPUsageQueryError.httpStatus(401, message: "unauthorized")
            },
            fetchRateLimitsAndAccountInfo: { _ in
                Issue.record("CLI fetch should not run after HTTP failure")
                throw ProviderUsageError.unsupported(.codex)
            },
            fetchStatusSnapshot: { _ in
                Issue.record("Status probe should not run after HTTP failure")
                return CodexStatusSnapshot(credits: nil, fiveHourPercentLeft: nil, weeklyPercentLeft: nil, fiveHourResetDescription: nil, weeklyResetDescription: nil, rawText: "")
            }
        )

        let context = ProviderFetchContext(
            provider: .codex,
            sourceMode: .auto,
            includeCredits: true,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: nil
        )

        let outcome = await descriptor.fetchOutcome(context: context)
        switch outcome.result {
        case .success:
            Issue.record("Expected HTTP failure")
        case let .failure(error):
            #expect(outcome.fetchKind == ProviderFetchKind.web)
            #expect(error as? CodexHTTPUsageQueryError == .httpStatus(401, message: "unauthorized"))
        }
    }
}
