import Foundation
import Testing
import STFilePath
@testable import CodexCLIKit
@testable import CodexAppServerKit
@testable import CodexProvider

private actor FakeRuntimeAccountService: CodexRuntimeAccountServing {
    private(set) var initializeCalls = 0
    private(set) var logoutCalls = 0
    var switchError: Error?

    func setSwitchError(_ error: Error?) {
        switchError = error
    }

    func initialize(clientName: String, clientVersion: String) async throws {
        initializeCalls += 1
    }

    func switchAccount(idToken: String, accessToken: String, chatgptAccountID: String?) async throws {
        if let switchError {
            throw switchError
        }
    }

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

    @Test("Maps account runtime typed error into categorized protocol error")
    func mapsTypedServiceErrorIntoProtocolCategory() async throws {
        let fake = FakeRuntimeAccountService()
        await fake.setSwitchError(CodexAccountRuntimeServiceError.loginStartMissingLoginID)
        let switcher = CodexRuntimeAccountSwitcher(serviceFactory: { _, _ in fake })

        let tokens = CodexTokenPair(idToken: "id", accessToken: "access", chatgptAccountID: nil)
        do {
            _ = try await switcher.switchAccount(tokens: tokens, executable: "codex", environment: [:])
            Issue.record("Expected protocol error")
        } catch let error as CodexCLIError {
            guard case let .protocolError(message) = error else {
                Issue.record("Expected protocolError, got: \(error)")
                return
            }
            #expect(message.contains("account/login_start_missing_login_id"))
        } catch {
            Issue.record("Expected CodexCLIError, got: \(error)")
        }
    }
}
