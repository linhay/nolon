import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("CodexAutoSwitchService")
struct CodexAutoSwitchServiceTests {
    @Test("Given active account is low on quota, when service evaluates from usage caches, then it activates the best cached candidate")
    func evaluatesFromAuthManagerData() async throws {
        let provider = makeProvider()
        let activeID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let betterID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let activated = LockIsolated<UUID?>(nil)
        let savedState = LockIsolated<CodexAutoSwitchState?>(nil)

        let service = CodexAutoSwitchService(
            coordinator: CodexAutoSwitchCoordinator(
                config: CodexAutoSwitchConfig(enabled: true, thresholdPercent: 10, minimumCandidateRemainingPercent: 20),
                loadState: { CodexAutoSwitchState() },
                saveState: { state in savedState.withValue { $0 = state } },
                now: { Date(timeIntervalSince1970: 1_700_000_000) },
                activateAccount: { account, _ in activated.withValue { $0 = account.id } }
            ),
            loadAccounts: {
                [
                    makeAccount(id: activeID),
                    makeAccount(id: betterID)
                ]
            },
            activeAccountID: { _ in activeID },
            loadUsageCache: { account in
                switch account.id {
                case activeID:
                    return makeUsageCache(usedPercent: 95)
                case betterID:
                    return makeUsageCache(usedPercent: 30)
                default:
                    return nil
                }
            },
            loadSummary: { account in
                if account.id == betterID {
                    return CodexAuthSummary(cardKind: .chatgptAccount)
                }
                return CodexAuthSummary(cardKind: .chatgptAccount)
            }
        )

        let decision = try await service.evaluateAndSwitchIfNeeded(for: provider)

        #expect(decision.reason == .switched)
        #expect(decision.fromAccountID == activeID)
        #expect(decision.toAccountID == betterID)
        #expect(activated.value == betterID)
        #expect(savedState.value?.lastSwitchedAtByProviderID[provider.id] != nil)
    }

    @Test("Given a decision is produced, when service completes evaluation, then it records latest status and event")
    func recordsEventAndStatusSnapshot() async throws {
        let provider = makeProvider()
        let eventStore = InMemoryEventStore()
        let statusStore = InMemoryStatusStore()

        let service = CodexAutoSwitchService(
            coordinator: CodexAutoSwitchCoordinator(
                config: CodexAutoSwitchConfig(enabled: true, thresholdPercent: 10),
                loadState: { CodexAutoSwitchState() },
                saveState: { _ in },
                now: { Date(timeIntervalSince1970: 1_700_000_500) },
                activateAccount: { _, _ in }
            ),
            loadAccounts: {
                [makeAccount(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)]
            },
            activeAccountID: { _ in UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")! },
            loadUsageCache: { _ in makeUsageCache(usedPercent: 80) },
            loadSummary: { _ in CodexAuthSummary(cardKind: .chatgptAccount) },
            config: CodexAutoSwitchConfig(enabled: true, thresholdPercent: 10),
            statusStore: statusStore,
            eventStore: eventStore
        )

        let decision = try await service.evaluateAndSwitchIfNeeded(for: provider)
        let snapshot = await statusStore.snapshot
        let events = await eventStore.events

        #expect(decision.reason == .thresholdNotReached)
        #expect(snapshot?.providerID == provider.id)
        #expect(snapshot?.lastDecision == decision)
        #expect(events.count == 1)
        #expect(events.first?.reason == .thresholdNotReached)
    }

    @Test("Given there is no active account, when service evaluates, then it returns no active account")
    func returnsNoActiveAccountWhenMissing() async throws {
        let service = CodexAutoSwitchService(
            coordinator: CodexAutoSwitchCoordinator(
                config: CodexAutoSwitchConfig(enabled: true),
                loadState: { CodexAutoSwitchState() },
                saveState: { _ in },
                now: { Date(timeIntervalSince1970: 1_700_000_000) },
                activateAccount: { _, _ in }
            ),
            loadAccounts: { [] },
            activeAccountID: { _ in nil },
            loadUsageCache: { _ in nil },
            loadSummary: { _ in CodexAuthSummary() }
        )

        let decision = try await service.evaluateAndSwitchIfNeeded(for: makeProvider())

        #expect(decision.reason == .noActiveAccount)
        #expect(decision.fromAccountID == nil)
        #expect(decision.toAccountID == nil)
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

    private func makeAccount(id: UUID) -> CodexAuthAccount {
        CodexAuthAccount(
            id: id,
            name: "acct-\(id.uuidString.prefix(4))",
            createdAt: Date(timeIntervalSince1970: 1_699_000_000),
            relativeAuthPath: "auth/\(id.uuidString).json"
        )
    }

    private func makeUsageCache(usedPercent: Double) -> CodexAuthUsageCache {
        CodexAuthUsageCache(
            fetchKind: .oauth,
            strategyKind: .direct,
            sourceLabel: "test",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: usedPercent),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            credits: nil,
            cost: nil
        )
    }
}

private actor InMemoryEventStore: CodexAutoSwitchEventStoring {
    private(set) var events: [CodexAutoSwitchEvent] = []

    func append(_ event: CodexAutoSwitchEvent) async throws {
        events.append(event)
    }

    func recentEvents(limit: Int) async -> [CodexAutoSwitchEvent] {
        Array(events.suffix(limit).reversed())
    }
}

private actor InMemoryStatusStore: CodexAutoSwitchStatusStoring {
    private(set) var snapshot: CodexAutoSwitchStatusSnapshot?

    func load() async -> CodexAutoSwitchStatusSnapshot? {
        snapshot
    }

    func save(_ snapshot: CodexAutoSwitchStatusSnapshot) async throws {
        self.snapshot = snapshot
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
