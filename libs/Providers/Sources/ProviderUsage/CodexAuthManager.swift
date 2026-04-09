import Foundation
import OSLog
import CryptoKit
import Darwin
import STFilePath
import ProviderCatalog
import STJSON
import ProvidersShared
import SQLite3

public actor CodexAuthManager {
    public static let shared = CodexAuthManager()
    nonisolated static let canonicalChatGPTAuthMode = "chatgpt"
    nonisolated static let legacyChatGPTAuthMode = "chatgptAuthTokens"

    public struct RuntimeHomeCleanupReport: Sendable, Equatable {
        public let scannedCount: Int
        public let removedCount: Int
        public let preservedActiveCount: Int
        public let skippedRecentCount: Int
        public let failureCount: Int

        public init(
            scannedCount: Int,
            removedCount: Int,
            preservedActiveCount: Int,
            skippedRecentCount: Int,
            failureCount: Int
        ) {
            self.scannedCount = scannedCount
            self.removedCount = removedCount
            self.preservedActiveCount = preservedActiveCount
            self.skippedRecentCount = skippedRecentCount
            self.failureCount = failureCount
        }
    }

    public enum ImportDestination: Sendable, Equatable {
        case managedSnapshots
        case customSQLiteGroup(name: String)
    }

    public struct RefreshedOAuthTokens: Sendable, Equatable {
        public let accessToken: String
        public let idToken: String
        public let refreshToken: String?
        public let expiresIn: Int?

        public init(
            accessToken: String,
            idToken: String,
            refreshToken: String? = nil,
            expiresIn: Int? = nil
        ) {
            self.accessToken = accessToken
            self.idToken = idToken
            self.refreshToken = refreshToken
            self.expiresIn = expiresIn
        }
    }

    public struct FetchedOAuthAccountInfo: Sendable, Equatable {
        public let email: String?
        public let accountID: String?
        public let planType: String?

        public init(email: String? = nil, accountID: String? = nil, planType: String? = nil) {
            self.email = email
            self.accountID = accountID
            self.planType = planType
        }
    }

    public struct ConfiguredRelay: Sendable, Equatable, Codable {
        public let baseURL: String
        public let modelProvider: String
        public let queryParams: [String: String]
        public let headers: [String: String]

        public init(
            baseURL: String,
            modelProvider: String,
            queryParams: [String: String] = [:],
            headers: [String: String] = [:]
        ) {
            self.baseURL = baseURL
            self.modelProvider = modelProvider
            self.queryParams = queryParams
            self.headers = headers
        }
    }

    public struct CodexManagementStatus: Sendable, Equatable {
        public let hasProviderAuthFile: Bool
        public let providerAuthIsSymlink: Bool
        public let snapshotCount: Int
        public let needsEnable: Bool
        public let needsMigration: Bool

        public init(
            hasProviderAuthFile: Bool,
            providerAuthIsSymlink: Bool,
            snapshotCount: Int,
            needsEnable: Bool,
            needsMigration: Bool
        ) {
            self.hasProviderAuthFile = hasProviderAuthFile
            self.providerAuthIsSymlink = providerAuthIsSymlink
            self.snapshotCount = snapshotCount
            self.needsEnable = needsEnable
            self.needsMigration = needsMigration
        }
    }

    public struct CodexManagementReport: Sendable, Equatable {
        public let enabled: Bool
        public let migrated: Bool
        public let affectedAccountID: UUID?
        public let snapshotCount: Int

        public init(enabled: Bool, migrated: Bool, affectedAccountID: UUID?, snapshotCount: Int) {
            self.enabled = enabled
            self.migrated = migrated
            self.affectedAccountID = affectedAccountID
            self.snapshotCount = snapshotCount
        }
    }

    public struct CodexImportValidationResult: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let fileURL: URL
        public let sourceGroupID: String
        public let sourceGroupLabel: String
        public let isValid: Bool
        public let reason: String?
        public let suggestedName: String?
        public let email: String?
        public let authJSONString: String?

        public init(
            id: UUID = UUID(),
            fileURL: URL,
            sourceGroupID: String? = nil,
            sourceGroupLabel: String? = nil,
            isValid: Bool,
            reason: String?,
            suggestedName: String?,
            email: String?,
            authJSONString: String?
        ) {
            self.id = id
            self.fileURL = fileURL
            self.sourceGroupID = sourceGroupID ?? fileURL.standardizedFileURL.deletingLastPathComponent().path
            self.sourceGroupLabel = sourceGroupLabel ?? fileURL.lastPathComponent
            self.isValid = isValid
            self.reason = reason
            self.suggestedName = suggestedName
            self.email = email
            self.authJSONString = authJSONString
        }
    }
    struct PathName: RawRepresentable, ExpressibleByStringLiteral {
        static let codexRoot: PathName = "codex"
        static let authFolder: PathName = "auth"
        static let cliLoginHomeFolder: PathName = "cli-login-home"
        static let runtimeHomeFolder: PathName = "runtime-home"
        static let runtimeSkillsTemplateFolder: PathName = "runtime-skills-template"
        static let activeAccountsFile: PathName = "active-accounts.json"
        static let activeFingerprintsFile: PathName = "active-fingerprints.json"
        static let backupsFolder: PathName = "backups"
        static let activeBackupsFolder: PathName = "active"
        static let authLockFile: PathName = ".auth.lock"
        static let authFile: PathName = "auth.json"

        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ value: String) {
            self.rawValue = value
        }

        init(stringLiteral value: String) {
            self.rawValue = value
        }
    }

    static let logger = Logger(subsystem: "com.nolon", category: "CodexAuthManager")
    static let gatewayVirtualAPIKey = "nolon-gateway-virtual-api-key"
    nonisolated static let canonicalCodexActiveProviderKeys: Set<String> = ["codex", "codex-xcode"]
    nonisolated static func isCodexTemplate(_ templateID: String?) -> Bool {
        templateID == ProviderTemplate.codex.rawValue || templateID == ProviderTemplate.codexXcode.rawValue
    }
    nonisolated static func canonicalCodexActiveProviderKey(for templateID: String?) -> String? {
        let normalized = templateID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "codex":
            return "codex"
        case "codexxcode", "codex-xcode":
            return "codex-xcode"
        default:
            return nil
        }
    }
    static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return encoder
    }()
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return decoder
    }()

    typealias JSONObject = [String: Any]

    nonisolated let rootFolder: STFolder
    nonisolated let refreshCodexTokenAction: @Sendable (_ refreshToken: String) async throws -> RefreshedOAuthTokens
    nonisolated let fetchCodexAccountInfoAction: @Sendable (_ accessToken: String) async throws -> FetchedOAuthAccountInfo?
    var providerAuthPollingTasks: [String: Task<Void, Never>] = [:]
    var providerAuthLastHashes: [String: String] = [:]
    let providerAuthPollIntervalNanoseconds: UInt64 = 2_000_000_000

    public init(
        rootURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        refreshCodexTokenAction: (@Sendable (_ refreshToken: String) async throws -> RefreshedOAuthTokens)? = nil,
        fetchCodexAccountInfoAction: (@Sendable (_ accessToken: String) async throws -> FetchedOAuthAccountInfo?)? = nil
    ) {
        if let rootURL {
            self.rootFolder = STFolder(rootURL)
        } else {
            self.rootFolder = NolonHomeEnvironment.resolveNolonHomeFolder(environment: environment)
        }
        self.refreshCodexTokenAction = refreshCodexTokenAction ?? Self.defaultRefreshCodexOAuthTokens
        self.fetchCodexAccountInfoAction = fetchCodexAccountInfoAction ?? Self.defaultFetchCodexOAuthAccountInfo
    }

    public nonisolated func nolonCodexRootFolder() -> STFolder {
        rootFolder.folder(PathName.codexRoot.rawValue)
    }

    public nonisolated func nolonCodexAuthFolder() -> STFolder {
        nolonCodexRootFolder().folder(PathName.authFolder.rawValue)
    }

    public nonisolated func nolonCodexGatewayVirtualAuthFolder() -> STFolder {
        nolonCodexRootFolder().folder("gateway").folder("virtual-auth")
    }

    public nonisolated func cliLoginCodexHomeFolder(providerID: String) -> STFolder {
        let sanitized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let fallback = "codex"
        let normalized = sanitized.isEmpty ? fallback : sanitized
        return nolonCodexRootFolder()
            .folder(PathName.cliLoginHomeFolder.rawValue)
            .folder(normalized)
    }

    public nonisolated func activeAccountsFile() -> STFile {
        nolonCodexRootFolder().file(PathName.activeAccountsFile.rawValue)
    }

    public nonisolated func accountsSQLiteFile() -> STFile {
        rootFolder.file("nolon.sqlite3")
    }

    nonisolated func activeAccountProviderKey(for provider: Provider) -> String {
        if let canonical = Self.canonicalCodexActiveProviderKey(for: provider.templateId) {
            return canonical
        }
        return provider.id
    }

    nonisolated func resolveActiveAccountID(from map: [String: String], for provider: Provider) -> String? {
        let canonicalKey = activeAccountProviderKey(for: provider)
        if let value = map[canonicalKey] {
            return value
        }
        guard canonicalKey != provider.id else { return nil }
        return map[provider.id]
    }

    nonisolated func configuredActiveAccountProviderKeys() -> Set<String> {
        let providers = configuredProviders()
        guard !providers.isEmpty else { return Self.canonicalCodexActiveProviderKeys }

        var keys = Set<String>()
        for provider in providers {
            keys.insert(activeAccountProviderKey(for: provider))
        }
        keys.formUnion(Self.canonicalCodexActiveProviderKeys)
        return keys
    }

    nonisolated func configuredProviders() -> [Provider] {
        let file = rootFolder.file("providers.json")
        guard file.isExists,
              let data = try? file.data(),
              !data.isEmpty,
              let providers = try? JSONDecoder().decode([Provider].self, from: data)
        else {
            return []
        }
        return providers
    }

    nonisolated func sanitizeActiveAccountMap(_ map: [String: String]) -> [String: String] {
        let allowedKeys = configuredActiveAccountProviderKeys()
        guard !allowedKeys.isEmpty else { return map }
        return map.reduce(into: [String: String]()) { result, item in
            guard allowedKeys.contains(item.key), UUID(uuidString: item.value) != nil else { return }
            result[item.key] = item.value
        }
    }

    public nonisolated func activeFingerprintsFile() -> STFile {
        nolonCodexRootFolder().file(PathName.activeFingerprintsFile.rawValue)
    }

    public nonisolated func runtimeHomeFolder(accountID: UUID) -> STFolder {
        nolonCodexRootFolder()
            .folder(PathName.runtimeHomeFolder.rawValue)
            .folder(accountID.uuidString.lowercased())
    }

    public nonisolated func runtimeSkillsTemplateFolder() -> STFolder {
        nolonCodexRootFolder().folder(PathName.runtimeSkillsTemplateFolder.rawValue)
    }

    /// Cleanup runtime homes created for account-isolated Codex runs.
    /// Called after app startup in a background task.
    /// Keeps active-account runtime homes and recent inactive homes.
    public func cleanupRuntimeHomesOnAppLaunch(
        maxAge: TimeInterval = 24 * 60 * 60,
        now: Date = Date()
    ) throws -> RuntimeHomeCleanupReport {
        let runtimeRoot = nolonCodexRootFolder().folder(PathName.runtimeHomeFolder.rawValue)
        guard runtimeRoot.isExists else {
            return RuntimeHomeCleanupReport(
                scannedCount: 0,
                removedCount: 0,
                preservedActiveCount: 0,
                skippedRecentCount: 0,
                failureCount: 0
            )
        }

        let activeIDs = Set(
            loadActiveAccountMap().values.compactMap { UUID(uuidString: $0) }
        )
        let fileManager = FileManager.default
        let entries = (try? fileManager.contentsOfDirectory(
            at: runtimeRoot.url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var scanned = 0
        var removed = 0
        var preservedActive = 0
        var skippedRecent = 0
        var failed = 0

        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard values?.isDirectory == true else { continue }
            let folderName = entry.lastPathComponent.lowercased()
            guard let folderAccountID = UUID(uuidString: folderName) else { continue }
            scanned += 1

            if activeIDs.contains(folderAccountID) {
                preservedActive += 1
                continue
            }

            let modifiedAt = values?.contentModificationDate
                ?? ((try? fileManager.attributesOfItem(atPath: entry.path)[.modificationDate]) as? Date)
                ?? .distantPast
            let age = now.timeIntervalSince(modifiedAt)
            if age < maxAge {
                skippedRecent += 1
                continue
            }

            do {
                try fileManager.removeItem(at: entry)
                removed += 1
            } catch {
                failed += 1
            }
        }

        return RuntimeHomeCleanupReport(
            scannedCount: scanned,
            removedCount: removed,
            preservedActiveCount: preservedActive,
            skippedRecentCount: skippedRecent,
            failureCount: failed
        )
    }

    public nonisolated func ensureRuntimeSkillsSymlink(accountID: UUID) throws {
        let runtimeHome = runtimeHomeFolder(accountID: accountID)
        _ = runtimeHome.createIfNotExists()

        let templateFolder = runtimeSkillsTemplateFolder()
        _ = templateFolder.createIfNotExists()

        let runtimeSkills = STPath(runtimeHome.folder("skills").url)
        let templatePath = STPath(templateFolder.url)
        let expectedDestination = standardizedPathString(templatePath)

        if runtimeSkills.isSymbolicLink,
           let linked = resolveSymlinkTarget(for: runtimeSkills),
           standardizedPathString(linked) == expectedDestination
        {
            return
        }

        if runtimeSkills.isExists || runtimeSkills.isSymbolicLink {
            try FileManager.default.removeItem(at: runtimeSkills.url)
        }

        try runtimeSkills.createSymbolicLink(to: templatePath)
    }

    public nonisolated func accountAuthFile(relativeAuthPath: String) -> STFile {
        nolonCodexRootFolder().file(relativeAuthPath)
    }

    public nonisolated func accountAuthData(relativeAuthPath: String) -> Data? {
        guard let accountID = sqliteAccountID(fromRelativeAuthPath: relativeAuthPath),
              let data = try? loadCodexAccountAuthDataFromSQLite(accountID: accountID),
              !data.isEmpty
        else {
            return nil
        }
        return data
    }

    public nonisolated func accountAuthData(for account: CodexAuthAccount) -> Data? {
        guard let data = try? loadCodexAccountAuthDataFromSQLite(accountID: account.id),
              !data.isEmpty
        else { return nil }
        return data
    }

    /// Reads account auth payload directly from SQLite-backed storage.
    public nonisolated func accountAuthDataWithoutMaterialization(for account: CodexAuthAccount) -> Data? {
        accountAuthData(for: account)
    }

    nonisolated func sqliteAccountID(fromRelativeAuthPath relativeAuthPath: String) -> UUID? {
        let normalized = relativeAuthPath.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("auth/") else { return nil }
        let fileName = URL(fileURLWithPath: normalized).lastPathComponent
        guard fileName.hasSuffix(".json") else { return nil }
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        return UUID(uuidString: stem)
    }

    nonisolated func sqliteRelativeAuthPath(for accountID: UUID) -> String {
        "auth/\(accountID.uuidString.lowercased()).json"
    }

    nonisolated func managedActiveAuthFolder(for providerID: String) -> STFolder {
        let normalizedProviderID = providerID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let folderName = normalizedProviderID.isEmpty ? "codex" : normalizedProviderID
        return nolonCodexRootFolder()
            .folder("active-auth")
            .folder(folderName)
    }

    func materializeManagedActiveAuthFile(for account: CodexAuthAccount, provider: Provider) throws -> STFile {
        let folder = managedActiveAuthFolder(for: provider.id)
        _ = folder.createIfNotExists()
        let file = folder.file("auth.json")
        let data = try readAccountAuthData(account)
        try file.overlay(with: data)
        try cleanupLegacyManagedActiveAuthFiles(in: folder, keeping: file.attributes.name)
        return file
    }

    func cleanupLegacyManagedActiveAuthFiles(in folder: STFolder, keeping fileName: String) throws {
        let files = (try? folder.files()) ?? []
        for entry in files where entry.attributes.name != fileName {
            guard entry.attributes.nameComponents.extension?.lowercased() == "json" else { continue }
            try? entry.delete()
        }
    }

    public nonisolated static func cleanedAuthJSONData(from data: Data) -> Data? {
        guard var dict = decodeJSONObject(from: data) else { return nil }
        dict.removeValue(forKey: "nolon")
        return try? encodeJSONObject(dict)
    }

    nonisolated static func canonicalAuthMode(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw == legacyChatGPTAuthMode {
            return canonicalChatGPTAuthMode
        }
        return raw
    }

    /// Normalizes imported auth JSON payloads into the canonical Codex `auth.json` structure:
    /// - Move top-level token fields into `tokens.*` (without overwriting existing `tokens.*` values).
    /// - Map `expired` -> `expires_at` when missing.
    /// - Backfill `auth_mode` when missing.
    ///
    /// The returned data is a stable JSON object encoding (sorted keys).
    public nonisolated static func normalizeImportedAuthJSONDataIfNeeded(_ data: Data) -> Data? {
        guard let rootJSON = try? JSON(data: data) else { return nil }
        var rootObject = rootJSON.dictionaryObject ?? [:]

        func trimmedNonEmpty(_ value: Any?) -> String? {
            guard let raw = value as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        func get(_ key: String) -> String? {
            trimmedNonEmpty(rootObject[key])
        }

        var tokens = rootObject["tokens"] as? JSONObject ?? [:]

        // Backfill tokens.* from top-level values without overwriting existing canonical fields.
        let tokenMappings: [(top: String, canonical: String)] = [
            ("id_token", "id_token"),
            ("idToken", "id_token"),
            ("access_token", "access_token"),
            ("accessToken", "access_token"),
            ("refresh_token", "refresh_token"),
            ("refreshToken", "refresh_token"),
            ("account_id", "account_id"),
            ("accountId", "account_id"),
        ]

        for (top, canonical) in tokenMappings {
            if tokens[canonical] == nil, let value = get(top) {
                tokens[canonical] = value
            }
            if rootObject[top] != nil {
                rootObject.removeValue(forKey: top)
            }
        }

        if !tokens.isEmpty || rootObject["tokens"] != nil {
            rootObject["tokens"] = tokens
        }

        // Map `expired` into `expires_at` (only when expires_at is not already present).
        if rootObject["expires_at"] == nil, rootObject["expiresAt"] == nil,
           let expired = get("expired")
        {
            rootObject["expires_at"] = expired
        }
        if rootObject["expired"] != nil {
            rootObject.removeValue(forKey: "expired")
        }

        // Backfill auth_mode if missing.
        let existingMode = Self.canonicalAuthMode(get("auth_mode"))
        if let existingMode {
            rootObject["auth_mode"] = existingMode
        } else {
            if trimmedNonEmpty(rootObject["OPENAI_API_KEY"]) != nil {
                rootObject["auth_mode"] = "apikey"
            } else if trimmedNonEmpty(tokens["id_token"]) != nil {
                rootObject["auth_mode"] = Self.canonicalChatGPTAuthMode
            }
        }

        return try? encodeJSONObject(rootObject)
    }

    // Usage cache encoding helpers are defined on CodexAuthUsageCache in ProviderUsage.

    public func codexHomeFolder(for provider: Provider) -> STFolder? {
        guard Self.isCodexTemplate(provider.templateId) else { return nil }
        let skillsPath = STPath(provider.defaultSkillsPath)
        return skillsPath.parentFolder()
    }

    public func authFile(for provider: Provider) -> STFile? {
        codexHomeFolder(for: provider)?.file(PathName.authFile.rawValue)
    }

    public func accountAuthFile(_ account: CodexAuthAccount) -> STFile {
        accountAuthFile(relativeAuthPath: account.relativeAuthPath)
    }

    public func loadCustomGroupNamesByAccountID() throws -> [UUID: String] {
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

        let hasCustomGroupColumn = (try? sqliteColumnExists(db: db, table: "codex_account_metadata", column: "custom_group_name")) ?? false
        guard hasCustomGroupColumn else { return [:] }

        let sql = """
        SELECT account_id, custom_group_name
        FROM codex_account_metadata
        WHERE custom_group_name IS NOT NULL AND TRIM(custom_group_name) <> '';
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexAuthManager.SQLiteAccounts", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare custom group query." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        var result: [UUID: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let accountIDRaw = sqlite3_column_text(statement, 0),
                  let groupRaw = sqlite3_column_text(statement, 1)
            else { continue }
            let accountIDString = String(cString: accountIDRaw)
            let group = String(cString: groupRaw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !group.isEmpty, let accountID = UUID(uuidString: accountIDString) else { continue }
            result[accountID] = group
        }
        return result
    }

    public func loadAccounts() async throws -> [CodexAuthAccount] {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
        return try loadAccountsFromAuthFolder()
    }

    /// Explicit migration entrypoint: move current Codex account system metadata into SQLite.
    public func migrateAccountSystemToSQLite() async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
    }

    public func addAccount(name: String, authJSONString: String) async throws -> CodexAuthAccount {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
        let preferredID = UUID()
        let relativePath = sqliteRelativeAuthPath(for: preferredID)
        let data = try normalizeAccountPayloadData(
            authJSONString: authJSONString,
            preferredId: preferredID,
            preferredCreatedAt: Date(),
            relativeAuthPath: relativePath
        )
        let account = accountFromNormalizedPayloadData(data, fallbackRelativeAuthPath: relativePath)
        try upsertCodexAccountInSQLite(account, authData: data)
        return account
    }

    public func updateAccount(_ account: CodexAuthAccount, authJSONString: String) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
        let data = try normalizeAccountPayloadData(
            authJSONString: authJSONString,
            preferredId: account.id,
            preferredCreatedAt: account.createdAt,
            relativeAuthPath: account.relativeAuthPath
        )
        let reloaded = accountFromNormalizedPayloadData(data, fallbackRelativeAuthPath: account.relativeAuthPath)
        try upsertCodexAccountInSQLite(reloaded, authData: data)
    }

    public func addConfiguredAccount(
        name: String,
        apiKey: String,
        relay: ConfiguredRelay?,
        usageQuery: CodexHTTPUsageQuery? = nil
    ) async throws -> CodexAuthAccount {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        let preferredName = sanitizedConfiguredAccountName(name: name, relay: relay)
        let preferredID = UUID()
        let relativePath = sqliteRelativeAuthPath(for: preferredID)
        let payload = try makeConfiguredAccountPayload(
            name: preferredName,
            apiKey: apiKey,
            relay: relay,
            usageQuery: usageQuery,
            preferredId: preferredID,
            relativeAuthPath: relativePath,
            createdAt: Date(),
            updatedAt: Date()
        )
        let account = accountFromNormalizedPayloadData(payload, fallbackRelativeAuthPath: relativePath)
        try upsertCodexAccountInSQLite(account, authData: payload)
        return account
    }

    public func updateConfiguredAccount(
        _ account: CodexAuthAccount,
        name: String,
        apiKey: String,
        relay: ConfiguredRelay?,
        usageQuery: CodexHTTPUsageQuery? = nil
    ) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
        let existingData = try readAccountAuthData(account)
        let payload = try makeConfiguredAccountPayload(
            name: sanitizedConfiguredAccountName(name: name, relay: relay),
            apiKey: apiKey,
            relay: relay,
            usageQuery: usageQuery,
            preferredId: account.id,
            relativeAuthPath: account.relativeAuthPath,
            createdAt: account.createdAt,
            updatedAt: Date(),
            existingRootObject: Self.decodeJSONObject(from: existingData)
        )
        let reloaded = accountFromNormalizedPayloadData(payload, fallbackRelativeAuthPath: account.relativeAuthPath)
        try upsertCodexAccountInSQLite(reloaded, authData: payload)
    }

    public func upsertGatewayVirtualAccount(
        providerID: String,
        name: String,
        apiKey: String,
        relay: ConfiguredRelay
    ) async throws -> CodexAuthAccount {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
        let trimmedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedProviderID.isEmpty else {
            throw CocoaError(.fileNoSuchFile)
        }

        let fileName = "__gateway_reply__-\(sanitizeFileStem(trimmedProviderID)).json"
        let virtualFolder = nolonCodexGatewayVirtualAuthFolder()
        _ = virtualFolder.createIfNotExists()
        let relativePath = "gateway/virtual-auth/\(fileName)"
        let file = accountAuthFile(relativeAuthPath: relativePath)

        let legacyRelativePath = "auth/\(fileName)"
        let legacyFile = accountAuthFile(relativeAuthPath: legacyRelativePath)
        if !file.isExists, legacyFile.isExists {
            _ = file.parentFolder()?.createIfNotExists()
            do {
                try FileManager.default.moveItem(at: legacyFile.url, to: file.url)
            } catch {
                _ = try? legacyFile.copy(to: file)
                _ = try? legacyFile.delete()
            }
        }

        let existing = try? loadAccount(file: file, relativeAuthPath: relativePath)
        let now = Date()
        let payload = try makeConfiguredAccountPayload(
            name: sanitizedConfiguredAccountName(name: name, relay: relay),
            apiKey: apiKey,
            relay: relay,
            usageQuery: nil,
            preferredId: existing?.id ?? UUID(),
            relativeAuthPath: relativePath,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            existingRootObject: (try? file.data()).flatMap { Self.decodeJSONObject(from: $0) }
        )
        try file.overlay(with: payload)
        let account = try loadAccount(file: file, relativeAuthPath: relativePath)
        try upsertCodexAccountInSQLite(account)
        return account
    }

    public func gatewayVirtualAccount(providerID: String) async -> CodexAuthAccount? {
        let trimmedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedProviderID.isEmpty else { return nil }

        let fileName = "__gateway_reply__-\(sanitizeFileStem(trimmedProviderID)).json"
        let relativePath = "gateway/virtual-auth/\(fileName)"
        let file = accountAuthFile(relativeAuthPath: relativePath)
        if file.isExists {
            return try? loadAccount(file: file, relativeAuthPath: relativePath)
        }

        let legacyRelativePath = "auth/\(fileName)"
        let legacyFile = accountAuthFile(relativeAuthPath: legacyRelativePath)
        if !legacyFile.isExists {
            return nil
        }

        _ = nolonCodexGatewayVirtualAuthFolder().createIfNotExists()
        do {
            _ = file.parentFolder()?.createIfNotExists()
            try FileManager.default.moveItem(at: legacyFile.url, to: file.url)
        } catch {
            _ = try? legacyFile.copy(to: file)
            _ = try? legacyFile.delete()
        }
        return try? loadAccount(file: file, relativeAuthPath: relativePath)
    }

    @discardableResult
    public func exportAccountsArchive(accountIDs: [UUID], destinationURL: URL) async throws -> Int {
        try await migrateLegacyIfNeeded()

        let selectedIDs = Set(accountIDs)
        guard !selectedIDs.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.Export",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No accounts selected for export."]
            )
        }

        let accounts = try loadAccountsFromAuthFolder()
        let selectedAccounts = accounts.filter { selectedIDs.contains($0.id) }
        guard !selectedAccounts.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.Export",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Selected accounts could not be found."]
            )
        }

        let fileManager = FileManager.default
        let stagingRoot = fileManager.temporaryDirectory.appendingPathComponent("codex-export-\(UUID().uuidString)", isDirectory: true)
        let stagingFolder = stagingRoot.appendingPathComponent("auth", isDirectory: true)
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        var usedNames: Set<String> = []
        for account in selectedAccounts {
            let sourceData = try readAccountAuthData(account)
            let preferredName = URL(fileURLWithPath: account.relativeAuthPath).deletingPathExtension().lastPathComponent
            let fileName = uniqueExportFileName(preferred: preferredName, usedNames: &usedNames)
            let destination = stagingFolder.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try sourceData.write(to: destination, options: .atomic)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try runDitto(arguments: ["-c", "-k", "--keepParent", stagingRoot.path, destinationURL.path])
        return selectedAccounts.count
    }


    @discardableResult
    public func exportValidatedAuthFilesArchive(
        results: [CodexImportValidationResult],
        destinationURL: URL
    ) async throws -> Int {
        try await migrateLegacyIfNeeded()
        let selectedEntries = makeValidatedExportEntries(from: results)
        guard !selectedEntries.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.Export",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No valid import candidates selected for export."]
            )
        }

        let fileManager = FileManager.default
        let stagingRoot = fileManager.temporaryDirectory.appendingPathComponent("codex-import-export-\(UUID().uuidString)", isDirectory: true)
        let stagingFolder = stagingRoot.appendingPathComponent("auth", isDirectory: true)
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        var usedNames: Set<String> = []
        for entry in selectedEntries {
            let fileName = uniqueExportFileName(preferred: entry.preferredFileStem, usedNames: &usedNames)
            let destination = stagingFolder.appendingPathComponent(fileName)
            try Data(entry.rawJSONString.utf8).write(to: destination, options: .atomic)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try runDitto(arguments: ["-c", "-k", "--keepParent", stagingRoot.path, destinationURL.path])
        return selectedEntries.count
    }


    public func findAccountByEmail(_ email: String) async throws -> CodexAuthAccount? {
        let normalized = normalizedEmail(email)
        guard let normalized else { return nil }
        let accounts = try await loadAccounts()
        for account in accounts {
            guard let data = try? readAccountAuthData(account), !data.isEmpty else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if let candidate = normalizedEmail(summary.email), candidate == normalized {
                return account
            }
        }
        return nil
    }

    public func matchAccountByAuthData(_ data: Data) async throws -> CodexAuthAccount? {
        let accounts = try await loadAccounts()
        return matchAccount(authData: data, accounts: accounts)
    }

    /// Upsert account snapshot from a successful `codex login` output.
    /// - If `preferredAccountID` is provided and exists, update that account first.
    /// - Else, use `matchAccount` strict identity rules to decide update vs create.
    /// - If no match, create a new snapshot account.
    public func upsertAccountFromCLILogin(authJSONString: String, preferredAccountID: UUID?) async throws -> CodexAuthAccount {
        let data = Data(authJSONString.utf8)
        if isGatewayVirtualAuthPayload(data) {
            throw CLILoginError.gatewayVirtualAuthPayload
        }

        if let preferredAccountID {
            let accounts = try await loadAccounts()
            if let preferred = accounts.first(where: { $0.id == preferredAccountID }) {
                try await updateAccount(preferred, authJSONString: authJSONString)
                return preferred
            }
        }

        let accounts = try await loadAccounts()
        if let matchedByAuth = matchAccount(authData: data, accounts: accounts) {
            try await updateAccount(matchedByAuth, authJSONString: authJSONString)
            return matchedByAuth
        }

        let finalName = deriveAccountName(fromAuthJSONString: authJSONString)
        return try await addAccount(name: finalName, authJSONString: authJSONString)
    }

    /// Persist CLI login payload to snapshots, then refresh login/sync metadata.
    @discardableResult
    public func recordCLILoginSnapshot(
        authJSONString: String,
        preferredAccountID: UUID?,
        loginAt: Date = Date()
    ) async throws -> CodexAuthAccount {
        let account = try await upsertAccountFromCLILogin(
            authJSONString: authJSONString,
            preferredAccountID: preferredAccountID
        )
        try updateLoginSuccess(for: account, date: loginAt)
        try updateSyncSuccess(for: account, date: loginAt)
        return account
    }

    public func deleteAccount(id: UUID, provider: Provider? = nil) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()
        try withAuthFileLock {
            let accounts = try loadAccountsFromAuthFolder()
            guard let account = accounts.first(where: { $0.id == id }) else { return }

            let snapshotData = try? readAccountAuthData(account)

            var map = loadActiveAccountMap()
            let before = map.count
            map = map.filter { $0.value != id.uuidString }
            if map.count != before {
                try saveActiveAccountMap(map)
                if let provider {
                    stopProviderAuthPolling(for: provider.id)
                }
            }
            try removeCodexAccountFromSQLite(id: id)

            guard let provider,
                  Self.isCodexTemplate(provider.templateId),
                  let providerAuthFile = authFile(for: provider)
            else { return }

            let shouldDetachProviderAuth: Bool = {
                guard providerAuthFile.isExists,
                      let snapshotData,
                      !snapshotData.isEmpty,
                      let providerData = try? providerAuthFile.data(),
                      !providerData.isEmpty
                else { return false }
                return cleanedHashHex(for: providerData) == cleanedHashHex(for: snapshotData)
            }()

            if shouldDetachProviderAuth {
                try removeFileOrSymlinkIfPresent(providerAuthFile)
            }

            try persistActiveFingerprintIfNeeded(for: provider)
        }
    }

    // MARK: - Accounts (SQLite-backed, file-compatible)

    func loadAccountsFromAuthFolder() throws -> [CodexAuthAccount] {
        try migrateAccountsStoreToSQLiteIfNeeded()
        let sqliteURL = codexAccountsSQLiteDatabaseURL()
        Self.logger.info(
            "Loading Codex accounts from SQLite. db=\(sqliteURL.path, privacy: .public) exists=\(FileManager.default.fileExists(atPath: sqliteURL.path), privacy: .public)"
        )
        var rows = try queryCodexAccountsRowsFromSQLite()
        if rows.isEmpty {
            try importSnapshotAccountsIntoSQLite()
            rows = try queryCodexAccountsRowsFromSQLite()
        }
        Self.logger.info("Codex accounts raw rows loaded. count=\(rows.count, privacy: .public)")
        var accounts: [CodexAuthAccount] = []
        accounts.reserveCapacity(rows.count)
        for row in rows {
            guard let data = try? loadCodexAccountAuthDataFromSQLite(accountID: row.id),
                  let raw = String(data: data, encoding: .utf8),
                  hasImportableCredentials(authJSONString: raw)
            else {
                try removeCodexAccountFromSQLite(id: row.id)
                continue
            }
            accounts.append(
                CodexAuthAccount(
                    id: row.id,
                    name: row.name,
                    createdAt: row.createdAt,
                    relativeAuthPath: sqliteRelativeAuthPath(for: row.id)
                )
            )
        }
        Self.logger.info("Codex accounts after credential filtering. count=\(accounts.count, privacy: .public)")
        accounts = try pruneDuplicateSnapshotPayloadsIfNeeded(accounts)
        Self.logger.info("Codex accounts after dedupe. count=\(accounts.count, privacy: .public)")
        accounts.sort(by: { $0.createdAt > $1.createdAt })
        return accounts
    }

    func shouldPruneSnapshotFileBeforeLoad(file: STFile, relativeAuthPath: String) throws -> Bool {
        let data = try file.data()
        guard !data.isEmpty else {
            try? file.delete()
            Self.logger.warning("Pruned empty Codex snapshot file before load. file=\(relativeAuthPath, privacy: .public)")
            return true
        }
        guard let raw = String(data: data, encoding: .utf8) else {
            return false
        }
        if isGatewayVirtualAuthPayload(data) || !hasImportableCredentials(authJSONString: raw) {
            try? file.delete()
            Self.logger.warning("Pruned non-importable Codex snapshot file before load. file=\(relativeAuthPath, privacy: .public)")
            return true
        }
        return false
    }

    nonisolated func stableAuthSnapshotFileNames(in folder: STFolder) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.url.path)) ?? []
        return names
            .filter { URL(fileURLWithPath: $0).pathExtension.lowercased() == "json" }
            .sorted()
    }

    public func readAuthJSONString(from provider: Provider) throws -> String? {
        guard let file = authFile(for: provider) else { return nil }
        guard file.isExists else { return nil }
        let raw = try file.read()
        return raw
    }

    public func readTokenPair(for account: CodexAuthAccount) throws -> (idToken: String, accessToken: String, chatgptAccountID: String?)? {
        let data = try readAccountAuthData(account)
        guard !data.isEmpty,
              let authJSON = try? JSON(data: data)
        else { return nil }

        let trimmed: (String?) -> String? = { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { return nil }
            return value
        }

        let idToken = trimmed(authJSON["tokens"]["id_token"].string)
            ?? trimmed(authJSON["tokens"]["idToken"].string)
            ?? trimmed(authJSON["id_token"].string)
            ?? trimmed(authJSON["idToken"].string)
        let accessToken = trimmed(authJSON["tokens"]["access_token"].string)
            ?? trimmed(authJSON["tokens"]["accessToken"].string)
            ?? trimmed(authJSON["access_token"].string)
            ?? trimmed(authJSON["accessToken"].string)
        let payload = idToken.flatMap(CodexAuthSummary.decodeJWTPayloadJSON)
        let chatgptAccountID = CodexAuthSummary.canonicalAccountID(json: authJSON, payload: payload)

        guard let idToken, let accessToken else { return nil }
        return (idToken: idToken, accessToken: accessToken, chatgptAccountID: chatgptAccountID)
    }

    public func loadUsageCache(for account: CodexAuthAccount) throws -> CodexAuthUsageCache? {
        let data = try readAccountAuthData(account)
        guard !data.isEmpty else { return nil }

        guard let root = Self.decodeJSONObject(from: data) else { return nil }
        guard let nolon = root["nolon"] as? JSONObject,
              let cacheObject = nolon["usage_cache"],
              !(cacheObject is NSNull)
        else { return nil }
        let cacheData = try Self.encodeJSONObject(["usage_cache": cacheObject])
        let wrapped = try CodexAuthUsageCache.jsonDecoder().decode(CodexAuthUsageCacheWrapper.self, from: cacheData)
        return wrapped.usageCache
    }

    public func storeUsageCache(_ cache: CodexAuthUsageCache, for account: CodexAuthAccount) throws {
        let existingData = try readAccountAuthData(account)
        var rootObject = Self.decodeJSONObject(from: existingData) ?? [:]
        var nolonObject = (rootObject["nolon"] as? JSONObject) ?? [:]
        if let cacheObject = nolonObject["usage_cache"], !(cacheObject is NSNull) {
            if let existing = try? Self.decodeUsageCache(from: cacheObject),
               Self.isUsageCacheEquivalent(existing, cache) {
                return
            }
        }
        nolonObject["usage_cache"] = cache
        rootObject["nolon"] = nolonObject
        try saveAccountAuthData(account, data: Self.encodeJSONObject(rootObject))
    }

    public func clearUsageCache(for account: CodexAuthAccount) throws {
        let existingData = try readAccountAuthData(account)
        var rootObject = Self.decodeJSONObject(from: existingData) ?? [:]
        var nolonObject = (rootObject["nolon"] as? JSONObject) ?? [:]
        guard nolonObject["usage_cache"] != nil else { return }
        nolonObject.removeValue(forKey: "usage_cache")
        rootObject["nolon"] = nolonObject
        try saveAccountAuthData(account, data: Self.encodeJSONObject(rootObject))
    }

    public func updateSyncSuccess(for account: CodexAuthAccount, date: Date = Date()) throws {
        try updateSyncMetadata(
            account: account,
            loginAt: nil,
            successAt: date,
            failureAt: nil,
            failureMessage: nil,
            clearFailure: true
        )
    }

    public func updateSyncFailure(for account: CodexAuthAccount, message: String, date: Date = Date()) throws {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        try updateSyncMetadata(
            account: account,
            loginAt: nil,
            successAt: nil,
            failureAt: date,
            failureMessage: trimmed.isEmpty ? nil : trimmed,
            clearFailure: false
        )
    }

    public func updateLoginSuccess(for account: CodexAuthAccount, date: Date = Date()) throws {
        try updateSyncMetadata(
            account: account,
            loginAt: date,
            successAt: nil,
            failureAt: nil,
            failureMessage: nil,
            clearFailure: false
        )
    }

    @discardableResult
    public func backfillEmailIfMissing(for account: CodexAuthAccount, email: String) throws -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return false }

        let data = try readAccountAuthData(account)
        guard !data.isEmpty,
              let rootJSON = try? JSON(data: data)
        else { return false }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        var changed = false

        let topLevelEmail = getString(rootObject, path: ["email"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if topLevelEmail?.isEmpty != false {
            setValue(trimmedEmail, path: ["email"], dict: &rootObject)
            changed = true
        }

        let metadataEmail = getString(rootObject, path: ["nolon", "account", "email"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if metadataEmail?.isEmpty != false {
            setValue(trimmedEmail, path: ["nolon", "account", "email"], dict: &rootObject)
            changed = true
        }

        if changed {
            try saveAccountAuthData(account, data: Self.encodeJSONObject(rootObject))
        }
        return changed
    }

    @discardableResult
    public func upsertPlanType(for account: CodexAuthAccount, plan: String) throws -> Bool {
        let trimmedPlan = plan.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlan.isEmpty else { return false }

        let data = try readAccountAuthData(account)
        guard !data.isEmpty,
              let rootJSON = try? JSON(data: data)
        else { return false }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        let currentPlanType = getString(rootObject, path: ["plan_type"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPlan = getString(rootObject, path: ["plan"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsPlanTypeUpdate = currentPlanType != trimmedPlan
        let needsPlanUpdate = currentPlan != trimmedPlan
        guard needsPlanTypeUpdate || needsPlanUpdate else { return false }

        if needsPlanTypeUpdate {
            setValue(trimmedPlan, path: ["plan_type"], dict: &rootObject)
        }
        if needsPlanUpdate {
            setValue(trimmedPlan, path: ["plan"], dict: &rootObject)
        }

        try saveAccountAuthData(account, data: Self.encodeJSONObject(rootObject))
        return true
    }

    public func currentAuthHashHex(for provider: Provider) -> String? {
        guard let raw = try? readAuthJSONString(from: provider) else { return nil }
        return CodexAuthAccount.hashHex(for: raw)
    }

    public func activeAccountId(for provider: Provider) async -> UUID? {
        let accounts = (try? await loadAccounts()) ?? []
        let registryActiveID = activeAccountIdFromRegistry(for: provider, accounts: accounts)
        if let registryActiveID,
           let registryAccount = accounts.first(where: { $0.id == registryActiveID }),
           isRelayProfileAccount(registryAccount) {
            return registryActiveID
        }

        guard let authFile = authFile(for: provider) else {
            return registryActiveID
        }

        // Symlink form (older behavior / user created): resolve target and match by file URL.
        if let destination = resolveSymlinkTarget(for: authFile) {
            if let symlinkData = try? Data(contentsOf: destination.url),
               let matched = matchAccount(authData: symlinkData, accounts: accounts)?.id {
                return matched
            }
        }

        // Regular file: match by cleaned content (ignore Nolon metadata).
        guard let currentData = try? authFile.data(),
              !currentData.isEmpty
        else { return registryActiveID }

        if let matched = matchAccount(authData: currentData, accounts: accounts)?.id {
            return matched
        }

        return registryActiveID
    }

    public func managementStatus(for provider: Provider) async -> CodexManagementStatus {
        let snapshots = (try? await loadAccounts()) ?? []
        let providerAuth = authFile(for: provider)
        let hasProviderAuthFile = providerAuth?.isExists ?? false
        let providerAuthIsSymlink = providerAuth?.isSymbolicLink ?? false
        let needsEnable = hasProviderAuthFile && !providerAuthIsSymlink
        let needsMigration = needsEnable || snapshots.isEmpty
        return CodexManagementStatus(
            hasProviderAuthFile: hasProviderAuthFile,
            providerAuthIsSymlink: providerAuthIsSymlink,
            snapshotCount: snapshots.count,
            needsEnable: needsEnable,
            needsMigration: needsMigration
        )
    }

    @discardableResult
    public func preflightManagedAuthIfNeeded(
        for provider: Provider,
        forceBackup: Bool = false,
        reason: String = "manual"
    ) async throws -> CodexAuthAccount? {
        guard Self.isCodexTemplate(provider.templateId) else { return nil }
        try await migrateLegacyIfNeeded()
        let reconciled = try withAuthFileLock {
            try reconcileProviderAuthWithSnapshotsIfNeeded(for: provider)
        }
        try withAuthFileLock {
            _ = try reconcileActiveSymlinkDriftIfNeeded(for: provider)
            try backupActiveSnapshotIfNeeded(for: provider, force: forceBackup, reason: reason)
            try persistActiveFingerprintIfNeeded(for: provider)
        }
        return reconciled
    }

    public func enableManagedAuth(for provider: Provider) async throws -> CodexManagementReport {
        let affected = try await preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: true,
            reason: "enable_management"
        )
        let snapshots = try await loadAccounts()
        return CodexManagementReport(
            enabled: true,
            migrated: affected != nil,
            affectedAccountID: affected?.id,
            snapshotCount: snapshots.count
        )
    }

    public func migrateManagedAuthData(for provider: Provider) async throws -> CodexManagementReport {
        let affected = try await preflightManagedAuthIfNeeded(
            for: provider,
            forceBackup: true,
            reason: "migrate_management_data"
        )
        let snapshots = try await loadAccounts()
        return CodexManagementReport(
            enabled: true,
            migrated: affected != nil,
            affectedAccountID: affected?.id,
            snapshotCount: snapshots.count
        )
    }

    public func setActiveAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        var map = loadActiveAccountMap()
        let key = activeAccountProviderKey(for: provider)
        map[key] = account.id.uuidString
        if key != provider.id {
            map.removeValue(forKey: provider.id)
        }
        try saveActiveAccountMap(map)
    }

    public func clearActiveAccount(for provider: Provider) throws {
        var map = loadActiveAccountMap()
        let key = activeAccountProviderKey(for: provider)
        map.removeValue(forKey: key)
        if key != provider.id {
            map.removeValue(forKey: provider.id)
        }
        try saveActiveAccountMap(map)
        stopProviderAuthPolling(for: provider.id)
    }

    public func activateAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        guard let authFile = authFile(for: provider) else { return }
        _ = authFile.parentFolder()?.createIfNotExists()
        let managedAuthFile = try materializeManagedActiveAuthFile(for: account, provider: provider)
        try removeFileOrSymlinkIfPresent(authFile)
        try FileManager.default.createSymbolicLink(atPath: authFile.url.path, withDestinationPath: managedAuthFile.url.path)
        Self.logger.info("Activated Codex auth from SQLite snapshot for provider: \(provider.id, privacy: .public)")
    }

    /// Activate snapshot into provider auth and persist active-account registry in one step.
    public func activateAccountAndMarkActive(_ account: CodexAuthAccount, for provider: Provider) throws {
        try withAuthFileLock {
            try activateAccount(account, for: provider)
            try setActiveAccount(account, for: provider)
            _ = try reconcileProviderAuthWithSnapshotsIfNeeded(for: provider)
            // Establish a fresh restore baseline immediately after activation.
            try backupActiveSnapshotIfNeeded(for: provider, force: true, reason: "activate_account")
            try persistActiveFingerprintIfNeeded(for: provider)
            startProviderAuthPolling(for: provider)
        }
    }

    /// Safety check after activation/login:
    /// if provider auth becomes a regular file (instead of symlink), migrate/reconcile into snapshot storage,
    /// then restore provider auth as a symlink to the resolved snapshot.
    @discardableResult
    public func reconcileDetachedProviderAuthIfNeeded(for provider: Provider) throws -> CodexAuthAccount? {
        try withAuthFileLock {
            try reconcileProviderAuthWithSnapshotsIfNeeded(for: provider)
        }
    }

    // MARK: - CLI Login Flow

    public enum CLILoginError: LocalizedError, Sendable {
        case codexHomeUnavailable
        case authFileNotFound
        case authFileInvalidEncoding
        case gatewayVirtualAuthPayload

        public var errorDescription: String? {
            switch self {
            case .codexHomeUnavailable:
                return "Codex home path is unavailable."
            case .authFileNotFound:
                return "No auth.json found."
            case .authFileInvalidEncoding:
                return "auth.json is not valid UTF-8."
            case .gatewayVirtualAuthPayload:
                return "CLI login returned a gateway virtual auth payload. Stop gateway mode and login again."
            }
        }
    }

    /// Prepare for running `codex login` in a terminal:
    /// - If `auth.json` is a symlink, remove it so `codex login` writes a fresh file.
    /// - If `auth.json` is a regular file, snapshot it into `~/.nolon/codex/auth/` and then remove it.
    public func prepareForCLILogin(provider: Provider, archiveAccountName: String?) async throws {
        try await migrateLegacyIfNeeded()

        guard let codexHome = codexHomeFolder(for: provider) else { throw CLILoginError.codexHomeUnavailable }
        _ = codexHome.createIfNotExists()

        guard let authFile = authFile(for: provider) else { throw CLILoginError.codexHomeUnavailable }
        guard authFile.isExists || authFile.isSymbolicLink else { return }
        if authFile.isSymbolicLink {
            // The active auth is already stored elsewhere; just detach so `codex login` can write a fresh file.
            try removeFileOrSymlinkIfPresent(authFile)
            return
        }

        // Regular file: if it matches an existing snapshot, just detach to avoid duplicating the account.
        if await activeAccountId(for: provider) != nil {
            try removeFileOrSymlinkIfPresent(authFile)
            return
        }

        // Regular file: snapshot it first, then remove.
        let raw = try authFile.read()
        let defaultName = deriveAccountName(fromAuthJSONString: raw)
        let name = (archiveAccountName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? defaultName
        _ = try await addAccount(name: name, authJSONString: raw)
        try removeFileOrSymlinkIfPresent(authFile)
    }

    /// After the user finishes `codex login`, call this to snapshot the freshly created `auth.json`
    /// into `~/.nolon/codex/auth/`, then sync provider `auth.json` and mark active in runtime registry.
    @discardableResult
    public func finalizeCLILogin(provider: Provider, newAccountName: String) async throws -> CodexAuthAccount {
        guard let authFile = authFile(for: provider) else { throw CLILoginError.codexHomeUnavailable }
        guard authFile.isExists else { throw CLILoginError.authFileNotFound }
        let raw = try authFile.read()

        let trimmed = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? deriveAccountName(fromAuthJSONString: raw) : trimmed

        let account = try await addAccount(name: name, authJSONString: raw)
        try activateAccountAndMarkActive(account, for: provider)
        return account
    }

    // MARK: - Helpers

    func uniqueAuthFileName(for name: String, existing: Set<String>) -> String {
        let base = sanitizeFileStem(name)
        var candidate = "\(base).json"
        var idx = 2
        while existing.contains("auth/\(candidate)") {
            candidate = "\(base)-\(idx).json"
            idx += 1
        }
        return candidate
    }

    func uniqueAuthFileName(forStem stem: String, existing: Set<String>) -> String {
        let trimmed = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "account" : trimmed
        var candidate = "\(base).json"
        var idx = 2
        while existing.contains("auth/\(candidate)") {
            candidate = "\(base)-\(idx).json"
            idx += 1
        }
        return candidate
    }

    func sanitizeFileStem(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "account" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = trimmed.unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(mapped)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "account" : collapsed.lowercased()
    }

    func uniqueExportFileName(preferred: String, usedNames: inout Set<String>) -> String {
        let base = sanitizeFileStem(preferred)
        var candidate = "\(base).json"
        var index = 2
        while usedNames.contains(candidate) {
            candidate = "\(base)-\(index).json"
            index += 1
        }
        usedNames.insert(candidate)
        return candidate
    }

    struct LegacyCodexAuthAccount: Codable, Sendable {
        let id: UUID
        let name: String
        let createdAt: Date
        let authJSONString: String
    }

    func migrateLegacyIfNeeded() async throws {
        try migrateLegacyIndexFileIfNeeded()

        // Legacy file used to live at ~/.nolon/codex-accounts.json
        let legacyFile = rootFolder.file("codex-accounts.json")
        guard legacyFile.isExists else { return }

        let data = try legacyFile.data()
        guard !data.isEmpty else {
            try? legacyFile.delete()
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let legacy = try? decoder.decode([LegacyCodexAuthAccount].self, from: data) else { return }

        _ = nolonCodexAuthFolder().createIfNotExists()

        let existing = existingAuthRelativePaths()
        var used = existing
        for item in legacy {
            let fileName = uniqueAuthFileName(for: item.name, existing: used)
            let relativePath = "auth/\(fileName)"
            let data = try normalizeAccountPayloadData(
                authJSONString: item.authJSONString,
                preferredId: item.id,
                preferredCreatedAt: item.createdAt,
                relativeAuthPath: relativePath
            )
            let account = accountFromNormalizedPayloadData(data, fallbackRelativeAuthPath: relativePath)
            try upsertCodexAccountInSQLite(account, authData: data)
            used.insert(relativePath)
        }

        // Keep a backup instead of deleting to be safe.
        let backupFile = rootFolder.file("codex-accounts.legacy.json")
        try? backupFile.delete()
        try legacyFile.move(to: backupFile)
    }

    public nonisolated func deriveAccountName(fromAuthJSONString authJSONString: String) -> String {
        let summary = CodexAuthSummary.fromJSONString(authJSONString)
        return summary.preferredDisplayName()
    }

    public nonisolated func deriveEmail(fromAuthJSONString authJSONString: String) -> String? {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else { return nil }
        return deriveEmail(from: json)
    }

    public nonisolated func hasImportableCredentials(authJSONString: String) -> Bool {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else { return false }

        let trimmed: (String?) -> String? = { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }

        let idToken = trimmed(json["tokens"]["id_token"].string)
            ?? trimmed(json["tokens"]["idToken"].string)
            ?? trimmed(json["id_token"].string)
            ?? trimmed(json["idToken"].string)
        let accessToken = trimmed(json["tokens"]["access_token"].string)
            ?? trimmed(json["tokens"]["accessToken"].string)
            ?? trimmed(json["access_token"].string)
            ?? trimmed(json["accessToken"].string)
        let hasTokenPair = (idToken != nil && accessToken != nil)

        let authMode = Self.canonicalAuthMode(trimmed(json["auth_mode"].string))
        let hasChatGPTTokenMode = (idToken != nil && authMode == Self.canonicalChatGPTAuthMode)

        let apiKey = trimmed(json["OPENAI_API_KEY"].string)
            ?? trimmed(json["openai_api_key"].string)
            ?? trimmed(json["api_key"].string)
            ?? trimmed(json["apiKey"].string)
        let hasAPIKey = apiKey != nil
        return hasTokenPair || hasChatGPTTokenMode || hasAPIKey
    }

    struct CredentialIdentity: Sendable {
        let apiKey: String?
        let baseURL: String?
        let email: String?
        let accountID: String?
    }

    enum CredentialIdentityValidationResult: Sendable {
        case valid(identityKey: String, normalized: CredentialIdentity)
        case invalid(reason: String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    nonisolated func credentialIdentityValidationResult(from json: JSON) -> CredentialIdentityValidationResult {
        let apiKey = firstNonEmptyString(in: json, paths: [
            ["OPENAI_API_KEY"],
            ["openai_api_key"],
            ["api_key"],
            ["apiKey"],
        ])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = firstNonEmptyString(in: json, paths: [
            ["base_url"],
            ["baseURL"],
        ])?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizeLower: (String?) -> String? = { raw in
            guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty
            else { return nil }
            return trimmed.lowercased()
        }
        let email = normalizeLower(deriveEmail(from: json))
        let accountID = normalizeLower(CodexAuthSummary.canonicalAccountID(json: json, payload: nil))

        let normalized = CredentialIdentity(
            apiKey: apiKey?.isEmpty == true ? nil : apiKey,
            baseURL: baseURL?.isEmpty == true ? nil : baseURL,
            email: email?.isEmpty == true ? nil : email,
            accountID: accountID?.isEmpty == true ? nil : accountID
        )

        let hasAPIKey = normalized.apiKey != nil
        let hasBaseURL = normalized.baseURL != nil
        let hasEmail = normalized.email != nil
        let hasAccountID = normalized.accountID != nil
        let composite = [
            normalized.apiKey ?? "",
            normalized.baseURL ?? "",
            normalized.email ?? "",
            normalized.accountID ?? "",
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(composite.utf8))
        let identityKey = digest.map { String(format: "%02x", $0) }.joined()

        if hasAPIKey && hasBaseURL && !hasEmail && !hasAccountID {
            return .valid(identityKey: identityKey, normalized: normalized)
        }
        if hasAPIKey && !hasBaseURL && !hasEmail && !hasAccountID {
            return .valid(identityKey: identityKey, normalized: normalized)
        }
        if !hasAPIKey && !hasBaseURL && hasEmail && hasAccountID {
            return .valid(identityKey: identityKey, normalized: normalized)
        }
        return .invalid(reason: "仅支持 (api_key/base_url) 或 (api_key) 或 (email/account_id) 三种凭证组合。")
    }

    nonisolated func buildCredentialIdentityKey(authJSONString: String) -> String? {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else {
            return nil
        }
        switch credentialIdentityValidationResult(from: json) {
        case let .valid(identityKey, _):
            return identityKey
        case .invalid:
            return nil
        }
    }

    nonisolated func credentialUsabilityScore(authJSONString: String) -> Int {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else {
            return 0
        }

        if firstNonEmptyString(in: json, paths: [
            ["OPENAI_API_KEY"],
            ["openai_api_key"],
            ["api_key"],
            ["apiKey"],
        ]) != nil {
            return 300
        }

        let idToken = firstNonEmptyString(in: json, paths: [
            ["tokens", "id_token"],
            ["tokens", "idToken"],
            ["id_token"],
            ["idToken"],
        ])
        let accessToken = firstNonEmptyString(in: json, paths: [
            ["tokens", "access_token"],
            ["tokens", "accessToken"],
            ["access_token"],
            ["accessToken"],
        ])
        guard idToken != nil, accessToken != nil else {
            return 0
        }

        var score = 100
        let refreshToken = firstNonEmptyString(in: json, paths: [
            ["tokens", "refresh_token"],
            ["tokens", "refreshToken"],
            ["refresh_token"],
            ["refreshToken"],
        ])
        if refreshToken != nil {
            score += 80
        }

        if let expiresAt = oauthExpiryDate(from: json) {
            if expiresAt > Date() {
                score += 40
            } else if refreshToken != nil {
                score += 20
            } else {
                score -= 60
            }
        }
        return max(0, score)
    }

    nonisolated func oauthExpiryDate(from json: JSON) -> Date? {
        let raw = firstNonEmptyString(in: json, paths: [
            ["expired"],
            ["expires_at"],
            ["expiresAt"],
            ["tokens", "expired"],
            ["tokens", "expires_at"],
            ["tokens", "expiresAt"],
        ])
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = Self.makeISOFormatter().date(from: trimmed) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: trimmed)
    }

    struct ValidatedExportEntry {
        let preferredFileStem: String
        let rawJSONString: String
        let authJSON: JSON
        let summary: CodexAuthSummary
    }

    nonisolated func resolveCardKind(for authJSON: JSON) -> CodexAuthSummary.CardKind? {
        let hasRelayBlock = authJSON["nolon"]["relay"] != JSON.null && authJSON["nolon"]["relay"].dictionaryObject?.isEmpty == false
        return CodexAuthSummary.resolveCardKind(
            explicitKind: authJSON["nolon"]["account"]["kind"].string,
            authMode: authJSON["auth_mode"].string,
            hasRelayBlock: hasRelayBlock
        )
    }

    nonisolated func firstNonEmptyString(in json: JSON?, paths: [[String]]) -> String? {
        CodexAuthManagerSupport.firstNonEmptyString(in: json, paths: paths)
    }

    nonisolated func makeValidatedExportEntries(
        from results: [CodexImportValidationResult]
    ) -> [ValidatedExportEntry] {
        results.compactMap { result in
            guard result.isValid,
                  let rawJSONString = result.authJSONString,
                  let data = rawJSONString.data(using: .utf8),
                  let authJSON = try? JSON(data: data)
            else {
                return nil
            }

            let fallbackFileStem = result.fileURL.deletingPathExtension().lastPathComponent
            return ValidatedExportEntry(
                preferredFileStem: fallbackFileStem.isEmpty ? "account" : fallbackFileStem,
                rawJSONString: rawJSONString,
                authJSON: authJSON,
                summary: CodexAuthSummary.fromJSONString(rawJSONString)
            )
        }
    }

}
