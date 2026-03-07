import Foundation
import Testing
@testable import ProviderUsage
@testable import CodexProvider

@Suite("Codex HTTP usage query executor")
struct CodexHTTPUsageQueryExecutorTests {
    @Test("Given valid relay auth and HTTP JSON, when executing, then maps plan credits usage and cost")
    func executeMapsHTTPUsageResponse() async throws {
        let query = CodexHTTPUsageQuery(
            enabled: true,
            timeoutSeconds: 15,
            request: .init(
                method: .get,
                url: "{{baseURL}}/billing/usage",
                headers: ["Authorization": "Bearer {{apiKey}}"]
            ),
            mapping: .init(
                planPath: "data.plan",
                creditsRemainingPath: "data.balance.remaining",
                usageUsedPath: "data.usage.used",
                usageTotalPath: "data.usage.total",
                costTodayUSDPath: "data.cost.today",
                costLast30DaysUSDPath: "data.cost.last30Days"
            )
        )
        let resolved = CodexHTTPUsageQueryResolvedConfiguration(
            query: query,
            defaultCredentials: .init(baseURL: "https://relay.example.com/v1", apiKey: "rk-live-123"),
            cardKind: .relayProfile
        )
        let executor = CodexHTTPUsageQueryExecutor { request in
            #expect(request.url?.absoluteString == "https://relay.example.com/v1/billing/usage")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer rk-live-123")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = #"{"data":{"plan":"Enterprise","balance":{"remaining":42.5},"usage":{"used":25,"total":100},"cost":{"today":1.2,"last30Days":9.8}}}"#
            return (Data(body.utf8), response)
        }

        let result = try await executor.execute(resolved, includeCredits: true)

        #expect(result.sourceLabel == "HTTP")
        #expect(result.usage.identity?.plan == "Enterprise")
        #expect(result.usage.identity?.loginMethod == "relay")
        #expect(result.credits?.remaining == 42.5)
        #expect(result.usage.primary?.usedPercent == 25)
        #expect(result.cost?.todayCostUSD == 1.2)
        #expect(result.cost?.last30DaysCostUSD == 9.8)
    }

    @Test("Given private URL, when executing, then rejects unsafe host before network")
    func executeRejectsUnsafeURL() async throws {
        let query = CodexHTTPUsageQuery(
            enabled: true,
            request: .init(method: .get, url: "https://127.0.0.1/usage"),
            mapping: .init(creditsRemainingPath: "credits")
        )
        let resolved = CodexHTTPUsageQueryResolvedConfiguration(
            query: query,
            defaultCredentials: .init(),
            cardKind: .officialAPIKey
        )
        let executor = CodexHTTPUsageQueryExecutor { _ in
            Issue.record("Network should not be reached for unsafe URLs")
            throw CodexHTTPUsageQueryError.networkFailure("unexpected")
        }

        await #expect(throws: CodexHTTPUsageQueryError.unsafeURL("Local and private network URLs are not allowed.")) {
            _ = try await executor.execute(resolved, includeCredits: true)
        }
    }

    @Test("Given JSON without usable fields, when executing, then returns mapping failed")
    func executeFailsWhenMappingHasNoUsableFields() async throws {
        let query = CodexHTTPUsageQuery(
            enabled: true,
            request: .init(method: .get, url: "https://api.example.com/usage"),
            mapping: .init(planPath: "missing")
        )
        let resolved = CodexHTTPUsageQueryResolvedConfiguration(
            query: query,
            defaultCredentials: .init(),
            cardKind: .officialAPIKey
        )
        let executor = CodexHTTPUsageQueryExecutor { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(#"{"ok":true}"#.utf8), response)
        }

        await #expect(throws: CodexHTTPUsageQueryError.mappingFailed("No usable usage fields found.")) {
            _ = try await executor.execute(resolved, includeCredits: true)
        }
    }

    @Test("Given auth source environment, when resolving configuration, then uses usageQuery and card defaults")
    func resolveConfigurationFromEnvironment() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("codex-http-query-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let authURL = folder.appendingPathComponent("auth.json")
        try Data(
            #"""
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "rk-live-5678",
              "nolon": {
                "account": {
                  "kind": "relayProfile",
                  "name": "Work Relay"
                },
                "relay": {
                  "base_url": "https://relay.example.com/v1",
                  "model_provider": "relay"
                },
                "usage_query": {
                  "enabled": true,
                  "request": {
                    "method": "GET",
                    "url": "{{baseURL}}/billing"
                  },
                  "mapping": {
                    "creditsRemainingPath": "data.remaining"
                  }
                }
              }
            }
            """#.utf8
        ).write(to: authURL)

        let resolved = try CodexHTTPUsageQueryExecutor.resolveConfiguration(
            from: [CodexHTTPUsageQueryExecutor.authSourcePathEnvironmentKey: authURL.path]
        )

        #expect(resolved?.query.enabled == true)
        #expect(resolved?.defaultCredentials.apiKey == "rk-live-5678")
        #expect(resolved?.defaultCredentials.baseURL == "https://relay.example.com/v1")
        #expect(resolved?.cardKind == .relayProfile)
    }

    @Test("Given callback-imported chatgpt auth tokens, when resolving configuration, then userID comes from persisted tokens.account_id")
    func resolveConfigurationUsesPersistedAccountIDFromCallbackImport() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("codex-http-query-callback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let callback = "http://localhost:1455/success?id_token=\(Self.makeJWT(email: "callback-http@example.com", accountID: "acct-http-callback"))"
        let raw = try CodexLoginRunner.authJSONString(fromSuccessCallbackURLString: callback)
        let object = try #require(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        var root = object
        var nolon = (root["nolon"] as? [String: Any]) ?? [:]
        nolon["usage_query"] = [
            "enabled": true,
            "request": [
                "method": "GET",
                "url": "https://example.com/usage?user={{userID}}",
            ],
            "mapping": [
                "creditsRemainingPath": "credits",
            ],
        ]
        root["nolon"] = nolon

        let authURL = folder.appendingPathComponent("auth.json")
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        try data.write(to: authURL)

        let resolvedConfiguration = try CodexHTTPUsageQueryExecutor.resolveConfiguration(
            from: [CodexHTTPUsageQueryExecutor.authSourcePathEnvironmentKey: authURL.path]
        )
        let resolved = try #require(resolvedConfiguration)

        #expect(resolved.defaultCredentials.userID == "acct-http-callback")
    }

    private static func makeJWT(email: String, accountID: String) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        let payload = """
        {
          "email":"\(email)",
          "https://api.openai.com/auth":{
            "chatgpt_account_id":"\(accountID)"
          }
        }
        """
        return "\(base64URLEncode(header)).\(base64URLEncode(payload))."
    }

    private static func base64URLEncode(_ raw: String) -> String {
        Data(raw.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
