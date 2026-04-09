import Foundation
import OSLog
import CryptoKit
import Darwin
import STFilePath
import ProviderCatalog
import STJSON
import ProvidersShared
import SQLite3

extension CodexAuthManager {
    struct SQLiteCodexAccountRow {
        let id: UUID
        let name: String
        let createdAt: Date
        let identityKey: String?
    }

    nonisolated func codexAccountsSQLiteDatabaseURL() -> URL {
        accountsSQLiteFile().url
    }

    func migrateAccountsStoreToSQLiteIfNeeded() throws {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        let folderURL = dbURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        try ensureCodexAccountsSQLiteSchema(databaseURL: dbURL)
        try backfillCodexIdentityKeysIfNeeded(databaseURL: dbURL)

        let existingAccounts = try loadCodexAccountsFromSQLite()
        if existingAccounts.isEmpty {
            try importSnapshotAccountsIntoSQLite()
        }
        try importLegacyActiveAccountsFileIntoSQLiteIfNeeded()
        try migrateActiveAccountProviderKeysIfNeeded()
        try cleanupManagedSnapshotFilesIfNeeded()
    }

    func migrateActiveAccountProviderKeysIfNeeded() throws {
        let map = try loadActiveAccountMapFromSQLite()
        guard !map.isEmpty else { return }

        var migrated = map
        for provider in configuredProviders() {
            guard provider.kind == .vendor,
                  provider.vendorCategory == .original,
                  let canonical = Self.canonicalCodexActiveProviderKey(for: provider.templateId),
                  canonical != provider.id
            else {
                continue
            }
            if let accountID = migrated[provider.id], migrated[canonical] == nil {
                migrated[canonical] = accountID
            }
            migrated.removeValue(forKey: provider.id)
        }

        let sanitized = sanitizeActiveAccountMap(migrated)
        guard sanitized != map else { return }

        try saveActiveAccountMapToSQLite(sanitized)
        try writeActiveAccountMapJSONMirror(sanitized)
    }

    nonisolated func ensureCodexAccountsSQLiteSchema(databaseURL: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5_000)
        _ = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)

        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS codex_accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL,
                identity_key TEXT,
                updated_at TEXT NOT NULL
            );
            """
        )
        if try !sqliteColumnExists(db: db, table: "codex_accounts", column: "identity_key") {
            try executeSQLite(
                db,
                sql: "ALTER TABLE codex_accounts ADD COLUMN identity_key TEXT;"
            )
        }
        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS codex_active_accounts (
                provider_id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS codex_account_credentials (
                account_id TEXT PRIMARY KEY,
                id_token TEXT,
                access_token TEXT,
                refresh_token TEXT,
                provider_type TEXT NOT NULL DEFAULT 'codex',
                api_key TEXT,
                base_url TEXT,
                email TEXT,
                chatgpt_account_id TEXT,
                last_refresh TEXT,
                expires_at TEXT
            );
            """
        )
        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS codex_account_metadata (
                account_id TEXT PRIMARY KEY,
                auth_mode TEXT,
                openai_api_key TEXT,
                tokens_account_id TEXT,
                expires_at TEXT,
                email TEXT,
                plan_type TEXT,
                last_refresh TEXT,
                custom_group_name TEXT,
                nolon_account_kind TEXT,
                nolon_account_email TEXT,
                nolon_account_last_login_at TEXT,
                nolon_account_last_sync_succeeded_at TEXT,
                nolon_account_last_sync_failed_at TEXT,
                nolon_account_last_sync_failure_message TEXT,
                usage_cache_json TEXT,
                usage_query_json TEXT,
                relay_model_provider TEXT,
                relay_query_params_json TEXT,
                relay_headers_json TEXT,
                updated_at TEXT NOT NULL
            );
            """
        )
        if try !sqliteColumnExists(db: db, table: "codex_account_metadata", column: "custom_group_name") {
            try executeSQLite(
                db,
                sql: "ALTER TABLE codex_account_metadata ADD COLUMN custom_group_name TEXT;"
            )
        }
        if try !sqliteColumnExists(db: db, table: "codex_account_metadata", column: "plan_type") {
            try executeSQLite(
                db,
                sql: "ALTER TABLE codex_account_metadata ADD COLUMN plan_type TEXT;"
            )
        }
        if try !sqliteColumnExists(db: db, table: "codex_account_metadata", column: "relay_model_provider") {
            try executeSQLite(
                db,
                sql: "ALTER TABLE codex_account_metadata ADD COLUMN relay_model_provider TEXT;"
            )
        }
        if try !sqliteColumnExists(db: db, table: "codex_account_metadata", column: "relay_query_params_json") {
            try executeSQLite(
                db,
                sql: "ALTER TABLE codex_account_metadata ADD COLUMN relay_query_params_json TEXT;"
            )
        }
        if try !sqliteColumnExists(db: db, table: "codex_account_metadata", column: "relay_headers_json") {
            try executeSQLite(
                db,
                sql: "ALTER TABLE codex_account_metadata ADD COLUMN relay_headers_json TEXT;"
            )
        }
        try executeSQLite(
            db,
            sql: """
            CREATE INDEX IF NOT EXISTS idx_codex_accounts_created_at
            ON codex_accounts(created_at DESC);
            """
        )
        try executeSQLite(
            db,
            sql: """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_codex_accounts_identity_key
            ON codex_accounts(identity_key)
            WHERE identity_key IS NOT NULL AND identity_key <> '';
            """
        )
    }

    nonisolated func backfillCodexIdentityKeysIfNeeded(databaseURL: URL) throws {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return }
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let hasLegacyAuthJSON = (try? sqliteColumnExists(db: db, table: "codex_accounts", column: "auth_json")) ?? false
        let query = hasLegacyAuthJSON
            ? """
            SELECT id, auth_json
            FROM codex_accounts
            WHERE identity_key IS NULL OR identity_key = '';
            """
            : """
            SELECT id
            FROM codex_accounts
            WHERE identity_key IS NULL OR identity_key = '';
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare identity backfill query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        var updates: [(String, String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idRaw = sqlite3_column_text(statement, 0) else { continue }
            let id = String(cString: idRaw)
            let auth: String? = {
                if hasLegacyAuthJSON, let authRaw = sqlite3_column_text(statement, 1) {
                    return String(cString: authRaw)
                }
                guard let uuid = UUID(uuidString: id),
                      let data = try? loadCodexAccountAuthDataFromSQLite(accountID: uuid),
                      let raw = String(data: data, encoding: .utf8)
                else {
                    return nil
                }
                return raw
            }()
            guard let auth,
                  let identityKey = buildCredentialIdentityKey(authJSONString: auth)
            else { continue }
            updates.append((id, identityKey))
        }

        for (id, identityKey) in updates {
            try? executeSQLite(
                db,
                sql: "UPDATE codex_accounts SET identity_key = ? WHERE id = ?;",
                bindings: [.text(identityKey), .text(id)]
            )
        }
    }

    func importSnapshotAccountsIntoSQLite() throws {
        let folder = nolonCodexAuthFolder()
        let fileNames = stableAuthSnapshotFileNames(in: folder)
        guard !fileNames.isEmpty else { return }
        for fileName in fileNames {
            let relativeAuthPath = "auth/\(fileName)"
            let file = folder.file(fileName)
            do {
                if try shouldPruneSnapshotFileBeforeLoad(file: file, relativeAuthPath: relativeAuthPath) {
                    continue
                }
                let raw = try file.read()
                let data = try normalizeAccountPayloadData(
                    authJSONString: raw,
                    preferredId: UUID(),
                    preferredCreatedAt: Date(),
                    relativeAuthPath: relativeAuthPath
                )
                let account = accountFromNormalizedPayloadData(
                    data,
                    fallbackRelativeAuthPath: relativeAuthPath
                )
                try upsertCodexAccountInSQLite(account, authData: data)
            } catch {
                Self.logger.error("Failed to migrate snapshot account into SQLite. file=\(fileName, privacy: .public) error=\(String(describing: error), privacy: .public)")
            }
        }
        try cleanupManagedSnapshotFilesIfNeeded()
    }

    func importLegacyActiveAccountsFileIntoSQLiteIfNeeded() throws {
        let file = activeAccountsFile()
        guard file.isExists,
              let data = try? file.data(),
              !data.isEmpty,
              let root = Self.decodeJSONObject(from: data),
              let providers = root["providers"] as? JSONObject,
              !providers.isEmpty
        else { return }

        var merged = (try? loadActiveAccountMapFromSQLite()) ?? [:]
        for (providerID, accountID) in providers {
            guard let accountID = accountID as? String, UUID(uuidString: accountID) != nil else { continue }
            if merged[providerID] == nil {
                merged[providerID] = accountID
            }
        }
        try saveActiveAccountMapToSQLite(merged)
    }

    func loadCodexAccountsFromSQLite() throws -> [CodexAuthAccount] {
        let rows = try queryCodexAccountsRowsFromSQLite()
        return rows.map { row in
            CodexAuthAccount(
                id: row.id,
                name: row.name,
                createdAt: row.createdAt,
                relativeAuthPath: sqliteRelativeAuthPath(for: row.id)
            )
        }
    }

    nonisolated func queryCodexAccountsRowsFromSQLite() throws -> [SQLiteCodexAccountRow] {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT id, name, created_at, identity_key
        FROM codex_accounts
        ORDER BY created_at DESC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare SQLite accounts query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        var rows: [SQLiteCodexAccountRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCString = sqlite3_column_text(statement, 0),
                let nameCString = sqlite3_column_text(statement, 1),
                let createdAtCString = sqlite3_column_text(statement, 2)
            else { continue }

            let idString = String(cString: idCString)
            let name = String(cString: nameCString)
            let createdAtRaw = String(cString: createdAtCString)
            let identityKey = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            guard let id = UUID(uuidString: idString) else { continue }
            let createdAt = Self.makeISOFormatter().date(from: createdAtRaw) ?? Date(timeIntervalSince1970: 0)
            rows.append(
                SQLiteCodexAccountRow(
                    id: id,
                    name: name,
                    createdAt: createdAt,
                    identityKey: identityKey
                )
            )
        }
        return rows
    }

    func upsertCodexAccountInSQLite(_ account: CodexAuthAccount, authData: Data? = nil) throws {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        try ensureCodexAccountsSQLiteSchema(databaseURL: dbURL)
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let authJSONString: String
        if let authData, let raw = String(data: authData, encoding: .utf8), !raw.isEmpty {
            authJSONString = raw
        } else if let existing = try? loadCodexAccountAuthDataFromSQLite(accountID: account.id), let raw = String(data: existing, encoding: .utf8), !raw.isEmpty {
            authJSONString = raw
        } else {
            authJSONString = "{}"
        }

        let nowISO = Self.makeISOFormatter().string(from: Date())
        let identityKey = buildCredentialIdentityKey(authJSONString: authJSONString)

        if let identityKey,
           let existingByIdentity = try queryCodexAccountRowByIdentityKeyFromSQLite(db: db, identityKey: identityKey),
           existingByIdentity.id != account.id
        {
            let incomingScore = credentialUsabilityScore(authJSONString: authJSONString)
            let existingScore: Int = {
                guard let existingData = try? loadCodexAccountAuthDataFromSQLite(accountID: existingByIdentity.id),
                      let existingRaw = String(data: existingData, encoding: .utf8)
                else {
                    return 0
                }
                return credentialUsabilityScore(authJSONString: existingRaw)
            }()
            if existingScore > incomingScore {
                return
            }
            try executeSQLite(
                db,
                sql: "DELETE FROM codex_accounts WHERE id = ?;",
                bindings: [.text(existingByIdentity.id.uuidString)]
            )
            try executeSQLite(
                db,
                sql: """
                UPDATE codex_active_accounts
                SET account_id = ?, updated_at = ?
                WHERE account_id = ?;
                """,
                bindings: [
                    .text(account.id.uuidString),
                    .text(nowISO),
                    .text(existingByIdentity.id.uuidString),
                ]
            )
        }

        let hasLegacyRelativePathColumn = (try? sqliteColumnExists(db: db, table: "codex_accounts", column: "relative_auth_path")) ?? false
        let hasLegacyAuthJSONColumn = (try? sqliteColumnExists(db: db, table: "codex_accounts", column: "auth_json")) ?? false
        let upsertSQL: String
        var bindings: [SQLiteBindingValue]
        if hasLegacyRelativePathColumn && hasLegacyAuthJSONColumn {
            upsertSQL = """
            INSERT INTO codex_accounts (id, name, created_at, relative_auth_path, auth_json, identity_key, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name=excluded.name,
                created_at=excluded.created_at,
                relative_auth_path=excluded.relative_auth_path,
                auth_json=excluded.auth_json,
                identity_key=excluded.identity_key,
                updated_at=excluded.updated_at;
            """
            bindings = [
                .text(account.id.uuidString),
                .text(account.name),
                .text(Self.makeISOFormatter().string(from: account.createdAt)),
                .text(account.relativeAuthPath),
                .text(authJSONString),
                .nullableText(identityKey),
                .text(nowISO),
            ]
        } else {
            upsertSQL = """
            INSERT INTO codex_accounts (id, name, created_at, identity_key, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name=excluded.name,
                created_at=excluded.created_at,
                identity_key=excluded.identity_key,
                updated_at=excluded.updated_at;
            """
            bindings = [
                .text(account.id.uuidString),
                .text(account.name),
                .text(Self.makeISOFormatter().string(from: account.createdAt)),
                .nullableText(identityKey),
                .text(nowISO),
            ]
        }
        try executeSQLite(db, sql: upsertSQL, bindings: bindings)
        try upsertCodexCredentialsInSQLite(
            db: db,
            accountID: account.id,
            authJSONString: authJSONString
        )
        try upsertCodexAccountMetadataInSQLite(
            db: db,
            accountID: account.id,
            authJSONString: authJSONString,
            updatedAtISO: nowISO
        )
    }

    nonisolated func queryCodexAccountRowByIdentityKeyFromSQLite(
        db: OpaquePointer?,
        identityKey: String
    ) throws -> SQLiteCodexAccountRow? {
        let sql = """
        SELECT id, name, created_at, identity_key
        FROM codex_accounts
        WHERE identity_key = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare identity query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_text(statement, 1, identityKey, -1, sqliteTransientDestructor) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to bind identity key." : message,
            ])
        }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let idCString = sqlite3_column_text(statement, 0),
              let nameCString = sqlite3_column_text(statement, 1),
              let createdAtCString = sqlite3_column_text(statement, 2)
        else {
            return nil
        }

        let idString = String(cString: idCString)
        guard let id = UUID(uuidString: idString) else { return nil }
        let createdAtRaw = String(cString: createdAtCString)
        let createdAt = Self.makeISOFormatter().date(from: createdAtRaw) ?? Date(timeIntervalSince1970: 0)
        let identity = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        return SQLiteCodexAccountRow(
            id: id,
            name: String(cString: nameCString),
            createdAt: createdAt,
            identityKey: identity
        )
    }

    nonisolated func upsertCodexCredentialsInSQLite(
        db: OpaquePointer?,
        accountID: UUID,
        authJSONString: String
    ) throws {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else {
            return
        }

        let idToken = firstNonEmptyString(in: json, paths: [
            ["tokens", "id_token"], ["tokens", "idToken"], ["id_token"], ["idToken"],
        ])
        let accessToken = firstNonEmptyString(in: json, paths: [
            ["tokens", "access_token"], ["tokens", "accessToken"], ["access_token"], ["accessToken"],
        ])
        let refreshToken = firstNonEmptyString(in: json, paths: [
            ["tokens", "refresh_token"], ["tokens", "refreshToken"], ["refresh_token"], ["refreshToken"],
        ])
        let apiKey = firstNonEmptyString(in: json, paths: [
            ["OPENAI_API_KEY"], ["openai_api_key"], ["api_key"], ["apiKey"],
        ])
        let baseURL = firstNonEmptyString(in: json, paths: [
            ["base_url"], ["baseURL"], ["nolon", "relay", "base_url"],
        ])?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let email = deriveEmail(from: json)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let accountRaw = CodexAuthSummary.canonicalAccountID(json: json, payload: nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lastRefresh = firstNonEmptyString(in: json, paths: [["last_refresh"], ["lastRefresh"]])
        let expiresAt = firstNonEmptyString(in: json, paths: [
            ["expired"], ["expires_at"], ["expiresAt"],
            ["tokens", "expired"], ["tokens", "expires_at"], ["tokens", "expiresAt"],
        ])

        try executeSQLite(
            db,
            sql: """
            INSERT INTO codex_account_credentials (
                account_id, id_token, access_token, refresh_token, provider_type,
                api_key, base_url, email, chatgpt_account_id, last_refresh, expires_at
            )
            VALUES (?, ?, ?, ?, 'codex', ?, ?, ?, ?, ?, ?)
            ON CONFLICT(account_id) DO UPDATE SET
                id_token=excluded.id_token,
                access_token=excluded.access_token,
                refresh_token=excluded.refresh_token,
                api_key=excluded.api_key,
                base_url=excluded.base_url,
                email=excluded.email,
                chatgpt_account_id=excluded.chatgpt_account_id,
                last_refresh=excluded.last_refresh,
                expires_at=excluded.expires_at;
            """,
            bindings: [
                .text(accountID.uuidString),
                .nullableText(idToken),
                .nullableText(accessToken),
                .nullableText(refreshToken),
                .nullableText(apiKey),
                .nullableText(baseURL),
                .nullableText(email),
                .nullableText(accountRaw),
                .nullableText(lastRefresh),
                .nullableText(expiresAt),
            ]
        )
    }

    nonisolated func upsertCodexAccountMetadataInSQLite(
        db: OpaquePointer?,
        accountID: UUID,
        authJSONString: String,
        updatedAtISO: String
    ) throws {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else {
            return
        }

        let authMode = Self.canonicalAuthMode(firstNonEmptyString(in: json, paths: [["auth_mode"], ["authMode"]]))
        let openAIAPIKey = firstNonEmptyString(in: json, paths: [["OPENAI_API_KEY"], ["openai_api_key"]])
        let tokensAccountID = firstNonEmptyString(in: json, paths: [
            ["tokens", "account_id"], ["tokens", "accountId"], ["account_id"], ["accountId"],
        ])
        let expiresAt = firstNonEmptyString(in: json, paths: [
            ["expires_at"], ["expiresAt"], ["expired"],
            ["tokens", "expires_at"], ["tokens", "expiresAt"], ["tokens", "expired"],
        ])
        let email = deriveEmail(from: json)
        let planType = firstNonEmptyString(in: json, paths: [
            ["plan_type"], ["planType"], ["plan"], ["subscription", "plan"], ["account", "plan"],
        ])
        let lastRefresh = firstNonEmptyString(in: json, paths: [["last_refresh"], ["lastRefresh"]])
        let customGroupName = firstNonEmptyString(in: json, paths: [["nolon", "custom_group_name"]])
        let kind = firstNonEmptyString(in: json, paths: [["nolon", "account", "kind"]])
        let nolonAccountEmail = firstNonEmptyString(in: json, paths: [["nolon", "account", "email"]])
        let lastLoginAt = firstNonEmptyString(in: json, paths: [["nolon", "account", "lastLoginAt"]])
        let lastSyncSucceededAt = firstNonEmptyString(in: json, paths: [["nolon", "account", "lastSyncSucceededAt"]])
        let lastSyncFailedAt = firstNonEmptyString(in: json, paths: [["nolon", "account", "lastSyncFailedAt"]])
        let lastSyncFailureMessage = firstNonEmptyString(in: json, paths: [["nolon", "account", "lastSyncFailureMessage"]])
        let usageCacheJSON = json["nolon"]["usage_cache"].rawString()
        let usageQueryJSON = json["nolon"]["usage_query"].rawString()
        let relayModelProvider = firstNonEmptyString(in: json, paths: [["nolon", "relay", "model_provider"]])
        let relayQueryParamsJSON = json["nolon"]["relay"]["query_params"].rawString()
        let relayHeadersJSON = json["nolon"]["relay"]["headers"].rawString()

        try executeSQLite(
            db,
            sql: """
            INSERT INTO codex_account_metadata (
                account_id, auth_mode, openai_api_key, tokens_account_id, expires_at, email, last_refresh,
                plan_type, custom_group_name, nolon_account_kind, nolon_account_email, nolon_account_last_login_at,
                nolon_account_last_sync_succeeded_at, nolon_account_last_sync_failed_at,
                nolon_account_last_sync_failure_message, usage_cache_json, usage_query_json,
                relay_model_provider, relay_query_params_json, relay_headers_json, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(account_id) DO UPDATE SET
                auth_mode=excluded.auth_mode,
                openai_api_key=excluded.openai_api_key,
                tokens_account_id=excluded.tokens_account_id,
                expires_at=excluded.expires_at,
                email=excluded.email,
                plan_type=COALESCE(excluded.plan_type, codex_account_metadata.plan_type),
                last_refresh=excluded.last_refresh,
                custom_group_name=COALESCE(excluded.custom_group_name, codex_account_metadata.custom_group_name),
                nolon_account_kind=excluded.nolon_account_kind,
                nolon_account_email=excluded.nolon_account_email,
                nolon_account_last_login_at=excluded.nolon_account_last_login_at,
                nolon_account_last_sync_succeeded_at=excluded.nolon_account_last_sync_succeeded_at,
                nolon_account_last_sync_failed_at=excluded.nolon_account_last_sync_failed_at,
                nolon_account_last_sync_failure_message=excluded.nolon_account_last_sync_failure_message,
                usage_cache_json=excluded.usage_cache_json,
                usage_query_json=excluded.usage_query_json,
                relay_model_provider=excluded.relay_model_provider,
                relay_query_params_json=excluded.relay_query_params_json,
                relay_headers_json=excluded.relay_headers_json,
                updated_at=excluded.updated_at;
            """,
            bindings: [
                .text(accountID.uuidString),
                .nullableText(authMode),
                .nullableText(openAIAPIKey),
                .nullableText(tokensAccountID),
                .nullableText(expiresAt),
                .nullableText(email),
                .nullableText(lastRefresh),
                .nullableText(planType),
                .nullableText(customGroupName),
                .nullableText(kind),
                .nullableText(nolonAccountEmail),
                .nullableText(lastLoginAt),
                .nullableText(lastSyncSucceededAt),
                .nullableText(lastSyncFailedAt),
                .nullableText(lastSyncFailureMessage),
                .nullableText(usageCacheJSON),
                .nullableText(usageQueryJSON),
                .nullableText(relayModelProvider),
                .nullableText(relayQueryParamsJSON),
                .nullableText(relayHeadersJSON),
                .text(updatedAtISO),
            ]
        )
    }

    nonisolated func loadCodexAccountAuthDataFromSQLite(accountID: UUID) throws -> Data? {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let hasLegacyAuthJSONColumn = (try? sqliteColumnExists(db: db, table: "codex_accounts", column: "auth_json")) ?? false
        let sql = """
        SELECT
            a.created_at,
            a.updated_at,
            c.id_token,
            c.access_token,
            c.refresh_token,
            c.api_key,
            c.base_url,
            c.email,
            c.chatgpt_account_id,
            c.last_refresh,
            c.expires_at,
            m.auth_mode,
            m.openai_api_key,
            m.tokens_account_id,
            m.expires_at,
            m.email,
            m.plan_type,
            m.last_refresh,
            m.custom_group_name,
            m.nolon_account_kind,
            m.nolon_account_email,
            m.nolon_account_last_login_at,
            m.nolon_account_last_sync_succeeded_at,
            m.nolon_account_last_sync_failed_at,
            m.nolon_account_last_sync_failure_message,
            m.usage_cache_json,
            m.usage_query_json,
            m.relay_model_provider,
            m.relay_query_params_json,
            m.relay_headers_json
            \(hasLegacyAuthJSONColumn ? ", a.auth_json" : "")
        FROM codex_accounts a
        LEFT JOIN codex_account_credentials c ON c.account_id = a.id
        LEFT JOIN codex_account_metadata m ON m.account_id = a.id
        WHERE a.id = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare account auth query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_bind_text(statement, 1, accountID.uuidString, -1, sqliteTransientDestructor) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to bind account id." : message,
            ])
        }

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let text: (Int32) -> String? = { index in
            guard let raw = sqlite3_column_text(statement, index) else { return nil }
            let value = String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let createdAt = text(0)
        let updatedAt = text(1) ?? Self.makeISOFormatter().string(from: Date())
        let idToken = text(2)
        let accessToken = text(3)
        let refreshToken = text(4)
        let credentialAPIKey = text(5)
        let baseURL = text(6)
        let credentialEmail = text(7)
        let credentialAccountID = text(8)
        let credentialLastRefresh = text(9)
        let credentialExpiresAt = text(10)

        let authMode = Self.canonicalAuthMode(text(11))
        let metadataAPIKey = text(12)
        let metadataAccountID = text(13)
        let metadataExpiresAt = text(14)
        let metadataEmail = text(15)
        let metadataPlanType = text(16)
        let metadataLastRefresh = text(17)
        let customGroupName = text(18)
        let kind = text(19)
        let nolonAccountEmail = text(20)
        let lastLoginAt = text(21)
        let lastSyncSucceededAt = text(22)
        let lastSyncFailedAt = text(23)
        let lastSyncFailureMessage = text(24)
        let usageCacheJSON = text(25)
        let usageQueryJSON = text(26)
        let relayModelProvider = text(27)
        let relayQueryParamsJSON = text(28)
        let relayHeadersJSON = text(29)
        let legacyAuthJSON = hasLegacyAuthJSONColumn ? text(30) : nil

        let hasStructuredData = [
            idToken, accessToken, refreshToken, credentialAPIKey, baseURL, credentialEmail, credentialAccountID,
            authMode, metadataAPIKey, metadataAccountID, metadataEmail, metadataPlanType, customGroupName, kind,
            usageCacheJSON, usageQueryJSON, relayModelProvider, relayQueryParamsJSON, relayHeadersJSON,
        ].contains { $0 != nil }

        if !hasStructuredData, let legacyAuthJSON {
            return Data(legacyAuthJSON.utf8)
        }

        func decodeEmbeddedJSONObject(_ raw: String?) -> JSONObject? {
            guard let raw,
                  let data = raw.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject
            else {
                return nil
            }
            return object
        }

        var root: JSONObject = [:]
        if let resolvedAuthMode = authMode ?? ((metadataAPIKey ?? credentialAPIKey) != nil ? "apikey" : ((idToken ?? accessToken) != nil ? Self.canonicalChatGPTAuthMode : nil)) {
            root["auth_mode"] = resolvedAuthMode
        }
        if let apiKey = metadataAPIKey ?? credentialAPIKey {
            root["OPENAI_API_KEY"] = apiKey
        } else {
            root["OPENAI_API_KEY"] = NSNull()
        }
        if let email = metadataEmail ?? credentialEmail {
            root["email"] = email
        }
        if let planType = metadataPlanType {
            root["plan_type"] = planType
            root["plan"] = planType
        }
        if let lastRefresh = metadataLastRefresh ?? credentialLastRefresh {
            root["last_refresh"] = lastRefresh
        }
        if let expiresAt = metadataExpiresAt ?? credentialExpiresAt {
            root["expires_at"] = expiresAt
        }
        if let baseURL {
            root["base_url"] = baseURL
        }
        if baseURL != nil || relayModelProvider != nil || relayQueryParamsJSON != nil || relayHeadersJSON != nil {
            var relay: JSONObject = [:]
            if let baseURL { relay["base_url"] = baseURL }
            if let relayModelProvider { relay["model_provider"] = relayModelProvider }
            if let relayQueryParams = decodeEmbeddedJSONObject(relayQueryParamsJSON), !relayQueryParams.isEmpty {
                relay["query_params"] = relayQueryParams
            }
            if let relayHeaders = decodeEmbeddedJSONObject(relayHeadersJSON), !relayHeaders.isEmpty {
                relay["headers"] = relayHeaders
            }
            if !relay.isEmpty {
                var nolon = (root["nolon"] as? JSONObject) ?? [:]
                nolon["relay"] = relay
                root["nolon"] = nolon
            }
        }

        var tokens: JSONObject = [:]
        if let idToken { tokens["id_token"] = idToken }
        if let accessToken { tokens["access_token"] = accessToken }
        if let refreshToken { tokens["refresh_token"] = refreshToken }
        if let accountID = metadataAccountID ?? credentialAccountID {
            tokens["account_id"] = accountID
        }
        if !tokens.isEmpty {
            root["tokens"] = tokens
        } else {
            root["tokens"] = NSNull()
        }

        var nolonAccount: JSONObject = [
            "id": accountID.uuidString,
            "updatedAt": updatedAt,
            "relativeAuthPath": sqliteRelativeAuthPath(for: accountID),
        ]
        if let createdAt { nolonAccount["createdAt"] = createdAt }
        if let kind { nolonAccount["kind"] = kind }
        if let email = nolonAccountEmail ?? metadataEmail ?? credentialEmail {
            nolonAccount["email"] = email
        }
        if let lastLoginAt { nolonAccount["lastLoginAt"] = lastLoginAt }
        if let lastSyncSucceededAt { nolonAccount["lastSyncSucceededAt"] = lastSyncSucceededAt }
        if let lastSyncFailedAt { nolonAccount["lastSyncFailedAt"] = lastSyncFailedAt }
        if let lastSyncFailureMessage { nolonAccount["lastSyncFailureMessage"] = lastSyncFailureMessage }

        var nolonObject: JSONObject = (root["nolon"] as? JSONObject) ?? [:]
        nolonObject["account"] = nolonAccount
        if let customGroupName {
            nolonObject["custom_group_name"] = customGroupName
        }
        if let usageCache = decodeEmbeddedJSONObject(usageCacheJSON) {
            nolonObject["usage_cache"] = usageCache
        }
        if let usageQuery = decodeEmbeddedJSONObject(usageQueryJSON) {
            nolonObject["usage_query"] = usageQuery
        }
        root["nolon"] = nolonObject

        return try Self.encodeJSONObject(root)
    }

    func cleanupManagedSnapshotFilesIfNeeded() throws {
        let folder = nolonCodexAuthFolder()
        let fileNames = stableAuthSnapshotFileNames(in: folder)
        guard !fileNames.isEmpty else { return }
        for fileName in fileNames {
            let file = folder.file(fileName)
            try? file.delete()
        }
    }

    func removeCodexAccountFromSQLite(id: UUID) throws {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        try executeSQLite(
            db,
            sql: "DELETE FROM codex_accounts WHERE id = ?;",
            bindings: [.text(id.uuidString)]
        )
        try executeSQLite(
            db,
            sql: "DELETE FROM codex_account_credentials WHERE account_id = ?;",
            bindings: [.text(id.uuidString)]
        )
        try executeSQLite(
            db,
            sql: "DELETE FROM codex_account_metadata WHERE account_id = ?;",
            bindings: [.text(id.uuidString)]
        )
        try executeSQLite(
            db,
            sql: "DELETE FROM codex_active_accounts WHERE account_id = ?;",
            bindings: [.text(id.uuidString)]
        )
    }

    nonisolated func loadActiveAccountMapFromSQLite() throws -> [String: String] {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return [:] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5_000)

        let sql = "SELECT provider_id, account_id FROM codex_active_accounts;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare active-account query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        var map: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let providerCString = sqlite3_column_text(statement, 0),
                let accountCString = sqlite3_column_text(statement, 1)
            else { continue }
            let providerID = String(cString: providerCString)
            let accountID = String(cString: accountCString)
            guard UUID(uuidString: accountID) != nil else { continue }
            map[providerID] = accountID
        }
        return map
    }

    func saveActiveAccountMapToSQLite(_ map: [String: String]) throws {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        try ensureCodexAccountsSQLiteSchema(databaseURL: dbURL)
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5_000)

        try executeSQLite(db, sql: "BEGIN IMMEDIATE TRANSACTION;")
        var didCommit = false
        defer {
            if !didCommit {
                try? executeSQLite(db, sql: "ROLLBACK TRANSACTION;")
            }
        }

        let nowISO = Self.makeISOFormatter().string(from: Date())
        for (providerID, accountID) in map {
            try executeSQLite(
                db,
                sql: """
                INSERT INTO codex_active_accounts (provider_id, account_id, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(provider_id) DO UPDATE SET
                    account_id=excluded.account_id,
                    updated_at=excluded.updated_at;
                """,
                bindings: [.text(providerID), .text(accountID), .text(nowISO)]
            )
        }

        let incomingProviderIDs = Set(map.keys)
        for providerID in try loadActiveProviderIDsFromSQLite(db: db) where !incomingProviderIDs.contains(providerID) {
            try executeSQLite(
                db,
                sql: "DELETE FROM codex_active_accounts WHERE provider_id = ?;",
                bindings: [.text(providerID)]
            )
        }

        try executeSQLite(db, sql: "COMMIT TRANSACTION;")
        didCommit = true
    }

    nonisolated func loadActiveProviderIDsFromSQLite(db: OpaquePointer?) throws -> [String] {
        let sql = "SELECT provider_id FROM codex_active_accounts;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare active-provider query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        var providerIDs: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let providerCString = sqlite3_column_text(statement, 0) else { continue }
            providerIDs.append(String(cString: providerCString))
        }
        return providerIDs
    }

    nonisolated func codexImportSQLiteDatabaseURL() -> URL {
        codexAccountsSQLiteDatabaseURL()
    }

    func persistValidatedImportsToSQLiteGroup(
        results: [CodexImportValidationResult],
        groupName: String
    ) async throws {
        let validRows = results.compactMap { result -> (CodexImportValidationResult, String)? in
            guard result.isValid, let raw = result.authJSONString else { return nil }
            return (result, raw)
        }
        guard !validRows.isEmpty else { return }

        let dbURL = codexImportSQLiteDatabaseURL()
        let folderURL = dbURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        try upsertSQLiteImportRows(validRows, groupName: groupName, databaseURL: dbURL)
    }

    func setCustomSQLiteGroup(_ groupName: String, for accountID: UUID) throws {
        let dbURL = codexAccountsSQLiteDatabaseURL()
        try ensureCodexAccountsSQLiteSchema(databaseURL: dbURL)
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nowISO = Self.makeISOFormatter().string(from: Date())
        try executeSQLite(
            db,
            sql: """
            INSERT INTO codex_account_metadata (account_id, custom_group_name, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(account_id) DO UPDATE SET
                custom_group_name=excluded.custom_group_name,
                updated_at=excluded.updated_at;
            """,
            bindings: [
                .text(accountID.uuidString),
                .nullableText(trimmedGroupName.isEmpty ? nil : trimmedGroupName),
                .text(nowISO),
            ]
        )
    }

    nonisolated func upsertSQLiteImportRows(
        _ rows: [(CodexImportValidationResult, String)],
        groupName: String,
        databaseURL: URL
    ) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS custom_import_groups (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL
            );
            """
        )
        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS imported_codex_accounts (
                id TEXT PRIMARY KEY,
                group_id TEXT NOT NULL,
                suggested_name TEXT,
                email TEXT,
                source_file_url TEXT NOT NULL,
                auth_json TEXT NOT NULL,
                auth_hash TEXT NOT NULL,
                imported_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(group_id, auth_hash)
            );
            """
        )
        try executeSQLite(
            db,
            sql: """
            CREATE INDEX IF NOT EXISTS idx_imported_codex_accounts_group
            ON imported_codex_accounts(group_id);
            """
        )

        let nowISO = Self.makeISOFormatter().string(from: Date())
        let groupID = stableImportGroupID(for: groupName)
        try executeSQLite(
            db,
            sql: """
            INSERT INTO custom_import_groups (id, name, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET name=excluded.name;
            """,
            bindings: [.text(groupID), .text(groupName), .text(nowISO)]
        )

        for (validation, raw) in rows {
            let authHash = CodexAuthAccount.hashHex(for: raw)
            let displayName = (validation.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? deriveAccountName(fromAuthJSONString: raw)
            let email = (validation.email?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? deriveEmail(fromAuthJSONString: raw)

            try executeSQLite(
                db,
                sql: """
                INSERT INTO imported_codex_accounts (
                    id, group_id, suggested_name, email, source_file_url, auth_json, auth_hash, imported_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(group_id, auth_hash) DO UPDATE SET
                    suggested_name=excluded.suggested_name,
                    email=excluded.email,
                    source_file_url=excluded.source_file_url,
                    auth_json=excluded.auth_json,
                    updated_at=excluded.updated_at;
                """,
                bindings: [
                    .text(UUID().uuidString),
                    .text(groupID),
                    .nullableText(displayName),
                    .nullableText(email),
                    .text(validation.fileURL.path),
                    .text(raw),
                    .text(authHash),
                    .text(nowISO),
                    .text(nowISO),
                ]
            )
        }
    }

    enum SQLiteBindingValue {
        case text(String)
        case nullableText(String?)
    }

    nonisolated var sqliteTransientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    nonisolated func executeSQLite(
        _ db: OpaquePointer?,
        sql: String,
        bindings: [SQLiteBindingValue] = []
    ) throws {
        sqlite3_busy_timeout(db, 5_000)
        var statement: OpaquePointer?
        let prepareCode: Int32 = {
            var lastCode: Int32 = SQLITE_OK
            for attempt in 0..<8 {
                lastCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
                if lastCode == SQLITE_OK {
                    return lastCode
                }
                if lastCode == SQLITE_BUSY || lastCode == SQLITE_LOCKED {
                    if attempt < 7 {
                        usleep(40_000)
                        continue
                    }
                }
                return lastCode
            }
            return lastCode
        }()
        guard prepareCode == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(prepareCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare SQLite statement." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case let .text(raw):
                guard sqlite3_bind_text(statement, position, raw, -1, sqliteTransientDestructor) == SQLITE_OK else {
                    let message = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(sqlite3_errcode(db)), userInfo: [
                        NSLocalizedDescriptionKey: message.isEmpty ? "Failed to bind SQLite text value." : message,
                    ])
                }
            case let .nullableText(raw):
                if let raw {
                    guard sqlite3_bind_text(statement, position, raw, -1, sqliteTransientDestructor) == SQLITE_OK else {
                        let message = String(cString: sqlite3_errmsg(db))
                        throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(sqlite3_errcode(db)), userInfo: [
                            NSLocalizedDescriptionKey: message.isEmpty ? "Failed to bind SQLite optional text value." : message,
                        ])
                    }
                } else {
                    guard sqlite3_bind_null(statement, position) == SQLITE_OK else {
                        let message = String(cString: sqlite3_errmsg(db))
                        throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(sqlite3_errcode(db)), userInfo: [
                            NSLocalizedDescriptionKey: message.isEmpty ? "Failed to bind SQLite null value." : message,
                        ])
                    }
                }
            }
        }

        let stepCode: Int32 = {
            var lastCode: Int32 = SQLITE_DONE
            for attempt in 0..<8 {
                lastCode = sqlite3_step(statement)
                if lastCode == SQLITE_DONE {
                    return lastCode
                }
                if lastCode == SQLITE_BUSY || lastCode == SQLITE_LOCKED {
                    if attempt < 7 {
                        sqlite3_reset(statement)
                        sqlite3_clear_bindings(statement)
                        for (index, value) in bindings.enumerated() {
                            let position = Int32(index + 1)
                            switch value {
                            case let .text(raw):
                                _ = sqlite3_bind_text(statement, position, raw, -1, sqliteTransientDestructor)
                            case let .nullableText(raw):
                                if let raw {
                                    _ = sqlite3_bind_text(statement, position, raw, -1, sqliteTransientDestructor)
                                } else {
                                    _ = sqlite3_bind_null(statement, position)
                                }
                            }
                        }
                        usleep(40_000)
                        continue
                    }
                }
                return lastCode
            }
            return lastCode
        }()
        guard stepCode == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(stepCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to execute SQLite statement." : message,
            ])
        }
    }

    nonisolated func sqliteColumnExists(db: OpaquePointer?, table: String, column: String) throws -> Bool {
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        let prepareCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareCode == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteImport", code: Int(prepareCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to inspect SQLite schema." : message,
            ])
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

}
