import Foundation
import STFilePath
import Testing
@testable import NolonCoreCLIKit

@Suite("Nolon Codex CLI Prepare Login Home")
struct NolonCodexCLIPrepareIsolatedLoginHomeTests {
    @Test("Given existing config sections when preparing isolated login home then only credential store is updated")
    func prepareLoginHomePreservesExistingConfig() throws {
        let root = STFolder("/tmp").folder("nolon-codex-cli-login-home-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let codexHome = root.folder("codex")
        _ = codexHome.createIfNotExists()

        let configFile = codexHome.file("config.toml")
        try configFile.overlay(with: """
        approval_policy = "on-request"
        cli_auth_credentials_store = "keyring"

        [features]
        multi_agent = true
        """)

        try NolonLiveCodexCLIService.prepareIsolatedLoginHome(codexHome: codexHome)

        let saved = try configFile.read()
        #expect(saved.contains(#"approval_policy = "on-request""#))
        #expect(saved.contains(#"cli_auth_credentials_store = "file""#))
        #expect(saved.contains("[features]"))
        #expect(saved.contains("multi_agent = true"))
    }
}
