import Foundation
import Testing
import CodexCLIKit
@testable import ProviderUsage

@Suite("CodexAuthRuntimeCoordinator")
struct CodexAuthRuntimeCoordinatorTests {
    @Test("Given account tokens, when activating runtime, then switch is invoked with account tokens")
    func activateRuntimeUsesTokenPair() async throws {
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let expectedExecutable = "/tmp/codex"
        let expectedEnv = ["CODEX_HOME": "/tmp/codex-home"]
        let box = LockIsolated<[String]>([])

        let coordinator = CodexAuthRuntimeCoordinator(
            tokenReader: { _ in ("id-token", "access-token") },
            runtimeSwitch: { idToken, accessToken, executable, environment in
                box.withValue {
                    $0 = [idToken, accessToken, executable, environment["CODEX_HOME"] ?? ""]
                }
            }
        )

        try await coordinator.activateAccountInRuntime(
            account: account,
            executable: expectedExecutable,
            environment: expectedEnv
        )

        let values = box.value
        #expect(values == ["id-token", "access-token", expectedExecutable, "/tmp/codex-home"])
    }

    @Test("Given missing token pair, when activating runtime, then throws tokenPairMissing and does not switch")
    func missingTokenPairThrows() async {
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let switchCallCount = LockIsolated(0)

        let coordinator = CodexAuthRuntimeCoordinator(
            tokenReader: { _ in nil },
            runtimeSwitch: { _, _, _, _ in
                switchCallCount.withValue { $0 += 1 }
            }
        )

        await #expect(throws: CodexAuthRuntimeCoordinatorError.tokenPairMissing(accountID: account.id)) {
            try await coordinator.activateAccountInRuntime(account: account)
        }
        #expect(switchCallCount.value == 0)
    }

    @Test("Given runtime switch failure, when activating runtime, then throws runtimeSwitchFailed")
    func runtimeSwitchFailureMapped() async {
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        let coordinator = CodexAuthRuntimeCoordinator(
            tokenReader: { _ in ("id-token", "access-token") },
            runtimeSwitch: { _, _, _, _ in
                throw CodexCLIError.launchFailed("simulated boom")
            }
        )

        await #expect(throws: CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: "Failed to launch codex: simulated boom")) {
            try await coordinator.activateAccountInRuntime(account: account)
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
