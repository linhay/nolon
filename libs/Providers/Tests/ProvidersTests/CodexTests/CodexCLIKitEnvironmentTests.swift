import Foundation
import Testing
import STFilePath
@testable import CodexCLIKit

@Suite("CodexCLIKit Environment")
struct CodexCLIKitEnvironmentTests {
    @Test("codex home uses CODEX_HOME override")
    func codexHomeOverride() {
        let env = ["CODEX_HOME": "/tmp/custom-codex-home"]
        let home = CodexCommandExecutor.codexHomeDirectoryURL(environment: env)
        #expect(home.path == "/tmp/custom-codex-home")
    }

    @Test("codex home STFolder uses CODEX_HOME override")
    func codexHomeFolderOverride() {
        let env = ["CODEX_HOME": "/tmp/custom-codex-home"]
        let home = CodexCommandExecutor.codexHomeDirectory(environment: env)
        #expect(home.url.path == "/tmp/custom-codex-home")
    }

    @Test("codex home defaults to ~/.codex")
    func codexHomeDefault() {
        let home = CodexCommandExecutor.codexHomeDirectoryURL(environment: [:])
        #expect(home.lastPathComponent == ".codex")
    }

    @Test("resolver respects CODEX_CLI_PATH")
    func resolveByEnvOverride() throws {
        let tempRoot = STFolder("/tmp")
            .folder("codex-cli-env-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex")
        try fakeCLI.overlay(with: "#!/bin/sh\nexit 0\n")
        try fakeCLI.set(permissions: .default)

        let executor = CodexCommandExecutor(executable: "codex", environment: ["CODEX_CLI_PATH": fakeCLI.url.path])
        #expect(executor.resolveExecutable() == fakeCLI.url.path)
    }

    @Test("resolver accepts explicit executable path")
    func resolveExplicitPath() throws {
        let tempRoot = STFolder("/tmp")
            .folder("codex-cli-explicit-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex-cli")
        try fakeCLI.overlay(with: "#!/bin/sh\nexit 0\n")
        try fakeCLI.set(permissions: .default)

        let executor = CodexCommandExecutor(executable: fakeCLI.url.path, environment: [:])
        #expect(executor.resolveExecutable() == fakeCLI.url.path)
    }

    @Test("async resolver respects CODEX_CLI_PATH")
    func resolveByEnvOverrideAsync() async throws {
        let tempRoot = STFolder("/tmp")
            .folder("codex-cli-env-async-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex")
        try fakeCLI.overlay(with: "#!/bin/sh\nexit 0\n")
        try fakeCLI.set(permissions: .default)

        let executor = CodexCommandExecutor(executable: "codex", environment: ["CODEX_CLI_PATH": fakeCLI.url.path])
        #expect(await executor.resolveExecutableAsync() == fakeCLI.url.path)
    }

    @Test("async resolver accepts explicit executable path")
    func resolveExplicitPathAsync() async throws {
        let tempRoot = STFolder("/tmp")
            .folder("codex-cli-explicit-async-\(UUID().uuidString)")
        _ = tempRoot.createIfNotExists()
        defer { try? tempRoot.delete() }

        let fakeCLI = tempRoot.file("codex-cli")
        try fakeCLI.overlay(with: "#!/bin/sh\nexit 0\n")
        try fakeCLI.set(permissions: .default)

        let executor = CodexCommandExecutor(executable: fakeCLI.url.path, environment: [:])
        #expect(await executor.resolveExecutableAsync() == fakeCLI.url.path)
    }
}
