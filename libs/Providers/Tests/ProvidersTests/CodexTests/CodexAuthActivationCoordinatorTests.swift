import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("CodexAuthActivationCoordinator")
struct CodexAuthActivationCoordinatorTests {
    @Test("Given disk activation succeeds, when activating, then coordinator only writes disk activation state")
    func activateWritesDiskStateOnly() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let authCallCount = LockIsolated(0)

        let coordinator = CodexAuthActivationCoordinator(
            authActivate: { _, _ in authCallCount.withValue { $0 += 1 } }
        )

        try await coordinator.activate(account: account, provider: provider)

        #expect(authCallCount.value == 1)
    }

    @Test("Given auth activation fails, when activating, then propagates disk activation error")
    func activateWithAuthFailure() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        let coordinator = CodexAuthActivationCoordinator(
            authActivate: { _, _ in
                throw ActivationTestError.failed
            }
        )

        await #expect(throws: ActivationTestError.failed) {
            try await coordinator.activate(account: account, provider: provider)
        }
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

private enum ActivationTestError: Error, Equatable {
    case failed
}
