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
}
