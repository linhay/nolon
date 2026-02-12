import Foundation
import Testing
@testable import CodexCLIKit

@Suite("CodexCLIKit Environment")
struct CodexCLIKitEnvironmentTests {
    @Test("codex home uses CODEX_HOME override")
    func codexHomeOverride() {
        let env = ["CODEX_HOME": "/tmp/custom-codex-home"]
        let home = CodexCommandExecutor.codexHomeDirectoryURL(environment: env)
        #expect(home.path == "/tmp/custom-codex-home")
    }

    @Test("codex home defaults to ~/.codex")
    func codexHomeDefault() {
        let home = CodexCommandExecutor.codexHomeDirectoryURL(environment: [:])
        #expect(home.lastPathComponent == ".codex")
    }

    @Test("resolver respects CODEX_CLI_PATH")
    func resolveByEnvOverride() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-env-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fakeCLI = tempRoot.appendingPathComponent("codex", isDirectory: false)
        FileManager.default.createFile(atPath: fakeCLI.path, contents: Data("#!/bin/sh\nexit 0\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCLI.path)

        let executor = CodexCommandExecutor(executable: "codex", environment: ["CODEX_CLI_PATH": fakeCLI.path])
        #expect(executor.resolveExecutable() == fakeCLI.path)
    }

    @Test("resolver accepts explicit executable path")
    func resolveExplicitPath() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-explicit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fakeCLI = tempRoot.appendingPathComponent("codex-cli", isDirectory: false)
        FileManager.default.createFile(atPath: fakeCLI.path, contents: Data("#!/bin/sh\nexit 0\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCLI.path)

        let executor = CodexCommandExecutor(executable: fakeCLI.path, environment: [:])
        #expect(executor.resolveExecutable() == fakeCLI.path)
    }
}
