import Foundation
import Testing
import STFilePath
import STJSON
@testable import ProviderUsage

@Suite("Codex configured accounts")
struct CodexConfiguredAccountTests {
    private static func makeJWT(payload: String) -> String {
        func encode(_ string: String) -> String {
            Data(string.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        let header = #"{"alg":"RS256","typ":"JWT"}"#
        return "\(encode(header)).\(encode(payload)).signature"
    }

    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    @Test("Given apikey auth with relay block, when parsing summary, then infers relay profile metadata")
    func parseRelaySummaryMetadata() throws {
        let json = #"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "rk-live-12345678",
          "nolon": {
            "account": {
              "name": "Work Relay"
            },
            "relay": {
              "base_url": "https://relay.example.com/v1",
              "model_provider": "relay"
            }
          }
        }
        """#

        let summary = CodexAuthSummary.fromJSONString(json)

        #expect(summary.cardKind == .relayProfile)
        #expect(summary.name == "Work Relay")
        #expect(summary.preferredDisplayName() == "relay")
        #expect(summary.relayBaseURL == "https://relay.example.com/v1")
        #expect(summary.relayModelProvider == "relay")
        #expect(summary.apiKeySuffix == "5678")
    }

    @Test("Given apikey auth without relay block, when parsing summary, then infers official API key metadata")
    func parseOfficialAPIKeySummaryMetadata() throws {
        let json = #"""
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "sk-live-12345678",
          "nolon": {
            "account": {
              "name": "OpenAI Direct"
            }
          }
        }
        """#

        let summary = CodexAuthSummary.fromJSONString(json)

        #expect(summary.cardKind == .officialAPIKey)
        #expect(summary.name == "OpenAI Direct")
        #expect(summary.preferredDisplayName() == "key-5678")
        #expect(summary.relayBaseURL == nil)
        #expect(summary.relayModelProvider == nil)
        #expect(summary.apiKeySuffix == "5678")
    }

    @Test("Given chatgpt auth with mismatched token and JWT account ids, when parsing summary, then prefers JWT chatgpt account id")
    func parseChatGPTSummaryPrefersJWTAccountID() throws {
        let jwt = Self.makeJWT(payload: """
        {
          "https://api.openai.com/auth": {
            "chatgpt_account_id": "acct-jwt"
          }
        }
        """)
        let json = #"""
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "id_token": "\#(jwt)",
            "account_id": "acct-token"
          },
          "email": "user@example.com"
        }
        """#

        let summary = CodexAuthSummary.fromJSONString(json)

        #expect(summary.accountID == "acct-jwt")
    }

    @Test("Given relay configuration, when adding configured account, then auth file stores relay metadata and account kind")
    func addConfiguredRelayAccount() async throws {
        let root = try makeTempRoot("codex-config-relay")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addConfiguredAccount(
            name: "Work Relay",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "relay",
                queryParams: ["api-version": "2025-01-01-preview"],
                headers: ["X-Workspace": "team-a"]
            )
        )

        let data = try #require(await manager.accountAuthData(for: account))
        let summary = CodexAuthSummary.fromJSONData(data)
        let json = try JSON(data: data)

        #expect(summary.cardKind == .relayProfile)
        #expect(summary.preferredDisplayName() == "relay")
        #expect(summary.relayBaseURL == "https://relay.example.com/v1")
        #expect(summary.relayModelProvider == "relay")
        #expect(json["nolon"]["account"]["name"] == JSON.null)
    }

    @Test("Given relay configuration without model provider, when adding configured account, then validation fails")
    func addConfiguredRelayAccountRequiresModelProvider() async throws {
        let root = try makeTempRoot("codex-config-relay-missing-provider")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)

        await #expect(throws: NSError.self) {
            try await manager.addConfiguredAccount(
                name: "Broken Relay",
                apiKey: "rk-live-12345678",
                relay: .init(
                    baseURL: "https://relay.example.com/v1",
                    modelProvider: "   "
                )
            )
        }
    }

    @Test("Given usage query config, when adding and updating configured account, then persists usage query block")
    func persistConfiguredAccountUsageQuery() async throws {
        let root = try makeTempRoot("codex-config-http-usage")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let usageQuery = CodexHTTPUsageQuery(
            enabled: true,
            request: .init(method: .get, url: "https://api.example.com/usage"),
            mapping: .init(creditsRemainingPath: "data.remaining")
        )

        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-12345678",
            relay: nil,
            usageQuery: usageQuery
        )
        try await manager.updateConfiguredAccount(
            account,
            name: "OpenAI Direct",
            apiKey: "sk-live-87654321",
            relay: nil,
            usageQuery: usageQuery
        )

        let data = try #require(await manager.accountAuthData(for: account))
        let authFile = root.folder("tmp").file("\(account.id.uuidString.lowercased()).json")
        _ = authFile.parentFolder()?.createIfNotExists()
        try authFile.overlay(with: data)
        let resolved = try CodexHTTPUsageQueryExecutor.resolveConfiguration(
            from: [CodexHTTPUsageQueryExecutor.authSourcePathEnvironmentKey: authFile.url.path]
        )
        let json = try JSON(data: data)

        #expect(CodexAuthSummary.fromJSONData(data).cardKind == .officialAPIKey)
        #expect(resolved?.query.enabled == true)
        #expect(resolved?.query.mapping?.creditsRemainingPath == "data.remaining")
        #expect(resolved?.defaultCredentials.apiKey == "sk-live-87654321")
        #expect(json["nolon"]["account"]["name"] == JSON.null)
    }

    @Test("Given direct API key account without relay or usage query, when materialized, then auth json omits SQLite-managed nolon metadata")
    func directConfiguredAccountOmitsNolonContainerWhenUnused() async throws {
        let root = try makeTempRoot("codex-config-direct-minimal")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-12345678",
            relay: nil,
            usageQuery: nil
        )

        let data = try #require(await manager.accountAuthData(for: account))
        let json = try JSON(data: data)

        #expect(CodexAuthSummary.fromJSONData(data).cardKind == .officialAPIKey)
        #expect(json["auth_mode"].string == "apikey")
        #expect(json["OPENAI_API_KEY"].string == "sk-live-12345678")
        #expect(json["nolon"] == JSON.null)
    }

    @Test("Given legacy nolon account name, when loading account, then removes persisted name and keeps runtime display label")
    func loadAccountRemovesLegacyNameField() async throws {
        let root = try makeTempRoot("codex-legacy-name")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let authFolder = manager.nolonCodexAuthFolder()
        _ = authFolder.createIfNotExists()
        let authFile = authFolder.file("legacy.json")
        try authFile.overlay(with: Data(
            #"""
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "sk-live-12345678",
              "nolon": {
                "account": {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "name": "OpenAI Direct",
                  "relativeAuthPath": "auth/legacy.json"
                }
              }
            }
            """#.utf8
        ))

        let account = try await manager.loadAccounts().first
        let data = try authFile.data()
        let json = try JSON(data: data)

        #expect(account?.name == "key-5678")
        #expect(json["nolon"]["account"]["name"] == JSON.null)
    }

    @Test("Given selected Codex accounts, when exporting and validating a zip, then all auth snapshots round-trip through the archive")
    func exportSelectedAccountsAsZip() async throws {
        let root = try makeTempRoot("codex-config-export-zip")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let relay = try await manager.addConfiguredAccount(
            name: "Work Relay",
            apiKey: "rk-live-12345678",
            relay: .init(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "relay",
                queryParams: [:],
                headers: [:]
            )
        )
        let direct = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-12345678",
            relay: nil
        )

        let archiveURL = root.url.appendingPathComponent("codex-export.zip")
        let exportedCount = try await manager.exportAccountsArchive(
            accountIDs: [relay.id, direct.id],
            destinationURL: archiveURL
        )
        let results = await manager.validateImportAuthFiles(urls: [archiveURL])

        #expect(exportedCount == 2)
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        #expect(results.count == 2)
        #expect(results.filter { !$0.isValid }.isEmpty)
        #expect(Set(results.compactMap(\.suggestedName)) == ["relay", "key-5678"])
    }
}
