import Foundation
import STFilePath
import Testing
@testable import CodexProvider

@Suite("CodexConfigStore")
struct CodexConfigStoreTests {
    @Test("Given concurrent non-overlapping updates when serialized through store then both config fragments are preserved")
    func concurrentUpdatesPreserveBothFragments() async throws {
        let root = STFolder("/tmp").folder("codex-config-store-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let configFile = root.file("config.toml")
        let store = CodexConfigStore(file: configFile)

        async let first: String = store.update { current in
            Thread.sleep(forTimeInterval: 0.05)
            return CodexConfigStore.upsertingTopLevelStringValue(in: current, key: "model", value: "gpt-5.4")
        }
        async let second: String = store.update { current in
            Thread.sleep(forTimeInterval: 0.05)
            let rendered = """
            [mcp_servers.local]
            command = "node"
            """
            return current.isEmpty ? rendered + "\n" : current + (current.hasSuffix("\n") ? "" : "\n") + rendered + "\n"
        }

        _ = try await (first, second)
        let saved = try store.readRaw()
        #expect(saved.contains(#"model = "gpt-5.4""#))
        #expect(saved.contains("[mcp_servers.local]"))
        #expect(saved.contains(#"command = "node""#))
    }

    @Test("Given existing sections when setting top-level key then unsupported content stays intact")
    func topLevelMutationPreservesSections() {
        let original = """
        approval_policy = "on-request"
        custom_top = "keep"

        [features]
        undo = true

        [mcp_servers.local]
        command = "node"
        """

        let patched = CodexConfigStore.upsertingTopLevelStringValue(
            in: original,
            key: "cli_auth_credentials_store",
            value: "file"
        )

        #expect(patched.contains(#"custom_top = "keep""#))
        #expect(patched.contains(#"cli_auth_credentials_store = "file""#))
        #expect(patched.contains("[features]"))
        #expect(patched.contains("[mcp_servers.local]"))
    }

    @Test("Given another process holds the config lock when updating through store then write waits and still persists")
    func externalLockBlocksUntilReleased() async throws {
        let root = STFolder("/tmp").folder("codex-config-store-lock-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let configFile = root.file("config.toml")
        let lockPath = CodexConfigStore.lockFilePath(for: configFile)
        let gateFile = root.file("child-ready")
        let releaseFile = root.file("release-child")

        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        child.arguments = [
            "python3",
            "-c",
            """
            import fcntl, os, time
            lock_path = os.environ["LOCK_PATH"]
            gate_path = os.environ["GATE_PATH"]
            release_path = os.environ["RELEASE_PATH"]
            os.makedirs(os.path.dirname(lock_path), exist_ok=True)
            fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
            fcntl.flock(fd, fcntl.LOCK_EX)
            with open(gate_path, "w", encoding="utf-8") as handle:
                handle.write("ready")
            while not os.path.exists(release_path):
                time.sleep(0.02)
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)
            """
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["LOCK_PATH"] = lockPath
        environment["GATE_PATH"] = gateFile.url.path
        environment["RELEASE_PATH"] = releaseFile.url.path
        child.environment = environment
        try child.run()
        defer {
            if child.isRunning {
                child.terminate()
            }
        }

        let deadline = Date().addingTimeInterval(2)
        while !gateFile.isExists, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(gateFile.isExists)

        let store = CodexConfigStore(file: configFile)
        let startedAt = Date()
        async let pendingWrite: String = store.update { current in
            CodexConfigStore.upsertingTopLevelStringValue(in: current, key: "model", value: "gpt-5.4")
        }

        try await Task.sleep(for: .milliseconds(150))
        #expect(configFile.isExists == false)

        try releaseFile.overlay(with: "release")
        let saved = try await pendingWrite
        let elapsed = Date().timeIntervalSince(startedAt)

        #expect(elapsed >= 0.12)
        #expect(saved.contains(#"model = "gpt-5.4""#))
        #expect(try store.readRaw().contains(#"model = "gpt-5.4""#))
    }
}
