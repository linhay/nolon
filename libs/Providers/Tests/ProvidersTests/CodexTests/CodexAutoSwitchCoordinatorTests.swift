import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("CodexAutoSwitchCoordinator")
struct CodexAutoSwitchCoordinatorTests {
    @Test("Given auto switch disabled, when evaluating, then returns disabled without activation")
    func disabledConfigDoesNotActivate() async throws {
        let activationCount = LockIsolated(0)
        let coordinator = CodexAutoSwitchCoordinator(
            config: CodexAutoSwitchConfig(enabled: false),
            loadState: { CodexAutoSwitchState() },
            saveState: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            activateAccount: { _, _ in activationCount.withValue { $0 += 1 } }
        )

        let decision = try await coordinator.evaluateAndSwitch(
            provider: makeProvider(),
            activeAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            candidates: [
                makeCandidate(
                    id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
                    usedPercent: 95
                )
            ]
        )

        #expect(decision.reason == .disabled)
        #expect(activationCount.value == 0)
    }

    @Test("Given active account still has quota, when evaluating, then keeps current account")
    func thresholdNotReachedDoesNotActivate() async throws {
        let activationCount = LockIsolated(0)
        let coordinator = CodexAutoSwitchCoordinator(
            config: CodexAutoSwitchConfig(enabled: true, thresholdPercent: 10),
            loadState: { CodexAutoSwitchState() },
            saveState: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            activateAccount: { _, _ in activationCount.withValue { $0 += 1 } }
        )

        let activeID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let decision = try await coordinator.evaluateAndSwitch(
            provider: makeProvider(),
            activeAccountID: activeID,
            candidates: [
                makeCandidate(id: activeID.uuidString, usedPercent: 80),
                makeCandidate(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", usedPercent: 20)
            ]
        )

        #expect(decision.reason == .thresholdNotReached)
        #expect(decision.fromAccountID == activeID)
        #expect(activationCount.value == 0)
    }

    @Test("Given active account is below threshold, when a better candidate exists, then activates the best candidate")
    func lowQuotaSwitchesToBestCandidate() async throws {
        let activatedAccountID = LockIsolated<UUID?>(nil)
        let savedState = LockIsolated<CodexAutoSwitchState?>(nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinator = CodexAutoSwitchCoordinator(
            config: CodexAutoSwitchConfig(
                enabled: true,
                thresholdPercent: 10,
                minimumCandidateRemainingPercent: 20,
                cooldown: 600
            ),
            loadState: { CodexAutoSwitchState() },
            saveState: { state in savedState.withValue { $0 = state } },
            now: { now },
            activateAccount: { account, _ in activatedAccountID.withValue { $0 = account.id } }
        )

        let activeID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let bestID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let decision = try await coordinator.evaluateAndSwitch(
            provider: makeProvider(),
            activeAccountID: activeID,
            candidates: [
                makeCandidate(id: activeID.uuidString, usedPercent: 95),
                makeCandidate(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", usedPercent: 70),
                makeCandidate(id: bestID.uuidString, usedPercent: 30)
            ]
        )

        #expect(decision.reason == .switched)
        #expect(decision.fromAccountID == activeID)
        #expect(decision.toAccountID == bestID)
        #expect(activatedAccountID.value == bestID)
        #expect(savedState.value?.lastSwitchedAtByProviderID[makeProvider().id] == now)
    }

    @Test("Given cooldown has not elapsed, when evaluating again, then does not switch")
    func cooldownBlocksRepeatedSwitch() async throws {
        let activationCount = LockIsolated(0)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = makeProvider()
        let coordinator = CodexAutoSwitchCoordinator(
            config: CodexAutoSwitchConfig(enabled: true, thresholdPercent: 10, cooldown: 600),
            loadState: {
                CodexAutoSwitchState(lastSwitchedAtByProviderID: [
                    provider.id: now.addingTimeInterval(-60)
                ])
            },
            saveState: { _ in },
            now: { now },
            activateAccount: { _, _ in activationCount.withValue { $0 += 1 } }
        )

        let decision = try await coordinator.evaluateAndSwitch(
            provider: provider,
            activeAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            candidates: [
                makeCandidate(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", usedPercent: 95),
                makeCandidate(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", usedPercent: 30)
            ]
        )

        #expect(decision.reason == .cooldownActive)
        #expect(activationCount.value == 0)
    }

    @Test("Given relay candidates are skipped, when evaluating, then relay accounts are not selected")
    func skipRelayCandidates() async throws {
        let activatedAccountID = LockIsolated<UUID?>(nil)
        let coordinator = CodexAutoSwitchCoordinator(
            config: CodexAutoSwitchConfig(
                enabled: true,
                thresholdPercent: 10,
                minimumCandidateRemainingPercent: 20,
                skipRelayAccounts: true
            ),
            loadState: { CodexAutoSwitchState() },
            saveState: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            activateAccount: { account, _ in activatedAccountID.withValue { $0 = account.id } }
        )

        let fallbackID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let decision = try await coordinator.evaluateAndSwitch(
            provider: makeProvider(),
            activeAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            candidates: [
                makeCandidate(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", usedPercent: 95),
                makeCandidate(
                    id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
                    usedPercent: 10,
                    cardKind: .relayProfile
                ),
                makeCandidate(id: fallbackID.uuidString, usedPercent: 50)
            ]
        )

        #expect(decision.reason == .switched)
        #expect(decision.toAccountID == fallbackID)
        #expect(activatedAccountID.value == fallbackID)
    }

    @Test("Given no candidate satisfies minimum remaining threshold, when evaluating, then returns no candidate")
    func noCandidateWhenAllRemainingTooLow() async throws {
        let activationCount = LockIsolated(0)
        let coordinator = CodexAutoSwitchCoordinator(
            config: CodexAutoSwitchConfig(
                enabled: true,
                thresholdPercent: 10,
                minimumCandidateRemainingPercent: 40
            ),
            loadState: { CodexAutoSwitchState() },
            saveState: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            activateAccount: { _, _ in activationCount.withValue { $0 += 1 } }
        )

        let decision = try await coordinator.evaluateAndSwitch(
            provider: makeProvider(),
            activeAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            candidates: [
                makeCandidate(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", usedPercent: 95),
                makeCandidate(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", usedPercent: 70),
                makeCandidate(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC", usedPercent: 75)
            ]
        )

        #expect(decision.reason == .noCandidate)
        #expect(activationCount.value == 0)
    }

    private func makeProvider() -> Provider {
        Provider(
            id: "codex-provider",
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
    }

    private func makeCandidate(
        id: String,
        usedPercent: Double,
        cardKind: CodexAuthSummary.CardKind? = .chatgptAccount
    ) -> CodexAutoSwitchCandidate {
        CodexAutoSwitchCandidate(
            account: CodexAuthAccount(
                id: UUID(uuidString: id)!,
                name: "acct-\(id.prefix(4))",
                createdAt: Date(timeIntervalSince1970: 1_699_000_000),
                relativeAuthPath: "auth/\(id).json"
            ),
            cardKind: cardKind,
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: usedPercent),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            isSchedulable: true,
            lastActivatedAt: nil
        )
    }
}

private final class LockIsolated<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func withValue(_ update: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        update(&_value)
    }
}
