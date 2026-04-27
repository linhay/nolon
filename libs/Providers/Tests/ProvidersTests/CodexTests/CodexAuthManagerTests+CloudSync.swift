import Foundation
import Testing
import ProviderCatalog
import STFilePath
import STJSON
import SQLite3
@testable import ProviderUsage

extension CodexAuthManagerTests {
    func sqliteInt(databaseURL: URL, sql: String, bind: String) throws -> Int? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 41, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 42, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        _ = sqlite3_bind_text(statement, 1, bind, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        if sqlite3_column_type(statement, 0) == SQLITE_NULL {
            return nil
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    func sqliteColumnExists(databaseURL: URL, table: String, column: String) throws -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 51, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManagerTests.sqlite", code: 52, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let raw = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: raw) == column {
                return true
            }
        }
        return false
    }

    @Test("Given sqlite account storage, when schema is initialized, then cloud sync columns exist")
    func sqliteSchemaIncludesCloudSyncColumns() async throws {
        let root = try makeTempRoot("codex-auth-cloud-schema")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        _ = try await manager.addAccount(
            name: "cloud-schema",
            authJSONString: #"{"tokens":{"id_token":"id-cloud-schema","access_token":"access-cloud-schema"},"email":"cloud-schema@example.com"}"#
        )

        let databaseURL = manager.codexAccountsSQLiteDatabaseURL()
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_accounts", column: "cloud_record_name"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_accounts", column: "record_updated_at"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_accounts", column: "last_synced_at"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_accounts", column: "sync_status"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_accounts", column: "is_tombstone"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_account_metadata", column: "cloud_last_error"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_account_metadata", column: "cloud_last_error_at"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_account_metadata", column: "cloud_device_id"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_account_metadata", column: "cloud_conflict_payload_json"))
        #expect(try sqliteColumnExists(databaseURL: databaseURL, table: "codex_account_metadata", column: "cloud_record_system_fields_base64"))
    }

    @Test("Given existing account, when loading cloud sync state, then defaults are localOnly and not tombstoned")
    func loadCloudSyncStateDefaultsToLocalOnly() async throws {
        let root = try makeTempRoot("codex-auth-cloud-default-state")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "local-only",
            authJSONString: #"{"tokens":{"id_token":"id-local-only","access_token":"access-local-only"},"email":"local-only@example.com"}"#
        )

        let state = try await manager.cloudSyncState(for: account.id)
        let resolved = try #require(state)
        #expect(resolved.syncStatus == .localOnly)
        #expect(resolved.isTombstone == false)
        #expect(resolved.cloudRecordName == nil)
    }

    @Test("Given default cloud sync configuration, when loading without settings file, then sync starts disabled")
    func cloudSyncConfigurationDefaultsToDisabled() async throws {
        let root = try makeTempRoot("codex-auth-cloud-config-default")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let configuration = try await manager.cloudSyncConfiguration()
        #expect(configuration.isEnabled == false)
    }

    @Test("Given cloud sync enabled, when adding account, then local mutation becomes pending upload with stable record name")
    func addAccountMarksPendingUploadWhenCloudSyncEnabled() async throws {
        let root = try makeTempRoot("codex-auth-cloud-add-pending-upload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)

        let account = try await manager.addAccount(
            name: "cloud-add",
            authJSONString: #"{"tokens":{"id_token":"id-cloud-add","access_token":"access-cloud-add"},"email":"cloud-add@example.com"}"#
        )

        let state = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(state.syncStatus == .pendingUpload)
        #expect(state.isTombstone == false)
        #expect(state.cloudRecordName == account.id.uuidString)
        #expect(state.recordUpdatedAt != nil)
    }

    @Test("Given cloud sync enabled, when updating account, then record stays pending upload and record timestamp advances")
    func updateAccountRefreshesPendingUploadStateWhenCloudSyncEnabled() async throws {
        let root = try makeTempRoot("codex-auth-cloud-update-pending-upload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)
        let account = try await manager.addAccount(
            name: "cloud-update",
            authJSONString: #"{"tokens":{"id_token":"id-cloud-update","access_token":"access-cloud-update"},"email":"cloud-update@example.com"}"#
        )
        let firstState = try #require(try await manager.cloudSyncState(for: account.id))

        try await manager.updateAccount(
            account,
            authJSONString: #"{"tokens":{"id_token":"id-cloud-update-2","access_token":"access-cloud-update-2"},"email":"cloud-update@example.com"}"#
        )

        let updatedState = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(updatedState.syncStatus == .pendingUpload)
        #expect(updatedState.isTombstone == false)
        #expect(updatedState.cloudRecordName == account.id.uuidString)
        #expect(updatedState.recordUpdatedAt != nil)
        #expect((updatedState.recordUpdatedAt ?? .distantPast) >= (firstState.recordUpdatedAt ?? .distantPast))
    }

    @Test("Given existing account, when marking pending cloud deletion, then tombstone state persists in sqlite")
    func markPendingCloudDeletionPersistsState() async throws {
        let root = try makeTempRoot("codex-auth-cloud-pending-delete")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "pending-delete",
            authJSONString: #"{"tokens":{"id_token":"id-pending-delete","access_token":"access-pending-delete"},"email":"pending-delete@example.com"}"#
        )

        try await manager.markAccountPendingCloudDeletion(id: account.id)

        let state = try await manager.cloudSyncState(for: account.id)
        let resolved = try #require(state)
        #expect(resolved.syncStatus == .pendingDelete)
        #expect(resolved.isTombstone == true)

        let databaseURL = manager.codexAccountsSQLiteDatabaseURL()
        let storedStatus = try sqliteString(
            databaseURL: databaseURL,
            sql: "SELECT sync_status FROM codex_accounts WHERE id = ?;",
            bind: account.id.uuidString
        )
        let storedTombstone = try sqliteInt(
            databaseURL: databaseURL,
            sql: "SELECT is_tombstone FROM codex_accounts WHERE id = ?;",
            bind: account.id.uuidString
        )
        #expect(storedStatus == CodexCloudSyncStatus.pendingDelete.rawValue)
        #expect(storedTombstone == 1)
    }

    @Test("Given sent cloud record metadata, when marking sync success, then cloud system fields persist for the next upload")
    func markCloudSyncSentPersistsRecordSystemFields() async throws {
        let root = try makeTempRoot("codex-auth-cloud-system-fields")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "system-fields",
            authJSONString: #"{"tokens":{"id_token":"id-system","access_token":"access-system"},"email":"system@example.com"}"#
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 11),
                syncStatus: .pendingUpload,
                isTombstone: false
            )
        )

        let systemFieldsData = Data("encoded-system-fields".utf8)
        try await manager.markCloudSyncSent(
            recordName: account.id.uuidString,
            zoneName: "CodexAccounts",
            sentAt: Date(timeIntervalSince1970: 22),
            originDeviceID: "device-a",
            systemFieldsData: systemFieldsData
        )

        let state = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(state.syncStatus == .synced)
        #expect(state.recordSystemFieldsBase64 == systemFieldsData.base64EncodedString())
    }

    @Test("Given mixed cloud sync states, when reading management status, then cloud summary counters are aggregated")
    func managementStatusAggregatesCloudSyncCounters() async throws {
        let root = try makeTempRoot("codex-auth-cloud-management-status")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let synced = try await manager.addAccount(
            name: "synced",
            authJSONString: #"{"tokens":{"id_token":"id-synced","access_token":"access-synced"},"email":"synced@example.com"}"#
        )
        let pending = try await manager.addAccount(
            name: "pending",
            authJSONString: #"{"tokens":{"id_token":"id-pending","access_token":"access-pending"},"email":"pending@example.com"}"#
        )
        let conflict = try await manager.addAccount(
            name: "conflict",
            authJSONString: #"{"tokens":{"id_token":"id-conflict","access_token":"access-conflict"},"email":"conflict@example.com"}"#
        )
        let invalid = try await manager.addAccount(
            name: "invalid",
            authJSONString: #"{"tokens":{"id_token":"id-invalid","access_token":"access-invalid"},"email":"invalid@example.com"}"#
        )

        try await manager.applyCloudSyncState(.init(accountID: synced.id, syncStatus: .synced, isTombstone: false))
        try await manager.applyCloudSyncState(.init(accountID: pending.id, syncStatus: .pendingUpload, isTombstone: false))
        try await manager.applyCloudSyncState(.init(accountID: conflict.id, syncStatus: .conflict, isTombstone: false))
        try await manager.applyCloudSyncState(.init(accountID: invalid.id, syncStatus: .invalidPending, isTombstone: true))

        let status = await manager.managementStatus(for: provider)
        #expect(status.snapshotCount == 4)
        #expect(status.cloudSyncedCount == 1)
        #expect(status.cloudPendingCount == 1)
        #expect(status.cloudConflictCount == 1)
        #expect(status.cloudInvalidPendingCount == 1)
    }

    @Test("Given cloud sync enabled, when deleting account, then account is hidden locally but tombstone row stays pending delete")
    func deleteAccountMarksPendingDeleteWhenCloudSyncEnabled() async throws {
        let root = try makeTempRoot("codex-auth-cloud-delete-pending-delete")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)
        let account = try await manager.addAccount(
            name: "cloud-delete",
            authJSONString: #"{"tokens":{"id_token":"id-cloud-delete","access_token":"access-cloud-delete"},"email":"cloud-delete@example.com"}"#
        )

        try await manager.deleteAccount(id: account.id)

        let loadedAccounts = try await manager.loadAccounts()
        #expect(loadedAccounts.isEmpty)

        let state = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(state.syncStatus == .pendingDelete)
        #expect(state.isTombstone == true)

        let databaseURL = manager.codexAccountsSQLiteDatabaseURL()
        let accountRows = try sqliteCount(
            databaseURL: databaseURL,
            sql: "SELECT COUNT(*) FROM codex_accounts WHERE id = ?;",
            bind: account.id.uuidString
        )
        #expect(accountRows == 1)
    }

    @Test("Given hidden tombstone and latest error metadata, when reading cloud sync overview, then pending deletes and error summary stay visible")
    func cloudSyncOverviewIncludesHiddenPendingDeleteAndLatestError() async throws {
        let root = try makeTempRoot("codex-auth-cloud-overview")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)

        let synced = try await manager.addAccount(
            name: "overview-synced",
            authJSONString: #"{"tokens":{"id_token":"id-overview-synced","access_token":"access-overview-synced"},"email":"overview-synced@example.com"}"#
        )
        let failed = try await manager.addAccount(
            name: "overview-failed",
            authJSONString: #"{"tokens":{"id_token":"id-overview-failed","access_token":"access-overview-failed"},"email":"overview-failed@example.com"}"#
        )
        let deleted = try await manager.addAccount(
            name: "overview-deleted",
            authJSONString: #"{"tokens":{"id_token":"id-overview-deleted","access_token":"access-overview-deleted"},"email":"overview-deleted@example.com"}"#
        )

        try await manager.applyCloudSyncState(
            .init(
                accountID: synced.id,
                cloudRecordName: synced.id.uuidString,
                recordUpdatedAt: Date(timeIntervalSince1970: 100),
                lastSyncedAt: Date(timeIntervalSince1970: 200),
                syncStatus: .synced,
                isTombstone: false
            )
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: failed.id,
                cloudRecordName: failed.id.uuidString,
                recordUpdatedAt: Date(timeIntervalSince1970: 300),
                lastSyncedAt: Date(timeIntervalSince1970: 250),
                syncStatus: .pendingUpload,
                isTombstone: false,
                lastError: "network timeout",
                lastErrorAt: Date(timeIntervalSince1970: 400)
            )
        )
        try await manager.deleteAccount(id: deleted.id)

        let overview = try await manager.cloudSyncOverview()
        #expect(overview.totalRecordCount == 3)
        #expect(overview.syncedCount == 1)
        #expect(overview.pendingCount == 2)
        #expect(overview.conflictCount == 0)
        #expect(overview.invalidPendingCount == 0)
        #expect(overview.lastSyncedAt == Date(timeIntervalSince1970: 250))
        #expect(overview.recentError == "network timeout")
        #expect(overview.recentErrorAt == Date(timeIntervalSince1970: 400))
    }

    @Test("Given matching hash without account id, when merge policy applies remote newer payload, then sync timestamps never move backwards")
    func mergePolicyPreservesLatestSyncMetadataForHashMatchedAccounts() throws {
        let local = #"""
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "id_token": "same-id",
            "access_token": "same-access"
          },
          "email": "merge@example.com",
          "nolon": {
            "account": {
              "lastLoginAt": "2026-04-24T10:00:00Z",
              "lastSyncSucceededAt": "2026-04-24T11:00:00Z",
              "lastSyncFailedAt": "2026-04-24T08:00:00Z",
              "lastSyncFailureMessage": "older failure"
            }
          }
        }
        """#
        let remote = #"""
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "id_token": "same-id",
            "access_token": "same-access"
          },
          "email": "merge@example.com",
          "nolon": {
            "account": {
              "lastLoginAt": "2026-04-25T10:00:00Z",
              "lastSyncSucceededAt": "2026-04-23T11:00:00Z",
              "lastSyncFailedAt": "2026-04-25T12:00:00Z",
              "lastSyncFailureMessage": "newer failure"
            }
          }
        }
        """#

        let merged = try CodexAccountCloudMergePolicy.mergeAuthData(
            localAuthData: Data(local.utf8),
            remoteAuthData: Data(remote.utf8),
            localRecordUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-24T10:00:00Z"),
            remoteRecordUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-25T10:00:00Z")
        )
        let json = try JSON(data: merged)
        #expect(json["nolon"]["account"]["lastLoginAt"].string == "2026-04-25T10:00:00Z")
        #expect(json["nolon"]["account"]["lastSyncSucceededAt"].string == "2026-04-24T11:00:00Z")
        #expect(json["nolon"]["account"]["lastSyncFailedAt"].string == "2026-04-25T12:00:00Z")
        #expect(json["nolon"]["account"]["lastSyncFailureMessage"].string == "newer failure")
    }

    @Test("Given active account already invalidated by cloud tombstone, when preflight runs, then manager throws explicit cloud sync block")
    func preflightThrowsForInvalidPendingCloudState() async throws {
        let root = try makeTempRoot("codex-auth-cloud-invalid-pending")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let account = try await manager.addAccount(
            name: "invalid-pending",
            authJSONString: #"{"tokens":{"id_token":"id-invalid-pending","access_token":"access-invalid-pending"},"email":"invalid-pending@example.com"}"#
        )
        try await manager.activateAccountAndMarkActive(account, for: provider)
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: nil,
                recordUpdatedAt: Date(),
                lastSyncedAt: Date(),
                syncStatus: .invalidPending,
                isTombstone: true,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: "device-a",
                conflictPayloadJSONString: nil
            )
        )

        await #expect(throws: CodexCloudSyncPreflightBlock.self) {
            _ = try await manager.preflightManagedAuthIfNeeded(for: provider, forceBackup: false, reason: "cloud_invalid_pending")
        }
    }

    @Test("Given non-active account receives remote tombstone, when applying cloud tombstone, then account is removed locally")
    func applyCloudTombstoneRemovesNonActiveAccount() async throws {
        let root = try makeTempRoot("codex-auth-cloud-tombstone-remove")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "to-remove",
            authJSONString: #"{"tokens":{"id_token":"id-remove","access_token":"access-remove"},"email":"remove@example.com"}"#
        )

        let result = try await manager.applyRemoteCloudTombstone(accountID: account.id, provider: nil)
        #expect(result == .removedLocally)
        #expect(try await manager.loadAccounts().isEmpty)
        #expect(try await manager.cloudSyncState(for: account.id) == nil)
    }

    @Test("Given existing local-only accounts, when enabling cloud sync, then current rows are queued for first upload")
    func enablingCloudSyncQueuesExistingAccountsForUpload() async throws {
        let root = try makeTempRoot("codex-auth-cloud-enable-existing-upload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "existing-local",
            authJSONString: #"{"tokens":{"id_token":"id-existing-local","access_token":"access-existing-local"},"email":"existing-local@example.com"}"#
        )

        let before = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(before.syncStatus == .localOnly)

        try await manager.setCloudSyncEnabled(true)

        let after = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(after.syncStatus == .pendingUpload)
        #expect(after.isTombstone == false)
        #expect(after.cloudRecordName == account.id.uuidString)
        #expect(after.recordUpdatedAt != nil)
    }

    @Test("Given hidden pending-delete rows, when exporting pending cloud changes, then tombstones stay in the outbound queue")
    func cloudSyncPendingChangesIncludesHiddenPendingDeletes() async throws {
        let root = try makeTempRoot("codex-auth-cloud-pending-changes")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)

        let upload = try await manager.addAccount(
            name: "pending-upload",
            authJSONString: #"{"tokens":{"id_token":"id-pending-upload","access_token":"access-pending-upload"},"email":"pending-upload@example.com"}"#
        )
        let deleted = try await manager.addAccount(
            name: "pending-delete",
            authJSONString: #"{"tokens":{"id_token":"id-pending-delete","access_token":"access-pending-delete"},"email":"pending-delete@example.com"}"#
        )
        try await manager.deleteAccount(id: deleted.id)

        let pending = try await manager.cloudSyncPendingChanges()
        #expect(pending.count == 2)

        let uploadChange = try #require(pending.first(where: { $0.account.id == upload.id }))
        #expect(uploadChange.state.syncStatus == .pendingUpload)
        #expect(uploadChange.authData != nil)

        let deleteChange = try #require(pending.first(where: { $0.account.id == deleted.id }))
        #expect(deleteChange.state.syncStatus == .pendingDelete)
        #expect(deleteChange.state.isTombstone == true)
        #expect(deleteChange.authData == nil)
    }

    @Test("Given remote cloud record payload, when applying it locally, then account is materialized and marked synced")
    func applyRemoteCloudRecordCreatesLocalAccountAndMarksSynced() async throws {
        let root = try makeTempRoot("codex-auth-cloud-apply-remote-record")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let accountID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_713_999_999)
        let authJSONString = """
        {
          "tokens": {
            "id_token": "id-remote-record",
            "access_token": "access-remote-record"
          },
          "email": "remote-record@example.com"
        }
        """

        let created = try await manager.applyRemoteCloudRecord(
            CodexCloudSyncRecordPayload(
                recordName: accountID.uuidString,
                zoneName: "CodexAccounts",
                accountPayloadData: Data(authJSONString.utf8),
                metadataJSONString: nil,
                recordUpdatedAt: updatedAt,
                isTombstone: false,
                originDeviceID: "device-b",
                schemaVersion: 1
            ),
            provider: nil
        )

        let account = try #require(created)
        #expect(account.id == accountID)

        let accounts = try await manager.loadAccounts()
        #expect(accounts.count == 1)
        #expect(accounts.first?.id == accountID)

        let synced = try #require(try await manager.cloudSyncState(for: accountID))
        #expect(synced.syncStatus == .synced)
        #expect(synced.isTombstone == false)
        #expect(synced.cloudRecordName == accountID.uuidString)
        #expect(synced.cloudRecordZone == "CodexAccounts")
        #expect(synced.recordUpdatedAt == updatedAt)
        #expect(synced.deviceID == "device-b")
        #expect(synced.lastSyncedAt != nil)
    }

    @Test("Given invalid pending cloud state, when retrying upload, then account returns to pendingUpload and clears tombstone error")
    func retryCloudSyncUploadResolvesInvalidPendingToPendingUpload() async throws {
        let root = try makeTempRoot("codex-auth-cloud-retry-upload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "retry-upload",
            authJSONString: #"{"tokens":{"id_token":"id-retry-upload","access_token":"access-retry-upload"},"email":"retry-upload@example.com"}"#
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 100),
                lastSyncedAt: Date(timeIntervalSince1970: 90),
                syncStatus: .invalidPending,
                isTombstone: true,
                lastError: "cloud tombstone blocked activation",
                lastErrorAt: Date(timeIntervalSince1970: 101),
                deviceID: "device-a",
                conflictPayloadJSONString: #"{"reason":"tombstone"}"#
            )
        )

        try await manager.retryCloudSyncUpload(accountID: account.id)

        let state = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(state.syncStatus == .pendingUpload)
        #expect(state.isTombstone == false)
        #expect(state.cloudRecordName == account.id.uuidString)
        #expect(state.lastError == nil)
        #expect(state.lastErrorAt == nil)
        #expect(state.conflictPayloadJSONString == nil)
    }

    @Test("Given server-record-changed failure with remote payload, when persisting cloud sync failure, then conflict payload is stored for later resolution")
    func markCloudSyncFailedStoresConflictPayloadForLaterResolution() async throws {
        let root = try makeTempRoot("codex-auth-cloud-store-conflict-payload")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let account = try await manager.addAccount(
            name: "store-conflict",
            authJSONString: #"{"tokens":{"id_token":"id-store-conflict","access_token":"access-store-conflict"},"email":"store-conflict@example.com"}"#
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 10),
                lastSyncedAt: Date(timeIntervalSince1970: 9),
                syncStatus: .pendingUpload,
                isTombstone: false
            )
        )

        let conflictPayload = CodexCloudSyncRecordPayload(
            recordName: account.id.uuidString,
            zoneName: "CodexAccounts",
            accountPayloadData: Data(#"{"tokens":{"id_token":"id-remote","access_token":"access-remote"},"email":"remote-conflict@example.com"}"#.utf8),
            metadataJSONString: nil,
            recordUpdatedAt: Date(timeIntervalSince1970: 11),
            isTombstone: false,
            originDeviceID: "device-remote",
            schemaVersion: 1
        )

        try await manager.markCloudSyncFailed(
            recordName: account.id.uuidString,
            message: "Server record changed",
            at: Date(timeIntervalSince1970: 12),
            suggestedStatus: .conflict,
            conflictPayload: conflictPayload
        )

        let state = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(state.syncStatus == .conflict)
        #expect(state.lastError == "Server record changed")
        #expect(CodexCloudSyncRecordPayload.decoded(from: state.conflictPayloadJSONString) == conflictPayload)
    }

    @Test("Given active invalid pending account, when discarding local managed residue, then active mapping auth file and sqlite row are removed")
    func discardInvalidPendingManagedAccountRemovesLocalResidue() async throws {
        let root = try makeTempRoot("codex-auth-cloud-discard-invalid")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let account = try await manager.addAccount(
            name: "discard-invalid",
            authJSONString: #"{"tokens":{"id_token":"id-discard-invalid","access_token":"access-discard-invalid"},"email":"discard-invalid@example.com"}"#
        )
        try await manager.activateAccountAndMarkActive(account, for: provider)
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(),
                lastSyncedAt: Date(),
                syncStatus: .invalidPending,
                isTombstone: true,
                lastError: "cloud tombstone blocked activation"
            )
        )

        try await manager.discardInvalidPendingManagedAccount(id: account.id, providers: [provider])

        #expect(try await manager.loadAccounts().isEmpty)
        #expect(await manager.activeAccountId(for: provider) == nil)
        #expect(try await manager.cloudSyncState(for: account.id) == nil)
        let providerAuthFile = try #require(await manager.authFile(for: provider))
        #expect(providerAuthFile.isExists == false)
        #expect(providerAuthFile.isSymbolicLink == false)
    }

    @Test("Given synced and pending cloud rows, when resetting metadata after remote purge, then all accounts fall back to localOnly without cloud linkage")
    func resetCloudSyncMetadataAfterRemotePurgeMakesAllRowsLocalOnly() async throws {
        let root = try makeTempRoot("codex-auth-cloud-reset-after-purge")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let synced = try await manager.addAccount(
            name: "synced",
            authJSONString: #"{"tokens":{"id_token":"id-reset-synced","access_token":"access-reset-synced"},"email":"reset-synced@example.com"}"#
        )
        let pending = try await manager.addAccount(
            name: "pending",
            authJSONString: #"{"tokens":{"id_token":"id-reset-pending","access_token":"access-reset-pending"},"email":"reset-pending@example.com"}"#
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: synced.id,
                cloudRecordName: synced.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 1),
                lastSyncedAt: Date(timeIntervalSince1970: 2),
                syncStatus: .synced,
                isTombstone: false,
                lastError: "old error",
                lastErrorAt: Date(timeIntervalSince1970: 3),
                deviceID: "device-a"
            )
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: pending.id,
                cloudRecordName: pending.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 4),
                lastSyncedAt: nil,
                syncStatus: .pendingUpload,
                isTombstone: false,
                lastError: "pending",
                lastErrorAt: Date(timeIntervalSince1970: 5),
                deviceID: "device-b"
            )
        )

        try await manager.resetCloudSyncMetadataAfterRemotePurge()

        let syncedState = try #require(try await manager.cloudSyncState(for: synced.id))
        #expect(syncedState.syncStatus == .localOnly)
        #expect(syncedState.cloudRecordName == nil)
        #expect(syncedState.lastSyncedAt == nil)
        #expect(syncedState.lastError == nil)

        let pendingState = try #require(try await manager.cloudSyncState(for: pending.id))
        #expect(pendingState.syncStatus == .localOnly)
        #expect(pendingState.cloudRecordZone == nil)
        #expect(pendingState.recordUpdatedAt == nil)
        #expect(pendingState.deviceID == nil)
    }

    @Test("Given conflict state with stored remote payload, when adopting remote cloud version, then local snapshot and active auth file both switch to the remote payload")
    func adoptRemoteCloudConflictOverwritesLocalSnapshotAndActiveAuthFile() async throws {
        let root = try makeTempRoot("codex-auth-cloud-adopt-remote-conflict")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        let provider = makeCodexProvider(root: root)
        let account = try await manager.addAccount(
            name: "local-conflict",
            authJSONString: #"{"tokens":{"id_token":"id-local-conflict","access_token":"access-local-conflict"},"email":"local-conflict@example.com"}"#
        )
        try await manager.activateAccountAndMarkActive(account, for: provider)

        let remoteAuthJSONString = #"{"tokens":{"id_token":"id-remote-conflict","access_token":"access-remote-conflict"},"email":"remote-conflict@example.com"}"#
        let conflictPayload = CodexCloudSyncRecordPayload(
            recordName: account.id.uuidString,
            zoneName: "CodexAccounts",
            accountPayloadData: Data(remoteAuthJSONString.utf8),
            metadataJSONString: nil,
            recordUpdatedAt: Date(timeIntervalSince1970: 50),
            isTombstone: false,
            originDeviceID: "device-remote",
            schemaVersion: 1
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 40),
                lastSyncedAt: Date(timeIntervalSince1970: 39),
                syncStatus: .conflict,
                isTombstone: false,
                lastError: "Server record changed",
                lastErrorAt: Date(timeIntervalSince1970: 41),
                deviceID: "device-local",
                conflictPayloadJSONString: conflictPayload.encodedJSONString()
            )
        )

        let adopted = try await manager.adoptRemoteCloudConflict(accountID: account.id, providers: [provider])
        let refreshed = try #require(adopted)
        let storedData = try await manager.readAccountAuthData(refreshed)
        let storedSummary = CodexAuthSummary.fromJSONData(storedData)
        #expect(storedSummary.email == "remote-conflict@example.com")

        let state = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(state.syncStatus == .synced)
        #expect(state.lastError == nil)
        #expect(state.conflictPayloadJSONString == nil)
        #expect(state.deviceID == "device-remote")

        let providerAuthFile = try #require(await manager.authFile(for: provider))
        let providerData = try providerAuthFile.data()
        let providerSummary = CodexAuthSummary.fromJSONData(providerData)
        #expect(providerSummary.email == "remote-conflict@example.com")
    }

    @Test("Given conflict state with stored remote payload, when keeping both, then local account stays put and duplicated remote account is created with a stable iCloud suffix")
    func splitCloudConflictKeepingBothCreatesDuplicatedPendingUploadAccount() async throws {
        let root = try makeTempRoot("codex-auth-cloud-keep-both")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)
        let account = try await manager.addAccount(
            name: "keep-both@example.com",
            authJSONString: #"{"tokens":{"id_token":"id-keep-both-local","access_token":"access-keep-both-local"},"email":"keep-both@example.com"}"#
        )
        try await manager.markCloudSyncSent(
            recordName: account.id.uuidString,
            zoneName: "CodexAccounts",
            sentAt: Date(timeIntervalSince1970: 10),
            originDeviceID: "device-local"
        )

        let conflictPayload = CodexCloudSyncRecordPayload(
            recordName: account.id.uuidString,
            zoneName: "CodexAccounts",
            accountPayloadData: Data(#"{"tokens":{"id_token":"id-keep-both-remote","access_token":"access-keep-both-remote"},"email":"keep-both@example.com"}"#.utf8),
            metadataJSONString: nil,
            recordUpdatedAt: Date(timeIntervalSince1970: 11),
            isTombstone: false,
            originDeviceID: "device-remote",
            schemaVersion: 1
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 10),
                lastSyncedAt: Date(timeIntervalSince1970: 10),
                syncStatus: .conflict,
                isTombstone: false,
                lastError: "Server record changed",
                lastErrorAt: Date(timeIntervalSince1970: 12),
                deviceID: "device-local",
                conflictPayloadJSONString: conflictPayload.encodedJSONString()
            )
        )

        let result = try await manager.splitCloudConflictKeepingBoth(accountID: account.id)
        let duplicated = try #require(result?.duplicated)
        #expect(duplicated.id != account.id)
        #expect(duplicated.name == "keep-both@example.com (iCloud)")

        let accounts = try await manager.loadAccounts().sorted { $0.createdAt < $1.createdAt }
        #expect(accounts.count == 2)
        #expect(Set(accounts.map(\.name)) == ["keep-both@example.com", "keep-both@example.com (iCloud)"])

        let keptState = try #require(try await manager.cloudSyncState(for: account.id))
        #expect(keptState.syncStatus == .pendingUpload)
        #expect(keptState.conflictPayloadJSONString == nil)

        let duplicatedState = try #require(try await manager.cloudSyncState(for: duplicated.id))
        #expect(duplicatedState.syncStatus == .pendingUpload)
        #expect(duplicatedState.cloudRecordName == duplicated.id.uuidString)
        #expect(duplicatedState.deviceID == "device-remote")

        let pending = try await manager.cloudSyncPendingChanges()
        #expect(Set(pending.map(\.account.id)) == [account.id, duplicated.id])

        let duplicatedData = try await manager.readAccountAuthData(duplicated)
        let duplicatedSummary = CodexAuthSummary.fromJSONData(duplicatedData)
        #expect(duplicatedSummary.email == "keep-both@example.com")
        #expect(duplicatedSummary.accountID == nil)
    }

    @Test("Given existing iCloud-suffixed duplicate, when keeping both again, then duplicated remote account gets the next stable suffix")
    func splitCloudConflictKeepingBothUsesIncrementingSuffixWhenNeeded() async throws {
        let root = try makeTempRoot("codex-auth-cloud-keep-both-suffix")
        defer { try? root.delete() }

        let manager = CodexAuthManager(rootURL: root.url)
        try await manager.setCloudSyncEnabled(true)
        let account = try await manager.addAccount(
            name: "suffix@example.com",
            authJSONString: #"{"tokens":{"id_token":"id-suffix-local","access_token":"access-suffix-local"},"email":"suffix@example.com"}"#
        )
        let existingDuplicate = try await manager.addAccount(
            name: "seed-duplicate",
            authJSONString: #"{"tokens":{"id_token":"id-suffix-existing","access_token":"access-suffix-existing"},"email":"suffix-icloud@example.com"}"#
        )
        let existingDuplicateData = try await manager.readAccountAuthData(existingDuplicate)
        try await manager.upsertCodexAccountInSQLite(
            CodexAuthAccount(
                id: existingDuplicate.id,
                name: "suffix@example.com (iCloud)",
                createdAt: existingDuplicate.createdAt,
                relativeAuthPath: existingDuplicate.relativeAuthPath
            ),
            authData: existingDuplicateData
        )
        let conflictPayload = CodexCloudSyncRecordPayload(
            recordName: account.id.uuidString,
            zoneName: "CodexAccounts",
            accountPayloadData: Data(#"{"tokens":{"id_token":"id-suffix-remote","access_token":"access-suffix-remote"},"email":"suffix@example.com"}"#.utf8),
            metadataJSONString: nil,
            recordUpdatedAt: Date(timeIntervalSince1970: 21),
            isTombstone: false,
            originDeviceID: "device-remote",
            schemaVersion: 1
        )
        try await manager.applyCloudSyncState(
            .init(
                accountID: account.id,
                cloudRecordName: account.id.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: Date(timeIntervalSince1970: 20),
                lastSyncedAt: Date(timeIntervalSince1970: 20),
                syncStatus: .conflict,
                isTombstone: false,
                lastError: "Server record changed",
                lastErrorAt: Date(timeIntervalSince1970: 22),
                deviceID: "device-local",
                conflictPayloadJSONString: conflictPayload.encodedJSONString()
            )
        )

        let result = try await manager.splitCloudConflictKeepingBoth(accountID: account.id)
        #expect(result?.duplicated.name == "suffix@example.com (iCloud 2)")
    }
}
