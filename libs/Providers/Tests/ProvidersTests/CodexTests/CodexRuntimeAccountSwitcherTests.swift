import Foundation
import Testing
import STFilePath
@testable import CodexCLIKit
@testable import CodexAppServerKit
@testable import CodexProvider

private actor FakeRuntimeAccountService: CodexRuntimeAccountServing {
    private(set) var initializeCalls = 0
    private(set) var logoutCalls = 0

    func initialize(clientName: String, clientVersion: String) async throws {
        initializeCalls += 1
    }

    func switchAccount(idToken: String, accessToken: String, chatgptAccountID: String?) async throws {}

    func readAccount(refreshToken: Bool) async throws -> CodexRuntimeAccountState {
        CodexRuntimeAccountState(email: nil, planType: nil, requiresOpenaiAuth: false, authMode: nil)
    }

    func readRateLimits() async throws -> CodexRuntimeRateLimitsSnapshot {
        CodexRuntimeRateLimitsSnapshot(primary: nil, secondary: nil, credits: nil)
    }

    func logout() async throws {
        logoutCalls += 1
    }

    func shutdown() async {}

    func counts() -> (initialize: Int, logout: Int) {
        (initializeCalls, logoutCalls)
    }
}

@Suite("CodexRuntimeAccountSwitcher")
struct CodexRuntimeAccountSwitcherTests {
    @Test("Reuses cached service for same resolved binary")
    func reusesServiceByResolvedBinary() async throws {
        let fake = FakeRuntimeAccountService()
        let switcher = CodexRuntimeAccountSwitcher(serviceFactory: { _, _ in fake })

        let tempRoot = STFolder("/tmp").folder("codex-switcher-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeBinary = tempRoot.file("codex")
        try fakeBinary.overlay(with: "#!/bin/sh\nexit 0\n")
        try fakeBinary.set(permissions: .default)

        let env = ["CODEX_CLI_PATH": fakeBinary.url.path]
        try await switcher.logout(executable: "codex", environment: env)
        try await switcher.logout(executable: fakeBinary.url.path, environment: env)

        let counts = await fake.counts()
        #expect(counts.initialize == 1)
        #expect(counts.logout == 2)
    }
}
