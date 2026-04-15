import Foundation
import Testing
import CopilotProvider
@testable import ProviderUsage

@Suite("Copilot Usage Descriptor")
struct CopilotUsageDescriptorTests {
    @Test("Builds chat and premium windows from fetched snapshot")
    func fetchOutcome_buildsNamedWindows() async {
        let now = Date(timeIntervalSince1970: 1_776_000_000)
        let descriptor = CopilotUsageDescriptor(
            fetchUsage: { token in
                #expect(token == "ghu_test_token")
                return CopilotUsageSnapshot(
                    plan: "copilot-pro",
                    viewer: CopilotViewerProfile(
                        login: "linhay",
                        name: "Lin Hay",
                        email: nil
                    ),
                    premiumQuota: CopilotQuota(
                        feature: "premium_interactions",
                        total: 100,
                        remaining: 80,
                        percentRemaining: 80
                    ),
                    chatQuota: CopilotQuota(
                        feature: "chat",
                        total: 100,
                        remaining: 65,
                        percentRemaining: 65
                    ),
                    quotaResetDate: "2026-04-16T00:00:00Z",
                    updatedAt: now
                )
            }
        )
        let context = ProviderFetchContext(
            provider: .copilot,
            sourceMode: .apiToken,
            includeCredits: false,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: "ghu_test_token"
        )

        let outcome = await descriptor.fetchOutcome(context: context)

        switch outcome.result {
        case let .success(result):
            #expect(outcome.fetchKind == .apiToken)
            #expect(result.fetchKind == .apiToken)
            #expect(result.usage.identity?.accountEmail == "linhay")
            #expect(result.usage.identity?.accountOrganization == "Lin Hay")
            #expect(result.usage.identity?.loginMethod == "GitHub")
            #expect(result.usage.identity?.plan == "Copilot Pro")
            #expect(result.usage.windows.map(\.id) == ["chat", "premium"])
            #expect(result.usage.windows.map(\.title) == ["Chat", "Premium"])
            #expect(abs((result.usage.primary?.usedPercent ?? -1) - 35) < 0.0001)
            #expect(abs((result.usage.secondary?.usedPercent ?? -1) - 20) < 0.0001)
            #expect(result.usage.updatedAt == now)
        case let .failure(error):
            Issue.record("Expected success for copilot descriptor, got failure: \(error)")
        }
    }

    @Test("Returns missing token error when api token is absent")
    func fetchOutcome_missingToken() async {
        let descriptor = CopilotUsageDescriptor()
        let context = ProviderFetchContext(
            provider: .copilot,
            sourceMode: .apiToken,
            includeCredits: false,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: nil
        )

        let outcome = await descriptor.fetchOutcome(context: context)

        switch outcome.result {
        case .success:
            Issue.record("Expected missing token failure for copilot descriptor")
        case let .failure(error):
            #expect(outcome.fetchKind == .apiToken)
            #expect(error as? ProviderUsageError == .missingToken(.copilot))
        }
    }

    @Test("Humanizes individual plan and keeps login as primary account label")
    func fetchOutcome_humanizesIndividualPlan() async {
        let descriptor = CopilotUsageDescriptor(
            fetchUsage: { _ in
                CopilotUsageSnapshot(
                    plan: "individual",
                    viewer: CopilotViewerProfile(
                        login: "octocat",
                        name: "The Octocat",
                        email: "octocat@github.com"
                    ),
                    premiumQuota: nil,
                    chatQuota: CopilotQuota(
                        feature: "chat",
                        total: 100,
                        remaining: 90,
                        percentRemaining: 90
                    ),
                    quotaResetDate: "2026-04-16T00:00:00Z"
                )
            }
        )
        let context = ProviderFetchContext(
            provider: .copilot,
            sourceMode: .apiToken,
            includeCredits: false,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: "ghu_test_token"
        )

        let outcome = await descriptor.fetchOutcome(context: context)

        switch outcome.result {
        case let .success(result):
            #expect(result.usage.identity?.accountEmail == "octocat")
            #expect(result.usage.identity?.accountOrganization == "The Octocat")
            #expect(result.usage.identity?.plan == "Individual")
        case let .failure(error):
            Issue.record("Expected success for copilot descriptor, got failure: \(error)")
        }
    }
}
