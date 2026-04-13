import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

extension CodexAuthManagerTests {
    @Test("Given batch JSON array import file, when validating then importing, each element becomes a snapshot and top-level tokens are normalized into tokens.*")
    func validateAndImportAuthFilesExpandsJSONArrayFile() async throws {
        let root = try makeTempRoot("codex-auth-import-array")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()

        let batchURL = inputFolder.file("batch.json").url
        try """
        [
          {
            "type": "codex",
            "email": "a@example.com",
            "id_token": "id-a",
            "access_token": "access-a",
            "refresh_token": "refresh-a",
            "account_id": "acct-a",
            "expired": "2026-03-20T15:23:19Z"
          },
          {
            "type": "codex",
            "email": "b@example.com",
            "id_token": "id-b",
            "access_token": "access-b",
            "refresh_token": "refresh-b",
            "account_id": "acct-b"
          }
        ]
        """.write(to: batchURL, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [batchURL])
        #expect(results.count == 2)
        #expect(results.filter { $0.isValid }.count == 2)

        let imported = try await manager.importValidatedAuthFiles(results: results)
        #expect(imported.count == 2)

        let accountA = try #require(imported.first)
        let accountB = try #require(imported.dropFirst().first)
        let pairA = try await manager.readTokenPair(for: accountA)
        let pairB = try await manager.readTokenPair(for: accountB)
        let pairs = [pairA, pairB].compactMap { $0 }
        #expect(pairs.count == 2)
        #expect(Set(pairs.map { $0.idToken }) == ["id-a", "id-b"])
        #expect(Set(pairs.map { $0.accessToken }) == ["access-a", "access-b"])
    }
    @Test("Given auth JSON contains type but not codex, when validating then candidate is rejected with a stable reason")
    func validateImportAuthFilesRejectsUnsupportedProviderType() async throws {
        let root = try makeTempRoot("codex-auth-import-type")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()

        let url = inputFolder.file("other.json").url
        try #"{"type":"other","id_token":"id","access_token":"access"}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        #expect(results.count == 1)
        #expect(results[0].isValid == false)
        #expect(results[0].reason?.lowercased().contains("type") == true)
    }
    @Test("Given oauth import only has access and refresh token, when validating then manager refreshes tokens and backfills account metadata")
    func validateImportAuthFilesRefreshesAndBackfillsMetadata() async throws {
        let root = try makeTempRoot("codex-auth-import-refresh")
        defer { try? root.delete() }

        let jwt = Self.makeJWT(payload: #"{"email":"refreshed@example.com","https://api.openai.com/auth":{"chatgpt_account_id":"acct-refreshed","chatgpt_plan_type":"pro"}}"#)
        let manager = CodexAuthManager(
            rootURL: root.url,
            refreshCodexTokenAction: { refreshToken in
                #expect(refreshToken == "refresh-only")
                return .init(
                    accessToken: "access-refreshed",
                    idToken: jwt,
                    refreshToken: "refresh-refreshed",
                    expiresIn: 3600
                )
            }
        )

        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let url = inputFolder.file("refresh-only.json").url
        try #"{"tokens":{"access_token":"access-only","refresh_token":"refresh-only"}}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.isValid == true)
        #expect(result.email == "refreshed@example.com")
        #expect(result.suggestedName == "refreshed@example.com")

        let raw = try #require(result.authJSONString)
        let json = try JSON(data: Data(raw.utf8))
        #expect(json["tokens"]["id_token"].string == jwt)
        #expect(json["tokens"]["access_token"].string == "access-refreshed")
        #expect(json["tokens"]["refresh_token"].string == "refresh-refreshed")
        #expect(json["tokens"]["account_id"].string == "acct-refreshed")
        #expect(json["chatgpt_account_id"].string == "acct-refreshed")
        #expect(json["email"].string == "refreshed@example.com")
        #expect(json["plan_type"].string == "pro")
        #expect(json["plan"].string == "pro")
    }
    @Test("Given oauth import has jwt tokens but missing profile fields, when validating then manager derives email account and plan from jwt")
    func validateImportAuthFilesDerivesMetadataFromJWTClaims() async throws {
        let root = try makeTempRoot("codex-auth-import-jwt-derive")
        defer { try? root.delete() }

        let jwt = Self.makeJWT(payload: #"{"email":"jwt-only@example.com","https://api.openai.com/auth":{"chatgpt_account_id":"acct-jwt","chatgpt_plan_type":"plus"}}"#)
        let manager = CodexAuthManager(
            rootURL: root.url,
            refreshCodexTokenAction: { _ in
                throw NSError(domain: "CodexAuthManagerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "refresh should not be called"])
            }
        )

        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let url = inputFolder.file("jwt-only.json").url
        try #"{"tokens":{"id_token":"\#(jwt)","access_token":"access-jwt-only"}}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.isValid == true)
        #expect(result.email == "jwt-only@example.com")
        #expect(result.suggestedName == "jwt-only@example.com")

        let raw = try #require(result.authJSONString)
        let json = try JSON(data: Data(raw.utf8))
        #expect(json["email"].string == "jwt-only@example.com")
        #expect(json["tokens"]["account_id"].string == "acct-jwt")
        #expect(json["chatgpt_account_id"].string == "acct-jwt")
        #expect(json["plan_type"].string == "plus")
        #expect(json["plan"].string == "plus")
    }
    @Test("Given oauth import lacks profile fields and jwt hints, when validating then manager fetches resource account info with access token")
    func validateImportAuthFilesFetchesResourceAccountInfo() async throws {
        let root = try makeTempRoot("codex-auth-import-resource-info")
        defer { try? root.delete() }

        let manager = CodexAuthManager(
            rootURL: root.url,
            refreshCodexTokenAction: { _ in
                throw NSError(domain: "CodexAuthManagerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "refresh should not be called"])
            },
            fetchCodexAccountInfoAction: { accessToken in
                #expect(accessToken == "access-resource")
                return .init(
                    email: "resource@example.com",
                    accountID: "acct-resource",
                    planType: "team"
                )
            }
        )

        let inputFolder = root.folder("input")
        _ = inputFolder.createIfNotExists()
        let url = inputFolder.file("resource-only.json").url
        try #"{"tokens":{"id_token":"header.payload.signature","access_token":"access-resource"}}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let results = await manager.validateImportAuthFiles(urls: [url])
        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.isValid == true)
        #expect(result.email == "resource@example.com")
        #expect(result.suggestedName == "resource@example.com")

        let raw = try #require(result.authJSONString)
        let json = try JSON(data: Data(raw.utf8))
        #expect(json["email"].string == "resource@example.com")
        #expect(json["tokens"]["account_id"].string == "acct-resource")
        #expect(json["chatgpt_account_id"].string == "acct-resource")
        #expect(json["plan_type"].string == "team")
        #expect(json["plan"].string == "team")
    }
    @Test("Given codexXcode provider template, when resolving codex home, then auth manager returns valid home folder")
    func codexXcodeHomeFolderIsAvailable() async throws {
        let root = try makeTempRoot("codex-auth-codexxcode-home")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let providerRoot = root.folder("xcode-codex-home")
        let provider = Provider(
            name: "Codex (Xcode)",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codexXcode"
        )

        let home = await manager.codexHomeFolder(for: provider)
        #expect(home == providerRoot)
    }
    @Test("Given auth payload with both email and api key suffix hints, when matching snapshot then email has highest priority")
    func matchAccountPrioritizesEmailOverApiKey() async throws {
        let root = try makeTempRoot("codex-auth-match-email")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let emailMatch = try await manager.addAccount(
            name: "email-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-email-1111","email":"email-match@example.com"}"#
        )
        _ = try await manager.addAccount(
            name: "key-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-key-9999","email":"other@example.com"}"#
        )
        let payload = Data(#"{"OPENAI_API_KEY":"sk-any-9999","email":"email-match@example.com"}"#.utf8)

        let matched = try await manager.matchAccountByAuthData(payload)
        #expect(matched?.id == emailMatch.id)
    }
    @Test("Given auth payload only contains account id, when matching snapshot then no snapshot is matched")
    func matchAccountDoesNotMatchWhenOnlyAccountIDIsPresent() async throws {
        let root = try makeTempRoot("codex-auth-match-accountid")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        _ = try await manager.addAccount(
            name: "accountid-match",
            authJSONString: #"{"tokens":{"account_id":"acct-123"},"OPENAI_API_KEY":"sk-one-1111"}"#
        )
        _ = try await manager.addAccount(
            name: "suffix-match",
            authJSONString: #"{"OPENAI_API_KEY":"sk-two-7777"}"#
        )
        let payload = Data(#"{"tokens":{"account_id":"acct-123"},"OPENAI_API_KEY":"sk-other-7777"}"#.utf8)

        let matched = try await manager.matchAccountByAuthData(payload)
        #expect(matched == nil)
    }
    @Test("Given same account id and missing email without nolon account id, when recording login snapshot then a new snapshot is created")
    func recordCLILoginSnapshotCreatesNewWhenMissingEmailAndNoNolonAccountID() async throws {
        let root = try makeTempRoot("codex-auth-record-accountid-only")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"account_id":"acct-shared","id_token":"old-id","access_token":"old-access"},"email":"existing@example.com"}"#
        )

        let created = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"tokens":{"account_id":"acct-shared","id_token":"new-id","access_token":"new-access"}}"#,
            preferredAccountID: nil
        )

        #expect(created.id != existing.id)
        let all = try await manager.loadAccounts()
        #expect(all.count == 2)
    }
    @Test("Given same account id and same nolon account id with missing email, when recording login snapshot then existing snapshot is overwritten in place")
    func recordCLILoginSnapshotOverwritesWhenMissingEmailButNolonAccountIDMatches() async throws {
        let root = try makeTempRoot("codex-auth-record-accountid-nolon-id")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let existing = try await manager.addAccount(
            name: "existing",
            authJSONString: #"{"tokens":{"account_id":"acct-shared","id_token":"old-id","access_token":"old-access"},"email":"existing@example.com"}"#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"""
            {
              "tokens": {
                "account_id": "acct-shared",
                "id_token": "new-id",
                "access_token": "new-access"
              },
              "nolon": {
                "account": {
                  "id": "\#(existing.id.uuidString)"
                }
              }
            }
            """#,
            preferredAccountID: nil
        )

        #expect(updated.id == existing.id)
        let all = try await manager.loadAccounts()
        #expect(all.count == 1)
        let pair = try await manager.readTokenPair(for: updated)
        #expect(pair?.idToken == "new-id")
        #expect(pair?.accessToken == "new-access")
    }
    @Test("Given same email and same JWT chatgpt account id but stale token account id, when recording login snapshot then updates existing snapshot instead of creating duplicate")
    func recordCLILoginSnapshotPrefersJWTAccountIDOverStaleTokenAccountID() async throws {
        let root = try makeTempRoot("codex-auth-login-jwt-account-id")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let canonicalJWT = Self.makeJWT(payload: """
        {
          "email": "same-user@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_account_id": "acct-team"
          }
        }
        """)
        let staleJWT = Self.makeJWT(payload: """
        {
          "email": "same-user@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_account_id": "acct-team"
          }
        }
        """)

        let existing = try await manager.addAccount(
            name: "team",
            authJSONString: #"""
            {
              "auth_mode": "chatgpt",
              "email": "same-user@example.com",
              "tokens": {
                "id_token": "\#(canonicalJWT)",
                "access_token": "access-old",
                "account_id": "acct-team"
              }
            }
            """#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"""
            {
              "auth_mode": "chatgpt",
              "email": "same-user@example.com",
              "tokens": {
                "id_token": "\#(staleJWT)",
                "access_token": "access-new",
                "account_id": "acct-stale"
              }
            }
            """#,
            preferredAccountID: nil
        )

        let accounts = try await manager.loadAccounts()
        var matching: [CodexAuthAccount] = []
        for account in accounts {
            guard let data = try? await manager.accountAuthFile(account).data() else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if summary.email == "same-user@example.com" {
                matching.append(account)
            }
        }

        #expect(updated.id == existing.id)
        #expect(matching.count == 1)
        let updatedPair = try await manager.readTokenPair(for: updated)
        #expect(updatedPair?.chatgptAccountID == "acct-team")
        #expect(updatedPair?.accessToken == "access-new")
    }
    @Test("Given two snapshots share api key suffix, when recording login snapshot, then exact api key account is updated without drifting into newer file")
    func recordCLILoginSnapshotMatchesExactAPIKeyWithoutSuffixDrift() async throws {
        let root = try makeTempRoot("codex-auth-match-exact-api-key")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let older = try await manager.addAccount(
            name: "older",
            authJSONString: #"{"OPENAI_API_KEY":"sk-alpha-1234"}"#
        )
        let newer = try await manager.addAccount(
            name: "newer",
            authJSONString: #"{"OPENAI_API_KEY":"sk-beta-1234"}"#
        )

        let updated = try await manager.recordCLILoginSnapshot(
            authJSONString: #"{"OPENAI_API_KEY":"sk-alpha-1234"}"#,
            preferredAccountID: nil
        )
        #expect(updated.id == older.id)

        let newerRaw = try await manager.accountAuthFile(newer).read()
        let newerJSON = try #require(try? JSON(data: Data(newerRaw.utf8)))
        #expect(newerJSON["OPENAI_API_KEY"].string == "sk-beta-1234")
    }
}
