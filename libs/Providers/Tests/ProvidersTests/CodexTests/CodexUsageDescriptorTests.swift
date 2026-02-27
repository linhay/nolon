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
}
