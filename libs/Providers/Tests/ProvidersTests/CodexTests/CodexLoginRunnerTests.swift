import Foundation
import Testing
import STFilePath
@testable import CodexProvider
@testable import CodexCLIKit

@Suite("CodexLoginRunner")
struct CodexLoginRunnerTests {
    @Test("startLogin prefers CODEX_CLI_PATH and injects CODEX_HOME")
    func startLoginPrefersEnvBinaryOverride() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-login-runner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let marker = tempRoot.appendingPathComponent("marker.txt")
        let fakeCLI = tempRoot.appendingPathComponent("codex")
        let script = "#!/bin/sh\n" +
            "echo \"ARGS:$@\" >> \"$MARKER_PATH\"\n" +
            "echo \"CODEX_HOME:$CODEX_HOME\" >> \"$MARKER_PATH\"\n"
        try script.data(using: .utf8)?.write(to: fakeCLI)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCLI.path)

        let codexHome = tempRoot.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        let runner = CodexLoginRunner()
        let resolved = CodexCommandExecutor(
            executable: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.path,
                "MARKER_PATH": marker.path,
            ]
        ).resolveExecutable()
        #expect(resolved == fakeCLI.path)

        let handle = try runner.startLogin(
            binary: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.path,
                "MARKER_PATH": marker.path,
            ],
            codexHome: codexHome
        )

        let out = try awaitMarkerOutput(at: marker, handle: handle, timeout: 5.0)
        #expect(out.contains("ARGS:login"))
        #expect(out.contains("CODEX_HOME:\(codexHome.path)"))
    }

    @Test("startLogin supports STFolder codexHome")
    func startLoginWithSTFolder() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-login-runner-folder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let marker = tempRoot.appendingPathComponent("marker.txt")
        let fakeCLI = tempRoot.appendingPathComponent("codex")
        let script = "#!/bin/sh\n" +
            "echo \"CODEX_HOME:$CODEX_HOME\" >> \"$MARKER_PATH\"\n"
        try script.data(using: .utf8)?.write(to: fakeCLI)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCLI.path)

        let codexHomeFolder = STFolder(tempRoot.appendingPathComponent("codex-home", isDirectory: true))
        _ = codexHomeFolder.createIfNotExists()

        let runner = CodexLoginRunner()
        let handle = try runner.startLogin(
            binary: "codex",
            environment: [
                "CODEX_CLI_PATH": fakeCLI.path,
                "MARKER_PATH": marker.path,
            ],
            codexHome: codexHomeFolder
        )

        let out = try awaitMarkerOutput(at: marker, handle: handle, timeout: 5.0)
        #expect(out.contains("CODEX_HOME:\(codexHomeFolder.url.path)"))
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
