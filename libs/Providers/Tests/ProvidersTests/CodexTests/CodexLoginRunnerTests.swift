import Foundation
import Testing
import STFilePath
@testable import CodexProvider
@testable import CodexCLIKit

@Suite("CodexLoginRunner")
struct CodexLoginRunnerTests {
    @Test("startLogin prefers CODEX_CLI_PATH and injects CODEX_HOME")
    func startLoginPrefersEnvBinaryOverride() throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-runner-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let marker = tempRoot.file("marker.txt").url
        let fakeCLI = tempRoot.file("codex")
        let script = "#!/bin/sh\n" +
            "echo \"ARGS:$@\" >> \"$MARKER_PATH\"\n" +
            "echo \"CODEX_HOME:$CODEX_HOME\" >> \"$MARKER_PATH\"\n"
        try fakeCLI.overlay(with: script)
        try fakeCLI.set(permissions: .default)

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let runner = CodexLoginRunner()
        let resolved = CodexCommandExecutor(
            executable: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.url.path,
                "MARKER_PATH": marker.path,
            ]
        ).resolveExecutable()
        #expect(resolved == fakeCLI.url.path)

        let handle = try runner.startLogin(
            binary: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.url.path,
                "MARKER_PATH": marker.path,
            ],
            codexHome: codexHome.url
        )

        let out = try awaitMarkerOutput(at: marker, handle: handle, timeout: 5.0)
        #expect(out.contains("ARGS:login"))
        #expect(out.contains("CODEX_HOME:\(codexHome.url.path)"))
    }

    @Test("startLogin supports STFolder codexHome")
    func startLoginWithSTFolder() throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-runner-folder-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let marker = tempRoot.file("marker.txt").url
        let fakeCLI = tempRoot.file("codex")
        let script = "#!/bin/sh\n" +
            "echo \"CODEX_HOME:$CODEX_HOME\" >> \"$MARKER_PATH\"\n"
        try fakeCLI.overlay(with: script)
        try fakeCLI.set(permissions: .default)

        let codexHomeFolder = tempRoot.folder("codex-home")
        _ = codexHomeFolder.createIfNotExists()

        let runner = CodexLoginRunner()
        let handle = try runner.startLogin(
            binary: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.url.path,
                "MARKER_PATH": marker.path,
            ],
            codexHome: codexHomeFolder
        )

        let out = try awaitMarkerOutput(at: marker, handle: handle, timeout: 5.0)
        #expect(out.contains("CODEX_HOME:\(codexHomeFolder.url.path)"))
    }

    @Test("loginAndAwaitAuthJSONString returns auth content when login writes auth.json")
    func loginAndAwaitAuthJSONStringReturnsAuth() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-auth-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex")
        let script = """
        #!/bin/sh
        mkdir -p "$CODEX_HOME"
        printf '{"tokens":{"id_token":"id-test","access_token":"access-test"}}' > "$CODEX_HOME/auth.json"
        """
        try fakeCLI.overlay(with: script)
        try fakeCLI.set(permissions: .default)

        let codexHomeFolder = tempRoot.folder("codex-home")
        _ = codexHomeFolder.createIfNotExists()

        let runner = CodexLoginRunner()
        let raw = try await runner.loginAndAwaitAuthJSONString(
            binary: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.url.path,
            ],
            codexHome: codexHomeFolder,
            timeoutSeconds: 15,
            pollIntervalSeconds: 0.05,
            processExitGraceSeconds: 0.2
        )
        #expect(raw.contains("\"id_token\":\"id-test\""))
        #expect(raw.contains("\"access_token\":\"access-test\""))
    }

    @Test("loginAndAwaitAuthResult captures login URL from CLI output")
    func loginAndAwaitAuthResultCapturesLoginURL() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-url-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex")
        let script = """
        #!/bin/sh
        echo "Open this URL to continue: https://auth.example.com/device?user_code=ABCD"
        mkdir -p "$CODEX_HOME"
        printf '{"tokens":{"id_token":"id-url","access_token":"access-url"}}' > "$CODEX_HOME/auth.json"
        """
        try fakeCLI.overlay(with: script)
        try fakeCLI.set(permissions: .default)

        let codexHomeFolder = tempRoot.folder("codex-home")
        _ = codexHomeFolder.createIfNotExists()

        let runner = CodexLoginRunner()
        let result = try await runner.loginAndAwaitAuthResult(
            binary: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.url.path,
            ],
            codexHome: codexHomeFolder,
            timeoutSeconds: 15,
            pollIntervalSeconds: 0.05,
            processExitGraceSeconds: 0.2
        )
        #expect(result.authJSONString.contains("\"id_token\":\"id-url\""))
        #expect(result.loginURL == "https://auth.example.com/device?user_code=ABCD")
    }

    @Test("loginAndAwaitAuthJSONString reports missing auth when login exits without auth.json")
    func loginAndAwaitAuthJSONStringThrowsWhenAuthMissing() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-missing-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex")
        let script = """
        #!/bin/sh
        exit 0
        """
        try fakeCLI.overlay(with: script)
        try fakeCLI.set(permissions: .default)

        let codexHomeFolder = tempRoot.folder("codex-home")
        _ = codexHomeFolder.createIfNotExists()

        let runner = CodexLoginRunner()
        do {
            _ = try await runner.loginAndAwaitAuthJSONString(
                binary: "codex",
                environment: [
                    "CODEX_CLI_PATH": fakeCLI.url.path,
                ],
                codexHome: codexHomeFolder,
                timeoutSeconds: 5,
                pollIntervalSeconds: 0.05,
                processExitGraceSeconds: 0.1
            )
            Issue.record("Expected auth missing error")
        } catch let error as CodexLoginError {
            #expect(error == .authNotCreated || error == .loginTimedOut)
        }
    }

    @Test("cancel escalates to kill when login process ignores terminate")
    func cancelEscalatesToKillWhenProcessIgnoresTerminate() throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-cancel-kill-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex")
        let script = """
        #!/bin/sh
        trap '' TERM
        while true; do
          sleep 1
        done
        """
        try fakeCLI.overlay(with: script)
        try fakeCLI.set(permissions: .default)

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let runner = CodexLoginRunner()
        let handle = try runner.startLogin(
            binary: "codex",
            environment: ["CODEX_CLI_PATH": fakeCLI.url.path],
            codexHome: codexHome.url
        )
        #expect(handle.isRunning)

        handle.cancel(graceSeconds: 0.1)
        let deadline = Date().addingTimeInterval(2.0)
        while handle.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        #expect(handle.isRunning == false)
    }

    @Test("awaitAuthResult waits for delayed auth.json write")
    func awaitAuthResultWaitsForDelayedWrite() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-delayed-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let writer = Task.detached {
            try? await Task.sleep(nanoseconds: 250_000_000)
            try? codexHome.file("auth.json").overlay(with: #"{"tokens":{"id_token":"id-delayed","access_token":"access-delayed"}}"#)
        }
        defer { writer.cancel() }

        let result = try await CodexLoginRunner.awaitAuthResult(
            codexHome: codexHome,
            timeoutSeconds: 2,
            pollIntervalSeconds: 0.05
        )
        #expect(result.authJSONString.contains("\"id_token\":\"id-delayed\""))
        #expect(result.authJSONString.contains("\"access_token\":\"access-delayed\""))
    }

    @Test("awaitAuthResult keeps polling when auth.json is temporarily invalid UTF-8")
    func awaitAuthResultRetriesWhenAuthUTF8IsTemporarilyInvalid() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-invalid-utf8-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()
        let authURL = codexHome.file("auth.json").url

        let writer = Task.detached {
            try? await Task.sleep(nanoseconds: 120_000_000)
            try? Data([0xC3, 0x28]).write(to: authURL)
            try? await Task.sleep(nanoseconds: 180_000_000)
            try? #"{"tokens":{"id_token":"id-fixed","access_token":"access-fixed"}}"#.write(
                to: authURL,
                atomically: true,
                encoding: .utf8
            )
        }
        defer { writer.cancel() }

        let result = try await CodexLoginRunner.awaitAuthResult(
            codexHome: codexHome,
            timeoutSeconds: 2,
            pollIntervalSeconds: 0.05
        )
        #expect(result.authJSONString.contains("\"id_token\":\"id-fixed\""))
        #expect(result.authJSONString.contains("\"access_token\":\"access-fixed\""))
    }

    @Test("awaitAuthResult throws authInvalidUTF8 when auth.json stays invalid until timeout")
    func awaitAuthResultThrowsInvalidUTF8WhenStillInvalidAtTimeout() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-invalid-utf8-timeout-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()
        let authFile = codexHome.file("auth.json")
        try authFile.overlay(with: Data([0xC3, 0x28]))

        do {
            _ = try await CodexLoginRunner.awaitAuthResult(
                codexHome: codexHome,
                timeoutSeconds: 0.2,
                pollIntervalSeconds: 0.05
            )
            Issue.record("Expected authInvalidUTF8 timeout error")
        } catch let error as CodexLoginError {
            #expect(error == .authInvalidUTF8)
        }
    }

    @Test("awaitAuthResultPreferFile succeeds even when completion waiter fails")
    func awaitAuthResultPreferFileIgnoresCompletionWaiterFailure() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-prefer-file-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let writer = Task.detached {
            try? await Task.sleep(nanoseconds: 250_000_000)
            try? codexHome.file("auth.json").overlay(with: #"{"tokens":{"id_token":"id-prefer","access_token":"access-prefer"}}"#)
        }
        defer { writer.cancel() }

        let result = try await CodexLoginRunner.awaitAuthResultPreferFile(
            codexHome: codexHome,
            timeoutSeconds: 2,
            pollIntervalSeconds: 0.05,
            completionWaiter: {
                throw NSError(domain: "CodexLoginRunnerTests", code: -1)
            }
        )
        #expect(result.authJSONString.contains("\"id_token\":\"id-prefer\""))
        #expect(result.authJSONString.contains("\"access_token\":\"access-prefer\""))
    }

    @Test("awaitAuthResultPreferFile returns immediately when auth file is ready even if completion waiter ignores cancellation")
    func awaitAuthResultPreferFileDoesNotBlockOnNonCancellableCompletionWaiter() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-prefer-file-cancel-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()

        let writer = Task.detached {
            try? await Task.sleep(nanoseconds: 250_000_000)
            try? codexHome.file("auth.json").overlay(with: #"{"tokens":{"id_token":"id-fast","access_token":"access-fast"}}"#)
        }
        defer { writer.cancel() }

        let startedAt = Date()
        let result = try await CodexLoginRunner.awaitAuthResultPreferFile(
            codexHome: codexHome,
            timeoutSeconds: 2,
            pollIntervalSeconds: 0.05,
            completionWaiter: {
                let waiterStart = Date()
                while Date().timeIntervalSince(waiterStart) < 3 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        )
        let elapsed = Date().timeIntervalSince(startedAt)

        #expect(result.authJSONString.contains("\"id_token\":\"id-fast\""))
        #expect(result.authJSONString.contains("\"access_token\":\"access-fast\""))
        #expect(elapsed < 1.5)
    }

    @Test("awaitAuthResult throws authNotCreated when timeout expires")
    func awaitAuthResultThrowsWhenTimeoutExpires() async throws {
        let tempRoot = STFolder("/tmp").folder("codex-login-await-timeout-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let codexHome = tempRoot.folder("codex-home")
        _ = codexHome.createIfNotExists()

        do {
            _ = try await CodexLoginRunner.awaitAuthResult(
                codexHome: codexHome,
                timeoutSeconds: 0.2,
                pollIntervalSeconds: 0.05
            )
            Issue.record("Expected authNotCreated timeout error")
        } catch let error as CodexLoginError {
            #expect(error == .authNotCreated)
        }
    }

    private func awaitMarkerOutput(at marker: URL, handle: CodexLoginHandle, timeout: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let out = try? String(contentsOf: marker, encoding: .utf8), !out.isEmpty {
                if handle.isRunning {
                    handle.cancel()
                }
                return out
            }
            if !handle.isRunning {
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        if handle.isRunning {
            handle.cancel()
        }
        return try String(contentsOf: marker, encoding: .utf8)
    }
}
