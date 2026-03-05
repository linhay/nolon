import Foundation
import Testing
@testable import ProviderUsage

@Suite("Gemini Usage Descriptor")
struct GeminiUsageDescriptorTests {
    @Test("Returns missingAccount error when no active account exists")
    func fetchOutcome_missingAccountWithoutActiveSession() async {
        let descriptor = GeminiUsageDescriptor(
            provider: .gemini,
            now: Date.init,
            loadActiveAccount: { _ in nil }
        )
        let context = ProviderFetchContext(
            provider: .gemini,
            sourceMode: .auto,
            includeCredits: false,
            timeout: 20,
            costWindowDays: 30,
            environment: [:],
            token: nil
        )

        let outcome = await descriptor.fetchOutcome(context: context)
        switch outcome.result {
        case .success:
            Issue.record("Expected failure when no active account exists")
        case let .failure(error):
            #expect(outcome.fetchKind == ProviderFetchKind.cli)
            #expect(error as? ProviderUsageError == .missingAccount(.gemini))
        }
    }

    @Test("Returns success snapshot for active OAuth account")
    func fetchOutcome_successForOAuthAccount() async {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            providerID: .gemini,
            name: "Gemini Main",
            method: .oauthPersonal,
            createdAt: now,
            lastUsedAt: now,
            lastLoginAt: now,
            email: "dev@example.com",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: "accounts/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/home"
        )
        let descriptor = GeminiUsageDescriptor(
            provider: .gemini,
            now: { now },
            loadActiveAccount: { provider in
                #expect(provider == .gemini)
                return account
            }
        )
        let context = ProviderFetchContext(
            provider: .gemini,
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
            #expect(outcome.fetchKind == ProviderFetchKind.cli)
            #expect(result.fetchKind == ProviderFetchKind.oauth)
            #expect(result.strategyKind == ProviderFetchStrategyKind.direct)
            #expect(result.usage.identity?.accountEmail == "dev@example.com")
            #expect(result.usage.identity?.loginMethod == "oauth")
            #expect(result.usage.identity?.plan == "oauth-personal")
            #expect(result.usage.primary == nil)
            #expect(result.usage.updatedAt == now)
        case let .failure(error):
            Issue.record("Expected success for active oauth account, got failure: \(error)")
        }
    }

    @Test("Returns success snapshot for active Vertex account")
    func fetchOutcome_successForVertexAccount() async {
        let now = Date(timeIntervalSince1970: 1_715_123_456)
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            providerID: .antigravity,
            name: "Antigravity Vertex",
            method: .vertexAI,
            createdAt: now,
            lastUsedAt: now,
            lastLoginAt: now,
            email: nil,
            project: "proj-1",
            location: "us-central1",
            runtimeHomeRelativePath: "accounts/11111111-2222-3333-4444-555555555555/home"
        )
        let descriptor = GeminiUsageDescriptor(
            provider: .antigravity,
            now: { now },
            loadActiveAccount: { _ in account }
        )
        let context = ProviderFetchContext(
            provider: .antigravity,
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
            #expect(outcome.fetchKind == ProviderFetchKind.cli)
            #expect(result.fetchKind == ProviderFetchKind.cli)
            #expect(result.usage.identity?.accountOrganization == "proj-1@us-central1")
            #expect(result.usage.identity?.loginMethod == "vertex")
            #expect(result.usage.identity?.plan == "vertex-ai")
        case let .failure(error):
            Issue.record("Expected success for active vertex account, got failure: \(error)")
        }
    }

}
