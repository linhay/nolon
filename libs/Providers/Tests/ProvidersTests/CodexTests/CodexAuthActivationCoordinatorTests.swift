import Foundation
import Testing
import ProviderCatalog
@testable import ProviderUsage

@Suite("CodexAuthActivationCoordinator")
struct CodexAuthActivationCoordinatorTests {
    @Test("Given disk activation succeeds, when activating, then only disk state changes and runtime is not switched")
    func activateSkipsRuntimeByDefault() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let authCallCount = LockIsolated(0)
        let runtimeCallCount = LockIsolated(0)

        let coordinator = CodexAuthActivationCoordinator(
            authActivate: { _, _ in authCallCount.withValue { $0 += 1 } },
            runtimeActivate: { _ in runtimeCallCount.withValue { $0 += 1 } }
        )

        let result = try await coordinator.activate(account: account, provider: provider)

        #expect(result == CodexAuthActivationResult(runtimeSwitched: false, runtimeErrorDescription: nil))
        #expect(authCallCount.value == 1)
        #expect(runtimeCallCount.value == 0)
    }

    @Test("Given manual runtime activation succeeds, when triggering runtime activation, then returns runtime switched")
    func activateRuntimeSuccess() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let runtimeCallCount = LockIsolated(0)

        let coordinator = CodexAuthActivationCoordinator(
            authActivate: { _, _ in _ = provider },
            runtimeActivate: { _ in runtimeCallCount.withValue { $0 += 1 } }
        )

        let result = await coordinator.activateRuntime(account: account)

        #expect(result.runtimeSwitched == true)
        #expect(result.runtimeErrorDescription == nil)
        #expect(runtimeCallCount.value == 1)
    }

    @Test("Given manual runtime activation fails, when triggering runtime activation, then keeps disk activation result and returns runtime error")
    func activateRuntimeFailure() async throws {
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        let coordinator = CodexAuthActivationCoordinator(
            authActivate: { _, _ in },
            runtimeActivate: { _ in
                throw CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: "simulated")
            }
        )

        let result = await coordinator.activateRuntime(account: account)

        #expect(result.runtimeSwitched == false)
        #expect(result.runtimeErrorDescription?.contains("simulated") == true)
    }

    @Test("Given auth activation fails, when activating, then throws and runtime is not called")
    func activateWithAuthFailure() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let runtimeCallCount = LockIsolated(0)

        let coordinator = CodexAuthActivationCoordinator(
            authActivate: { _, _ in
                throw CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: "auth write failed")
            },
            runtimeActivate: { _ in
                runtimeCallCount.withValue { $0 += 1 }
            }
        )

        await #expect(throws: CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: "auth write failed")) {
            _ = try await coordinator.activate(account: account, provider: provider)
        }
        #expect(runtimeCallCount.value == 0)
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
