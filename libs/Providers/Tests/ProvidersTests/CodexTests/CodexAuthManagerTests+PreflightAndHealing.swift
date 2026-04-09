import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

extension CodexAuthManagerTests {
    @Test("Given detached provider auth with invalid json and healthy snapshot, when preflight runs then snapshot is kept as source of truth")
    func preflightPrefersHealthySnapshotWhenProviderAuthBroken() async throws {
        let root = try makeTempRoot("codex-auth-preflight-prefer-snapshot")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let snapshot = try await manager.addAccount(
            name: "stable",
            authJSONString: #"{"tokens":{"id_token":"id-stable","access_token":"access-stable"},"email":"stable@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(snapshot, for: provider)
        let providerAuth = try #require(await manager.authFile(for: provider))
        if providerAuth.isExists || providerAuth.isSymbolicLink {
            try providerAuth.delete()
        }
        try "not-json".write(to: providerAuth.url, atomically: true, encoding: .utf8)

        let affected = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "test")
        #expect(affected?.id == snapshot.id)
        #expect(providerAuth.isSymbolicLink == true)
    }
    @Test("Given snapshot folder contains non-importable files, when loading accounts then those files are pruned")
    func loadAccountsPrunesNonImportableSnapshotFiles() async throws {
        let root = try makeTempRoot("codex-auth-load-prune-non-importable")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let authFolder = manager.nolonCodexAuthFolder()
        _ = authFolder.createIfNotExists()

        let activeFile = authFolder.file("active.json")
        try #"{"email":"active@example.com","nolon":{"account":{"relativeAuthPath":"auth/active.json"}}}"#
            .write(to: activeFile.url, atomically: true, encoding: .utf8)
        let testFile = authFolder.file("test.json")
        try #"{"nolon":{"account":{"relativeAuthPath":"auth/test.json"}}}"#
            .write(to: testFile.url, atomically: true, encoding: .utf8)
        let validFile = authFolder.file("valid.json")
        try #"{"tokens":{"id_token":"id-valid","access_token":"access-valid"},"email":"valid@example.com"}"#
            .write(to: validFile.url, atomically: true, encoding: .utf8)

        let accounts = try await manager.loadAccounts()

        #expect(accounts.count == 1)
        #expect(accounts.first?.relativeAuthPath == "auth/valid.json")
        #expect(activeFile.isExists == false)
        #expect(testFile.isExists == false)
        #expect(validFile.isExists == true)
    }
    @Test("Given active snapshot drifted by external write, when preflight runs then active snapshot is restored and drifted auth is preserved separately")
    func preflightRestoresActiveSnapshotAfterExternalDrift() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active","account_id":"acct-shared"},"email":"active@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"{"tokens":{"id_token":"id-drift","access_token":"access-drift","account_id":"acct-shared"},"email":"drift@example.com"}"#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require((try await manager.loadAccounts()).first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try await manager.accountAuthFile(restoredActive).data())
        #expect(restoredSummary.email == "active@example.com")

        let accounts = try await manager.loadAccounts()
        var driftedFound = false
        for account in accounts where account.id != restoredActiveID {
            let file = await manager.accountAuthFile(account)
            let summary = CodexAuthSummary.fromJSONData((try? file.data()) ?? Data())
            if summary.email == "drift@example.com" {
                driftedFound = true
                break
            }
        }
        #expect(driftedFound == true)
    }
    @Test("Given active drift payload shares account id and email with an existing snapshot, when preflight runs then existing same-identity snapshot is overwritten")
    func preflightOverwritesExistingSnapshotWhenDriftIdentityMatchesStrictly() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift-strict-match")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active","account_id":"acct-shared"},"email":"active@example.com"}"#
        )
        let peer = try await manager.addAccount(
            name: "peer",
            authJSONString: #"{"tokens":{"id_token":"id-peer-old","access_token":"access-peer-old","account_id":"acct-shared"},"email":"peer@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"""
        {
          "tokens": {
            "id_token": "id-peer-new",
            "access_token": "access-peer-new",
            "account_id": "acct-shared"
          },
          "email": "peer@example.com",
          "nolon": {
            "account": {
              "id": "\#(active.id.uuidString)"
            }
          }
        }
        """#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 2)

        let peerAfter = try #require(accounts.first(where: { $0.id == peer.id }))
        let peerPair = try await manager.readTokenPair(for: peerAfter)
        #expect(peerPair?.idToken == "id-peer-new")
        #expect(peerPair?.accessToken == "access-peer-new")

        let restoredActiveID = try #require(await manager.activeAccountId(for: provider))
        let restoredActive = try #require(accounts.first(where: { $0.id == restoredActiveID }))
        let restoredSummary = CodexAuthSummary.fromJSONData(try await manager.accountAuthFile(restoredActive).data())
        #expect(restoredSummary.email == "active@example.com")
    }
    @Test("Given active drift payload shares account id but has different email from existing snapshots, when preflight runs then drift payload is saved as a new snapshot")
    func preflightCreatesNewSnapshotWhenDriftEmailDiffersUnderSameAccountID() async throws {
        let root = try makeTempRoot("codex-auth-preflight-drift-email-diff")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let active = try await manager.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"id-active","access_token":"access-active","account_id":"acct-shared"},"email":"active@example.com"}"#
        )
        let peer = try await manager.addAccount(
            name: "peer",
            authJSONString: #"{"tokens":{"id_token":"id-peer-old","access_token":"access-peer-old","account_id":"acct-shared"},"email":"peer@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(active, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let driftedRaw = #"""
        {
          "tokens": {
            "id_token": "id-drift-new",
            "access_token": "access-drift-new",
            "account_id": "acct-shared"
          },
          "email": "newcomer@example.com",
          "nolon": {
            "account": {
              "id": "\#(active.id.uuidString)"
            }
          }
        }
        """#
        let activeID = try #require(await manager.activeAccountId(for: provider))
        let activeResolved = try #require((try await manager.loadAccounts()).first(where: { $0.id == activeID }))
        let activeFile = await manager.accountAuthFile(activeResolved)
        try activeFile.overlay(with: Data(driftedRaw.utf8))

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "detect_drift")

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 3)

        let peerAfter = try #require(accounts.first(where: { $0.id == peer.id }))
        let peerPair = try await manager.readTokenPair(for: peerAfter)
        #expect(peerPair?.idToken == "id-peer-old")
        #expect(peerPair?.accessToken == "access-peer-old")

        var newcomerCount = 0
        for account in accounts {
            guard let data = try? await manager.accountAuthFile(account).data() else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if summary.email == "newcomer@example.com" {
                newcomerCount += 1
            }
        }
        #expect(newcomerCount == 1)
    }
    @Test("Given gateway virtual account is active, when preflight runs then it must not be restored back to normal snapshot")
    func preflightKeepsGatewayVirtualAccountActive() async throws {
        let root = try makeTempRoot("codex-auth-preflight-gateway-virtual")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let normal = try await manager.addAccount(
            name: "normal",
            authJSONString: #"{"tokens":{"id_token":"id-normal","access_token":"access-normal"},"email":"normal@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(normal, for: provider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: true, reason: "seed_backup")

        let virtual = try await manager.upsertGatewayVirtualAccount(
            providerID: "codex",
            name: "__gateway_reply__-codex",
            apiKey: "nolon-gateway-virtual-api-key",
            relay: .init(
                baseURL: "http://127.0.0.1:18080",
                modelProvider: "openai",
                queryParams: [
                    "nolon_gateway_virtual": "1",
                    "provider_id": "codex",
                ]
            )
        )
        try await manager.activateAccountAndMarkActive(virtual, for: provider)

        _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "gateway_virtual_reload")

        let activeID = try #require(await manager.activeAccountId(for: provider))
        #expect(activeID == virtual.id)
        let authFile = try #require(await manager.authFile(for: provider))
        let destination = try authFile.destinationOfSymbolicLink()
        let virtualFile = await manager.accountAuthFile(virtual)
        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(virtualFile.url.path).path)
    }
    @Test("Given gateway was activated via canonical codex provider, when custom codex provider preflight runs then auth symlink remains gateway virtual")
    func preflightKeepsGatewayVirtualWhenProviderIDDiffers() async throws {
        let root = try makeTempRoot("codex-auth-preflight-gateway-provider-id-mismatch")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let normal = try await manager.addAccount(
            name: "normal",
            authJSONString: #"{"tokens":{"id_token":"id-normal","access_token":"access-normal"},"email":"normal@example.com"}"#
        )

        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        let customProvider = Provider(
            id: "D3B087EE-4BBF-495E-BAC6-8FDEFB5B88B0",
            name: "Codex Custom",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let canonicalProvider = Provider(
            id: "codex",
            name: "Codex",
            defaultSkillsPath: providerRoot.folder("skills").url.path,
            workflowPath: providerRoot.folder("prompts").url.path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await manager.activateAccountAndMarkActive(normal, for: customProvider)
        _ = try await manager.preflightManagedAuthIfNeeded(for: customProvider, forceBackup: true, reason: "seed_custom_backup")

        let virtual = try await manager.upsertGatewayVirtualAccount(
            providerID: "codex",
            name: "__gateway_reply__-codex",
            apiKey: "nolon-gateway-virtual-api-key",
            relay: .init(
                baseURL: "http://127.0.0.1:18081",
                modelProvider: "openai",
                queryParams: [
                    "nolon_gateway_virtual": "1",
                    "provider_id": "codex",
                ]
            )
        )
        try await manager.activateAccountAndMarkActive(virtual, for: canonicalProvider)

        _ = try await manager.preflightManagedAuthIfNeeded(for: customProvider, forceBackup: false, reason: "gateway_custom_reload")

        let authFile = try #require(await manager.authFile(for: customProvider))
        let destination = try authFile.destinationOfSymbolicLink()
        let virtualFile = await manager.accountAuthFile(virtual)
        let activeID = await manager.activeAccountId(for: customProvider)

        #expect(STPath.standardizedPath(destination.url.path).path == STPath.standardizedPath(virtualFile.url.path).path)
        #expect(activeID == virtual.id)
    }
    @Test("Given duplicate snapshot ids and wrong relative path metadata, when loading accounts then id collision is healed and relative path is corrected")
    func loadAccountsHealsDuplicateIDsAndWrongRelativePath() async throws {
        let root = try makeTempRoot("codex-auth-heal-duplicate-id")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let canonical = try await manager.addAccount(
            name: "linhan",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"email":"canonical@example.com"}"#
        )
        let duplicate = try await manager.addAccount(
            name: "robbins",
            authJSONString: #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"email":"duplicate@example.com"}"#
        )

        let canonicalFile = await manager.accountAuthFile(canonical)
        let duplicateFile = await manager.accountAuthFile(duplicate)
        let canonicalRaw = try canonicalFile.read()
        let polluted = canonicalRaw
            .replacingOccurrences(of: "canonical@example.com", with: "duplicate@example.com")
            .replacingOccurrences(of: "\"id-1\"", with: "\"id-2\"")
            .replacingOccurrences(of: "\"access-1\"", with: "\"access-2\"")
        try duplicateFile.overlay(with: Data(polluted.utf8))

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 2)

        var accountByEmail: [String: CodexAuthAccount] = [:]
        for account in accounts {
            let summary = CodexAuthSummary.fromJSONData((try? await manager.accountAuthFile(account).data()) ?? Data())
            if let email = summary.email?.lowercased() {
                accountByEmail[email] = account
            }
        }

        let canonicalAfter = try #require(accountByEmail["canonical@example.com"])
        let duplicateAfter = try #require(accountByEmail["duplicate@example.com"])
        #expect(canonicalAfter.id == canonical.id)
        #expect(duplicateAfter.id != canonical.id)

        let duplicateAfterFile = await manager.accountAuthFile(duplicateAfter)
        let duplicateJSON = try #require(try? JSON(data: duplicateAfterFile.data()))
        #expect(duplicateJSON["nolon"]["account"]["relativeAuthPath"].string == duplicateAfter.relativeAuthPath)
        #expect(duplicateJSON["nolon"]["account"]["id"].string == duplicateAfter.id.uuidString)
    }
    @Test("Given duplicated snapshot payload in another file, when loading accounts then duplicate file is pruned")
    func loadAccountsPrunesDuplicatedSnapshotPayloadFile() async throws {
        let root = try makeTempRoot("codex-auth-prune-duplicate-payload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let canonical = try await manager.addAccount(
            name: "linhan",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"email":"canonical@example.com"}"#
        )
        let duplicate = try await manager.addAccount(
            name: "robbins",
            authJSONString: #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"email":"duplicate@example.com"}"#
        )

        let canonicalFile = await manager.accountAuthFile(canonical)
        let duplicateFile = await manager.accountAuthFile(duplicate)
        try duplicateFile.overlay(with: Data(try canonicalFile.read().utf8))

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        let kept = try #require(accounts.first)
        let keptSummary = CodexAuthSummary.fromJSONData((try? await manager.accountAuthFile(kept).data()) ?? Data())
        #expect(keptSummary.email?.lowercased() == "canonical@example.com")
        #expect(duplicateFile.isExists == false)
    }
    @Test("Given snapshot file name mismatched with email(account_id), when loading accounts then snapshot file is renamed to match email(account_id)")
    func loadAccountsAlignsSnapshotFileNameWithEmailAndAccountID() async throws {
        let root = try makeTempRoot("codex-auth-align-file-name")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "placeholder@example.com",
            authJSONString: #"{"email":"canonical@example.com","tokens":{"account_id":"acct-123","id_token":"id-1","access_token":"access-1"}}"#
        )

        let oldPath = account.relativeAuthPath
        let oldFile = await manager.accountAuthFile(account)
        #expect(oldFile.isExists == true)

        let accounts = try await manager.loadAccounts()
        let aligned = try #require(accounts.first(where: { $0.id == account.id }))
        #expect(aligned.relativeAuthPath == "auth/canonical@example.com(acct-123).json")

        let newFile = await manager.accountAuthFile(aligned)
        #expect(newFile.isExists == true)
        #expect(oldFile.isExists == false)

        let json = try #require(try? JSON(data: newFile.data()))
        #expect(json["nolon"]["account"]["relativeAuthPath"].string == aligned.relativeAuthPath)
        #expect((json["email"].string ?? "").lowercased() == "canonical@example.com")
        #expect(oldPath != aligned.relativeAuthPath)
    }
    @Test("Given snapshot missing email and using account.json, when backfilling email then load accounts aligns file name to email(account_id)")
    func backfillEmailEnablesEmailAccountIDAlignment() async throws {
        let root = try makeTempRoot("codex-auth-backfill-email-align")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "account",
            authJSONString: #"{"tokens":{"account_id":"acct-raw","id_token":"id-raw","access_token":"access-raw"}}"#
        )
        #expect(account.relativeAuthPath == "auth/account.json")

        try await manager.backfillEmailIfMissing(for: account, email: "fresh@example.com")

        let accounts = try await manager.loadAccounts()
        let aligned = try #require(accounts.first(where: { $0.id == account.id }))
        #expect(aligned.relativeAuthPath == "auth/fresh@example.com(acct-raw).json")

        let alignedFile = await manager.accountAuthFile(aligned)
        let json = try #require(try? JSON(data: alignedFile.data()))
        #expect((json["email"].string ?? "").lowercased() == "fresh@example.com")
        #expect((json["nolon"]["account"]["email"].string ?? "").lowercased() == "fresh@example.com")
    }
    @Test("Given selected validated import candidates, when exporting zip, then only selected valid candidates are archived")
    func exportSelectedValidatedImportCandidatesAsZip() async throws {
        let root = try makeTempRoot("codex-import-export-zip")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let selectedURL = root.url.appendingPathComponent("selected.json")
        let unselectedURL = root.url.appendingPathComponent("unselected.json")
        let invalidURL = root.url.appendingPathComponent("invalid.json")

        let selected = CodexAuthManager.CodexImportValidationResult(
            fileURL: selectedURL,
            isValid: true,
            reason: nil,
            suggestedName: "Selected",
            email: "selected@example.com",
            authJSONString: #"{"auth_mode":"chatgptAuthTokens","email":"selected@example.com","tokens":{"id_token":"id-selected","access_token":"access-selected"}}"#
        )
        let unselected = CodexAuthManager.CodexImportValidationResult(
            fileURL: unselectedURL,
            isValid: true,
            reason: nil,
            suggestedName: "Unselected",
            email: "unselected@example.com",
            authJSONString: #"{"auth_mode":"chatgptAuthTokens","email":"unselected@example.com","tokens":{"id_token":"id-unselected","access_token":"access-unselected"}}"#
        )
        let invalid = CodexAuthManager.CodexImportValidationResult(
            fileURL: invalidURL,
            isValid: false,
            reason: "Missing required credentials",
            suggestedName: nil,
            email: nil,
            authJSONString: nil
        )

        let destinationURL = root.url.appendingPathComponent("selected-imports.zip")
        let exportedCount = try await manager.exportValidatedAuthFilesArchive(
            results: [selected, invalid],
            destinationURL: destinationURL
        )
        let roundTripped = await manager.validateImportAuthFiles(urls: [destinationURL])

        #expect(exportedCount == 1)
        #expect(roundTripped.count == 1)
        #expect(roundTripped[0].isValid == true)
        #expect(roundTripped[0].email == "selected@example.com")
        #expect(roundTripped[0].fileURL.lastPathComponent.contains("selected"))
        #expect(roundTripped.allSatisfy { $0.email != unselected.email })
    }
}
