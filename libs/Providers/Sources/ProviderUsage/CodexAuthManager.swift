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
    private nonisolated static let canonicalChatGPTAuthMode = "chatgpt"
    private nonisolated static let legacyChatGPTAuthMode = "chatgptAuthTokens"

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
    private struct PathName: RawRepresentable, ExpressibleByStringLiteral {
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

    private static let logger = Logger(subsystem: "com.nolon", category: "CodexAuthManager")
    private static let gatewayVirtualAPIKey = "nolon-gateway-virtual-api-key"
    private nonisolated static let canonicalCodexActiveProviderKeys: Set<String> = ["codex", "codex-xcode"]
    private nonisolated static func isCodexTemplate(_ templateID: String?) -> Bool {
        templateID == ProviderTemplate.codex.rawValue || templateID == ProviderTemplate.codexXcode.rawValue
    }
    private nonisolated static func canonicalCodexActiveProviderKey(for templateID: String?) -> String? {
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
    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return encoder
    }()
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return decoder
    }()

    private typealias JSONObject = [String: Any]

    private nonisolated let rootFolder: STFolder
    private nonisolated let refreshCodexTokenAction: @Sendable (_ refreshToken: String) async throws -> RefreshedOAuthTokens
    private nonisolated let fetchCodexAccountInfoAction: @Sendable (_ accessToken: String) async throws -> FetchedOAuthAccountInfo?
    private var providerAuthPollingTasks: [String: Task<Void, Never>] = [:]
    private var providerAuthLastHashes: [String: String] = [:]
    private let providerAuthPollIntervalNanoseconds: UInt64 = 2_000_000_000

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

    private nonisolated func activeAccountProviderKey(for provider: Provider) -> String {
        if let canonical = Self.canonicalCodexActiveProviderKey(for: provider.templateId) {
            return canonical
        }
        return provider.id
    }

    private nonisolated func resolveActiveAccountID(from map: [String: String], for provider: Provider) -> String? {
        let canonicalKey = activeAccountProviderKey(for: provider)
        if let value = map[canonicalKey] {
            return value
        }
        guard canonicalKey != provider.id else { return nil }
        return map[provider.id]
    }

    private nonisolated func configuredActiveAccountProviderKeys() -> Set<String> {
        let providers = configuredProviders()
        guard !providers.isEmpty else { return Self.canonicalCodexActiveProviderKeys }

        var keys = Set<String>()
        for provider in providers {
            keys.insert(activeAccountProviderKey(for: provider))
        }
        keys.formUnion(Self.canonicalCodexActiveProviderKeys)
        return keys
    }

    private nonisolated func configuredProviders() -> [Provider] {
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

    private nonisolated func sanitizeActiveAccountMap(_ map: [String: String]) -> [String: String] {
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
        let file = nolonCodexRootFolder().file(relativeAuthPath)
        materializeSQLiteAuthMirrorIfNeeded(file: file, relativeAuthPath: relativeAuthPath)
        return file
    }

    public nonisolated func accountAuthData(relativeAuthPath: String) -> Data? {
        let file = accountAuthFile(relativeAuthPath: relativeAuthPath)
        if let data = try? file.data(), !data.isEmpty {
            return data
        }
        guard let accountID = sqliteAccountID(fromRelativeAuthPath: relativeAuthPath),
              let data = try? loadCodexAccountAuthDataFromSQLite(accountID: accountID),
              !data.isEmpty
        else {
            return nil
        }
        return data
    }

    public nonisolated func accountAuthData(for account: CodexAuthAccount) -> Data? {
        if let data = try? loadCodexAccountAuthDataFromSQLite(accountID: account.id), !data.isEmpty {
            return data
        }
        return accountAuthData(relativeAuthPath: account.relativeAuthPath)
    }

    /// Reads account auth payload without triggering legacy mirror materialization on disk.
    public nonisolated func accountAuthDataWithoutMaterialization(for account: CodexAuthAccount) -> Data? {
        if let data = try? loadCodexAccountAuthDataFromSQLite(accountID: account.id), !data.isEmpty {
            return data
        }

        let file = nolonCodexRootFolder().file(account.relativeAuthPath)
        if let data = try? file.data(), !data.isEmpty {
            return data
        }
        return nil
    }

    private nonisolated func materializeSQLiteAuthMirrorIfNeeded(file: STFile, relativeAuthPath: String) {
        guard !file.isExists else { return }
        guard let accountID = sqliteAccountID(fromRelativeAuthPath: relativeAuthPath) else { return }
        guard let data = try? loadCodexAccountAuthDataFromSQLite(accountID: accountID), !data.isEmpty else { return }
        _ = file.parentFolder()?.createIfNotExists()
        try? file.overlay(with: data)
    }

    private nonisolated func sqliteAccountID(fromRelativeAuthPath relativeAuthPath: String) -> UUID? {
        let normalized = relativeAuthPath.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("auth/") else { return nil }
        let fileName = URL(fileURLWithPath: normalized).lastPathComponent
        guard fileName.hasSuffix(".json") else { return nil }
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        return UUID(uuidString: stem)
    }

    private nonisolated func sqliteRelativeAuthPath(for accountID: UUID) -> String {
        "auth/\(accountID.uuidString.lowercased()).json"
    }

    private nonisolated func managedActiveAuthFolder(for providerID: String) -> STFolder {
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

    private func materializeManagedActiveAuthFile(for account: CodexAuthAccount, provider: Provider) throws -> STFile {
        let folder = managedActiveAuthFolder(for: provider.id)
        _ = folder.createIfNotExists()
        let file = folder.file("auth.json")
        let data = try readAccountAuthData(account)
        try file.overlay(with: data)
        try cleanupLegacyManagedActiveAuthFiles(in: folder, keeping: file.attributes.name)
        return file
    }

    private func cleanupLegacyManagedActiveAuthFiles(in folder: STFolder, keeping fileName: String) throws {
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

    private nonisolated static func canonicalAuthMode(_ raw: String?) -> String? {
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

    private func loadAccountsFromAuthFolder() throws -> [CodexAuthAccount] {
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

    private func shouldPruneSnapshotFileBeforeLoad(file: STFile, relativeAuthPath: String) throws -> Bool {
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

    private nonisolated func stableAuthSnapshotFileNames(in folder: STFolder) -> [String] {
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

    private func uniqueAuthFileName(for name: String, existing: Set<String>) -> String {
        let base = sanitizeFileStem(name)
        var candidate = "\(base).json"
        var idx = 2
        while existing.contains("auth/\(candidate)") {
            candidate = "\(base)-\(idx).json"
            idx += 1
        }
        return candidate
    }

    private func uniqueAuthFileName(forStem stem: String, existing: Set<String>) -> String {
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

    private func sanitizeFileStem(_ name: String) -> String {
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

    private func uniqueExportFileName(preferred: String, usedNames: inout Set<String>) -> String {
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

    private struct LegacyCodexAuthAccount: Codable, Sendable {
        let id: UUID
        let name: String
        let createdAt: Date
        let authJSONString: String
    }

    private func migrateLegacyIfNeeded() async throws {
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

    private struct CredentialIdentity: Sendable {
        let apiKey: String?
        let baseURL: String?
        let email: String?
        let accountID: String?
    }

    private enum CredentialIdentityValidationResult: Sendable {
        case valid(identityKey: String, normalized: CredentialIdentity)
        case invalid(reason: String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    private nonisolated func credentialIdentityValidationResult(from json: JSON) -> CredentialIdentityValidationResult {
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

    private nonisolated func buildCredentialIdentityKey(authJSONString: String) -> String? {
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

    private nonisolated func credentialUsabilityScore(authJSONString: String) -> Int {
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

    private nonisolated func oauthExpiryDate(from json: JSON) -> Date? {
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

    private struct ValidatedExportEntry {
        let preferredFileStem: String
        let rawJSONString: String
        let authJSON: JSON
        let summary: CodexAuthSummary
    }

    private nonisolated func resolveCardKind(for authJSON: JSON) -> CodexAuthSummary.CardKind? {
        let hasRelayBlock = authJSON["nolon"]["relay"] != JSON.null && authJSON["nolon"]["relay"].dictionaryObject?.isEmpty == false
        return CodexAuthSummary.resolveCardKind(
            explicitKind: authJSON["nolon"]["account"]["kind"].string,
            authMode: authJSON["auth_mode"].string,
            hasRelayBlock: hasRelayBlock
        )
    }

    private nonisolated func firstNonEmptyString(in json: JSON?, paths: [[String]]) -> String? {
        CodexAuthManagerSupport.firstNonEmptyString(in: json, paths: paths)
    }

    private nonisolated func makeValidatedExportEntries(
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

private extension CodexAuthManager {
    struct CodexAuthUsageCacheWrapper: Codable {
        let usageCache: CodexAuthUsageCache

        enum CodingKeys: String, CodingKey {
            case usageCache = "usage_cache"
        }
    }

    private struct AccountSnapshot {
        let account: CodexAuthAccount
        let data: Data
        let cleanedData: Data
        let summary: CodexAuthSummary
        let apiKey: String?
        let identity: AccountIdentity
    }

    private struct AccountIdentity {
        let accountID: String?
        let email: String?
        let nolonAccountID: String?
    }

    private struct AuthSourceCandidate {
        enum Source: String {
            case provider
            case snapshot
        }

        let source: Source
        let account: CodexAuthAccount?
        let data: Data
        let rawJSONString: String?
        let summary: CodexAuthSummary
        let score: Int
    }
    private static func decodeJSONObject(from data: Data) -> JSONObject? {
        CodexAuthManagerSupport.decodeJSONObject(from: data, decoder: jsonDecoder)
    }

    private static func encodeJSONObject(_ object: JSONObject) throws -> Data {
        try CodexAuthManagerSupport.encodeJSONObject(object, encoder: jsonEncoder)
    }

    private static func decodeUsageCache(from cacheObject: Any) throws -> CodexAuthUsageCache {
        let cacheData = try encodeJSONObject(["usage_cache": cacheObject])
        let wrapped = try CodexAuthUsageCache.jsonDecoder().decode(CodexAuthUsageCacheWrapper.self, from: cacheData)
        return wrapped.usageCache
    }

    private static func isUsageCacheEquivalent(_ lhs: CodexAuthUsageCache, _ rhs: CodexAuthUsageCache) -> Bool {
        var left = lhs
        var right = rhs
        let referenceDate = Date(timeIntervalSince1970: 0)
        left.cachedAt = referenceDate
        right.cachedAt = referenceDate
        left.creditsRefreshedAt = nil
        right.creditsRefreshedAt = nil
        return left == right
    }

    private nonisolated func resolveSymlinkTarget(for path: any STPathProtocol) -> STPath? {
        guard path.isSymbolicLink else { return nil }
        return try? path.destinationOfSymbolicLink()
    }

    private nonisolated func standardizedPathString(_ path: any STPathProtocol) -> String {
        STPath.standardizedPath(path.url.path).path
    }

    private func getString(_ dict: JSONObject, path: [String]) -> String? {
        CodexAuthManagerSupport.getString(dict, path: path)
    }

    private func getDictionary(_ dict: JSONObject, path: [String]) -> JSONObject? {
        CodexAuthManagerSupport.getDictionary(dict, path: path)
    }

    private func setValue(_ value: Any, path: [String], dict: inout JSONObject) {
        CodexAuthManagerSupport.setValue(value, path: path, dict: &dict)
    }

    private func removeValue(path: [String], dict: inout JSONObject) {
        CodexAuthManagerSupport.removeValue(path: path, dict: &dict)
    }

    private func encodeJSONObjectObject<T: Encodable>(_ value: T) throws -> JSONObject {
        try CodexAuthManagerSupport.encodeJSONObjectObject(value)
    }

    private func loadAccountSnapshots(for accounts: [CodexAuthAccount]) -> [AccountSnapshot] {
        var snapshots: [AccountSnapshot] = []
        snapshots.reserveCapacity(accounts.count)

        for account in accounts {
            guard let data = try? readAccountAuthData(account), !data.isEmpty else { continue }
            let cleaned = Self.cleanedAuthJSONData(from: data) ?? data
            let summary = CodexAuthSummary.fromJSONData(data)
            let apiKey = extractAPIKey(from: data)
            let identity = accountIdentity(from: data, summary: summary)
            snapshots.append(
                AccountSnapshot(
                    account: account,
                    data: data,
                    cleanedData: cleaned,
                    summary: summary,
                    apiKey: apiKey,
                    identity: identity
                )
            )
        }

        return snapshots
    }

    private func accountIdentity(from data: Data, summary: CodexAuthSummary? = nil) -> AccountIdentity {
        let resolvedSummary = summary ?? CodexAuthSummary.fromJSONData(data)
        let root = Self.decodeJSONObject(from: data)
        let nolonAccountID = normalizedNolonAccountID(
            root.flatMap { getString($0, path: ["nolon", "account", "id"]) }
        )
        return AccountIdentity(
            accountID: normalizedAccountID(resolvedSummary.accountID),
            email: normalizedEmail(resolvedSummary.email),
            nolonAccountID: nolonAccountID
        )
    }

    private func matchAccountByStrictIdentity(
        authIdentity: AccountIdentity,
        snapshots: [AccountSnapshot],
        excludedAccountID: UUID?
    ) -> CodexAuthAccount? {
        guard let authAccountID = authIdentity.accountID else { return nil }

        if let authEmail = authIdentity.email {
            let matches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
                guard snapshot.identity.accountID == authAccountID,
                      snapshot.identity.email == authEmail,
                      snapshot.account.id != excludedAccountID
                else { return nil }
                return snapshot.account
            }
            return pickLatestAccount(from: matches)
        }

        if let authNolonAccountID = authIdentity.nolonAccountID {
            let matches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
                guard snapshot.identity.accountID == authAccountID,
                      snapshot.identity.nolonAccountID == authNolonAccountID,
                      snapshot.account.id != excludedAccountID
                else { return nil }
                return snapshot.account
            }
            return pickLatestAccount(from: matches)
        }

        // Only `account_id` is not enough to merge snapshots.
        return nil
    }

    private func existingAuthRelativePaths() -> Set<String> {
        let rows = (try? queryCodexAccountsRowsFromSQLite()) ?? []
        let sqlitePaths = rows.map { sqliteRelativeAuthPath(for: $0.id) }
        return Set(sqlitePaths)
    }

    private func activeAccountIdFromRegistry(for provider: Provider, accounts: [CodexAuthAccount]) -> UUID? {
        let map = loadActiveAccountMap()
        guard let raw = resolveActiveAccountID(from: map, for: provider), let id = UUID(uuidString: raw) else { return nil }
        if accounts.contains(where: { $0.id == id }) {
            return id
        }
        return containsGatewayVirtualAccount(id: id) ? id : nil
    }

    private func containsGatewayVirtualAccount(id: UUID) -> Bool {
        let folder = nolonCodexGatewayVirtualAuthFolder()
        let fileNames = stableAuthSnapshotFileNames(in: folder)
        for fileName in fileNames {
            let relativePath = "gateway/virtual-auth/\(fileName)"
            let file = folder.file(fileName)
            guard let account = try? loadAccount(file: file, relativeAuthPath: relativePath) else {
                continue
            }
            if account.id == id {
                return true
            }
        }
        return false
    }

    private func loadGatewayVirtualAccount(byStandardizedPath path: String) -> CodexAuthAccount? {
        let folder = nolonCodexGatewayVirtualAuthFolder()
        let fileNames = stableAuthSnapshotFileNames(in: folder)
        for fileName in fileNames {
            let relativePath = "gateway/virtual-auth/\(fileName)"
            let file = folder.file(fileName)
            guard standardizedPathString(file) == path else { continue }
            if let account = try? loadAccount(file: file, relativeAuthPath: relativePath) {
                return account
            }
        }
        return nil
    }

    private func isRelayProfileAccount(_ account: CodexAuthAccount) -> Bool {
        guard let data = try? readAccountAuthData(account), !data.isEmpty else { return false }
        return CodexAuthSummary.fromJSONData(data).cardKind == .relayProfile
    }

    private func isGatewayVirtualAccount(_ account: CodexAuthAccount) -> Bool {
        let relative = account.relativeAuthPath.lowercased()
        if relative.hasPrefix("gateway/virtual-auth/") || relative.contains("/__gateway_reply__-") {
            return true
        }
        guard let data = try? readAccountAuthData(account),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nolon = object["nolon"] as? [String: Any],
              let relay = nolon["relay"] as? [String: Any],
              let params = relay["query_params"] as? [String: Any]
        else {
            return false
        }
        return (params["nolon_gateway_virtual"] as? String) == "1"
    }

    private func isGatewayVirtualAuthPayload(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        if let apiKey = object["OPENAI_API_KEY"] as? String {
            let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedAPIKey == Self.gatewayVirtualAPIKey {
                return true
            }
        }
        guard let nolon = object["nolon"] as? [String: Any],
              let relay = nolon["relay"] as? [String: Any],
              let params = relay["query_params"] as? [String: Any]
        else {
            return false
        }
        if let marker = params["nolon_gateway_virtual"] as? String {
            let normalized = marker.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true"
        }
        if let marker = params["nolon_gateway_virtual"] as? NSNumber {
            return marker.intValue != 0
        }
        return false
    }

    private func loadActiveAccountMap() -> [String: String] {
        if let map = try? loadActiveAccountMapFromSQLite(), !map.isEmpty {
            let sanitized = sanitizeActiveAccountMap(map)
            if sanitized != map {
                try? saveActiveAccountMap(sanitized)
            }
            return sanitized
        }

        let file = activeAccountsFile()
        guard file.isExists,
              let data = try? file.data(),
              !data.isEmpty,
              let root = Self.decodeJSONObject(from: data),
              let providers = root["providers"] as? JSONObject
        else { return [:] }

        let reduced = providers.reduce(into: [String: String]()) { result, element in
            if let value = element.value as? String,
               UUID(uuidString: value) != nil {
                result[element.key] = value
            }
        }
        let sanitized = sanitizeActiveAccountMap(reduced)
        if sanitized != reduced {
            try? saveActiveAccountMap(sanitized)
        }
        return sanitized
    }

    private func saveActiveAccountMap(_ map: [String: String]) throws {
        let sanitized = sanitizeActiveAccountMap(map)
        try migrateAccountsStoreToSQLiteIfNeeded()
        try saveActiveAccountMapToSQLite(sanitized)
        try writeActiveAccountMapJSONMirror(sanitized)
    }

    private nonisolated func writeActiveAccountMapJSONMirror(_ map: [String: String]) throws {
        let file = activeAccountsFile()
        _ = file.parentFolder()?.createIfNotExists()

        let root: JSONObject
        if map.isEmpty {
            root = ["providers": JSONObject()]
        } else {
            root = ["providers": map]
        }
        try file.overlay(with: Self.encodeJSONObject(root))
    }

    func matchAccount(authData: Data, accounts: [CodexAuthAccount]) -> CodexAuthAccount? {
        let snapshots = loadAccountSnapshots(for: accounts)
        let authSummary = CodexAuthSummary.fromJSONData(authData)
        let authIdentity = accountIdentity(from: authData, summary: authSummary)
        let authAPIKey = extractAPIKey(from: authData)

        if let strictMatch = matchAccountByStrictIdentity(
            authIdentity: authIdentity,
            snapshots: snapshots,
            excludedAccountID: nil
        ) {
            return strictMatch
        }

        let apiKeyMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authAPIKey,
                  let apiKey = snapshot.apiKey,
                  apiKey == authAPIKey
            else { return nil }
            return snapshot.account
        }

        let emailMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authEmail = authIdentity.email,
                  snapshot.identity.email == authEmail
            else { return nil }
            return snapshot.account
        }

        if authIdentity.accountID != nil {
            // For account-scoped OAuth payloads, only strict identity matches can update snapshots.
            let cleanedAuthData = Self.cleanedAuthJSONData(from: authData) ?? authData
            if let match = snapshots.first(where: { $0.cleanedData == cleanedAuthData }) {
                return match.account
            }
            return nil
        }

        if let match = pickLatestAccount(from: apiKeyMatches) {
            return match
        }
        if let match = pickLatestAccount(from: emailMatches) {
            return match
        }

        let cleanedAuthData = Self.cleanedAuthJSONData(from: authData) ?? authData
        if let match = snapshots.first(where: { $0.cleanedData == cleanedAuthData }) {
            return match.account
        }
        return nil
    }

    func extractAPIKey(from data: Data) -> String? {
        guard let json = try? JSON(data: data) else { return nil }
        let value = json["OPENAI_API_KEY"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    func updateSyncMetadata(
        account: CodexAuthAccount,
        loginAt: Date?,
        successAt: Date?,
        failureAt: Date?,
        failureMessage: String?,
        clearFailure: Bool
    ) throws {
        let data = try readAccountAuthData(account)
        var rootObject = Self.decodeJSONObject(from: data) ?? [:]
        var nolonObject = (rootObject["nolon"] as? JSONObject) ?? [:]
        var accountObject = (nolonObject["account"] as? JSONObject) ?? [:]

        if let loginAt {
            accountObject["lastLoginAt"] = Self.makeISOFormatter().string(from: loginAt)
        }
        if let successAt {
            accountObject["lastSyncSucceededAt"] = Self.makeISOFormatter().string(from: successAt)
        }
        if let failureAt {
            accountObject["lastSyncFailedAt"] = Self.makeISOFormatter().string(from: failureAt)
        }
        if let failureMessage {
            accountObject["lastSyncFailureMessage"] = failureMessage
        }
        if clearFailure {
            accountObject.removeValue(forKey: "lastSyncFailedAt")
            accountObject.removeValue(forKey: "lastSyncFailureMessage")
        }

        nolonObject["account"] = accountObject
        rootObject["nolon"] = nolonObject
        try saveAccountAuthData(account, data: Self.encodeJSONObject(rootObject))
    }

    func normalizedEmail(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value.lowercased()
    }

    func normalizedAccountID(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value.lowercased()
    }

    func normalizedNolonAccountID(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value.lowercased()
    }

    func pickLatestAccount(from accounts: [CodexAuthAccount]) -> CodexAuthAccount? {
        guard !accounts.isEmpty else { return nil }
        return accounts.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    func createSnapshotAccount(authJSONString: String) throws -> CodexAuthAccount {
        let name = deriveAccountName(fromAuthJSONString: authJSONString)
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

    func loadAccount(file: STFile, relativeAuthPath: String) throws -> CodexAuthAccount {
        let data = try file.data()
        guard !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let rootJSON = try? JSON(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        let fileDates = safeFileDates(for: file)
        let fallbackCreatedAt = max(fileDates.creationDate, fileDates.modificationDate)
        var changed = false

        let existingId = getString(rootObject, path: ["nolon", "account", "id"]).flatMap(UUID.init(uuidString:))
        let id = existingId ?? UUID()
        if existingId == nil {
            setValue(id.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
            changed = true
        }

        let existingRelativePath = getString(rootObject, path: ["nolon", "account", "relativeAuthPath"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if existingRelativePath != relativeAuthPath {
            setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)
            changed = true
        }

        let existingCreatedAt = getString(rootObject, path: ["nolon", "account", "createdAt"]).flatMap { Self.makeISOFormatter().date(from: $0) }
        let createdAt = existingCreatedAt ?? fallbackCreatedAt
        if existingCreatedAt == nil {
            setValue(Self.makeISOFormatter().string(from: createdAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
            changed = true
        }

        let existingUpdatedAt = getString(rootObject, path: ["nolon", "account", "updatedAt"]).flatMap { Self.makeISOFormatter().date(from: $0) }
        let updatedAt = existingUpdatedAt ?? max(fileDates.modificationDate, createdAt)
        if existingUpdatedAt == nil {
            setValue(Self.makeISOFormatter().string(from: updatedAt), path: ["nolon", "account", "updatedAt"], dict: &rootObject)
            changed = true
        }

        let derivedEmail = deriveEmail(from: rootJSON)
        let existingEmail = getString(rootObject, path: ["nolon", "account", "email"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (existingEmail?.isEmpty == false ? existingEmail : nil) ?? derivedEmail

        if let email, (existingEmail == nil || existingEmail?.isEmpty == true) {
            setValue(email, path: ["nolon", "account", "email"], dict: &rootObject)
            changed = true
        }
        let topEmail = getString(rootObject, path: ["email"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, (topEmail == nil || topEmail?.isEmpty == true) {
            setValue(email, path: ["email"], dict: &rootObject)
            changed = true
        }

        let legacyName = getString(rootObject, path: ["nolon", "account", "name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackFileStem = URL(fileURLWithPath: relativeAuthPath).deletingPathExtension().lastPathComponent
        let summary = CodexAuthSummary.fromJSONData(data)
        let name = summary.preferredDisplayName(fallbackFileStem: fallbackFileStem)

        if legacyName != nil {
            removeValue(path: ["nolon", "account", "name"], dict: &rootObject)
            changed = true
        }

        let existingKind = getString(rootObject, path: ["nolon", "account", "kind"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let derivedKind = deriveAccountKind(from: rootJSON)
        if (existingKind == nil || existingKind?.isEmpty == true),
           let derivedKind
        {
            setValue(derivedKind, path: ["nolon", "account", "kind"], dict: &rootObject)
            changed = true
        }

        if changed {
            try file.overlay(with: Self.encodeJSONObject(rootObject))
        }

        return CodexAuthAccount(id: id, name: name, createdAt: createdAt, relativeAuthPath: relativeAuthPath)
    }

    private nonisolated func safeFileDates(for file: STFile) -> (creationDate: Date, modificationDate: Date) {
        let fallback = Date()
        let values = try? file.url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let creationDate = values?.creationDate ?? values?.contentModificationDate ?? fallback
        let modificationDate = values?.contentModificationDate ?? values?.creationDate ?? fallback
        return (creationDate, modificationDate)
    }

    private func normalizeAccountPayloadData(
        authJSONString: String,
        preferredId: UUID,
        preferredCreatedAt: Date,
        relativeAuthPath: String
    ) throws -> Data {
        guard let data = authJSONString.data(using: .utf8),
              let rootJSON = try? JSON(data: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        setValue(preferredId.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
        removeValue(path: ["nolon", "account", "name"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: preferredCreatedAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: Date()), path: ["nolon", "account", "updatedAt"], dict: &rootObject)
        setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)

        if let derivedKind = deriveAccountKind(from: rootJSON) {
            setValue(derivedKind, path: ["nolon", "account", "kind"], dict: &rootObject)
        }
        if let email = deriveEmail(from: rootJSON) {
            if getString(rootObject, path: ["nolon", "account", "email"]) == nil {
                setValue(email, path: ["nolon", "account", "email"], dict: &rootObject)
            }
            if getString(rootObject, path: ["email"]) == nil {
                setValue(email, path: ["email"], dict: &rootObject)
            }
        }
        return try Self.encodeJSONObject(rootObject)
    }

    private func accountFromNormalizedPayloadData(_ data: Data, fallbackRelativeAuthPath: String) -> CodexAuthAccount {
        let rootObject = Self.decodeJSONObject(from: data) ?? [:]
        let id = getString(rootObject, path: ["nolon", "account", "id"]).flatMap(UUID.init(uuidString:)) ?? UUID()
        let trimmedRelativePath = getString(rootObject, path: ["nolon", "account", "relativeAuthPath"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let relativePath = (trimmedRelativePath?.isEmpty == false ? trimmedRelativePath : nil) ?? fallbackRelativeAuthPath
        let createdAt = getString(rootObject, path: ["nolon", "account", "createdAt"])
            .flatMap { Self.makeISOFormatter().date(from: $0) } ?? Date()
        let fallbackFileStem = URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
        let summary = CodexAuthSummary.fromJSONData(data)
        let name = summary.preferredDisplayName(fallbackFileStem: fallbackFileStem)
        return CodexAuthAccount(id: id, name: name, createdAt: createdAt, relativeAuthPath: relativePath)
    }

    private func readAccountAuthData(_ account: CodexAuthAccount) throws -> Data {
        if let data = try loadCodexAccountAuthDataFromSQLite(accountID: account.id), !data.isEmpty {
            return data
        }
        let file = accountAuthFile(account)
        if file.isExists {
            return try file.data()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func saveAccountAuthData(_ account: CodexAuthAccount, data: Data) throws {
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let normalized = try normalizeAccountPayloadData(
            authJSONString: raw,
            preferredId: account.id,
            preferredCreatedAt: account.createdAt,
            relativeAuthPath: account.relativeAuthPath
        )
        let reloaded = accountFromNormalizedPayloadData(normalized, fallbackRelativeAuthPath: account.relativeAuthPath)
        try upsertCodexAccountInSQLite(reloaded, authData: normalized)
    }

    func healDuplicateAccountIDsIfNeeded(_ accounts: [CodexAuthAccount]) throws -> [CodexAuthAccount] {
        // SQLite primary key already guarantees account id uniqueness.
        return accounts
    }

    func pruneDuplicateSnapshotPayloadsIfNeeded(_ accounts: [CodexAuthAccount]) throws -> [CodexAuthAccount] {
        guard accounts.count > 1 else { return accounts }

        let snapshots = loadAccountSnapshots(for: accounts)
        guard snapshots.count > 1 else { return accounts }

        var grouped: [String: [AccountSnapshot]] = [:]
        grouped.reserveCapacity(snapshots.count)
        for snapshot in snapshots {
            let key = cleanedHashHex(for: snapshot.cleanedData)
            grouped[key, default: []].append(snapshot)
        }

        let activeMap = loadActiveAccountMap()
        let activeIDs = Set(activeMap.values.compactMap(UUID.init(uuidString:)))
        var removedIDs = Set<UUID>()
        var replacementByRemovedID: [UUID: UUID] = [:]

        for group in grouped.values where group.count > 1 {
            let ordered = group.sorted { lhs, rhs in
                let lhsActive = activeIDs.contains(lhs.account.id)
                let rhsActive = activeIDs.contains(rhs.account.id)
                if lhsActive != rhsActive {
                    return lhsActive && !rhsActive
                }
                if lhs.account.createdAt != rhs.account.createdAt {
                    return lhs.account.createdAt < rhs.account.createdAt
                }
                return lhs.account.relativeAuthPath < rhs.account.relativeAuthPath
            }

            guard let keeper = ordered.first else { continue }
            for duplicate in ordered.dropFirst() {
                try removeCodexAccountFromSQLite(id: duplicate.account.id)
                removedIDs.insert(duplicate.account.id)
                replacementByRemovedID[duplicate.account.id] = keeper.account.id
                Self.logger.warning(
                    "Removed duplicate Codex snapshot payload. removed=\(duplicate.account.relativeAuthPath, privacy: .public) kept=\(keeper.account.relativeAuthPath, privacy: .public)"
                )
            }
        }

        guard !removedIDs.isEmpty else { return accounts }

        var nextMap = activeMap
        var mapChanged = false
        for (providerID, rawID) in activeMap {
            guard let id = UUID(uuidString: rawID) else { continue }
            if let replacement = replacementByRemovedID[id] {
                nextMap[providerID] = replacement.uuidString
                mapChanged = true
            } else if removedIDs.contains(id) {
                nextMap.removeValue(forKey: providerID)
                mapChanged = true
            }
        }
        if mapChanged {
            try saveActiveAccountMap(nextMap)
        }

        return accounts.filter { !removedIDs.contains($0.id) }
    }

    func alignSnapshotFileNamesWithEmailIfNeeded(_ accounts: [CodexAuthAccount]) throws -> [CodexAuthAccount] {
        // Snapshot file names are no longer source-of-truth after moving to SQLite.
        return accounts
    }

    func writeAccountFile(
        file: STFile,
        relativeAuthPath: String,
        authJSONString: String,
        preferredId: UUID,
        preferredCreatedAt: Date
    ) throws {
        guard let data = authJSONString.data(using: .utf8),
              let rootJSON = try? JSON(data: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var rootObject = rootJSON.dictionaryObject ?? [:]

        setValue(preferredId.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
        removeValue(path: ["nolon", "account", "name"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: preferredCreatedAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: Date()), path: ["nolon", "account", "updatedAt"], dict: &rootObject)
        setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)

        if let derivedKind = deriveAccountKind(from: rootJSON) {
            setValue(derivedKind, path: ["nolon", "account", "kind"], dict: &rootObject)
        }

        if let email = deriveEmail(from: rootJSON) {
            if getString(rootObject, path: ["nolon", "account", "email"]) == nil {
                setValue(email, path: ["nolon", "account", "email"], dict: &rootObject)
            }
            if getString(rootObject, path: ["email"]) == nil {
                setValue(email, path: ["email"], dict: &rootObject)
            }
        }

        try file.overlay(with: Self.encodeJSONObject(rootObject))
    }

    func migrateLegacyIndexFileIfNeeded() throws {
        let rootFolder = nolonCodexRootFolder()
        let candidates = [
            rootFolder.file("account.json"),
            rootFolder.file("accounts.json"),
        ]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in candidates where file.isExists {
            let data = (try? file.data()) ?? Data()
            guard !data.isEmpty else {
                try? file.delete()
                continue
            }

            guard let accounts = try? decoder.decode([CodexAuthAccount].self, from: data) else {
                try? file.delete()
                continue
            }

            for account in accounts {
                let authFile = accountAuthFile(relativeAuthPath: account.relativeAuthPath)
                guard authFile.isExists else { continue }
                do {
                    try ensureAccountMetadata(
                        for: authFile,
                        relativeAuthPath: account.relativeAuthPath,
                        preferredId: account.id,
                        preferredCreatedAt: account.createdAt
                    )
                } catch {
                    Self.logger.error("Failed to migrate Codex account index entry: \(account.relativeAuthPath, privacy: .public) error: \(String(describing: error), privacy: .public)")
                }
            }

            try? file.delete()
        }
    }

    func ensureAccountMetadata(
        for file: STFile,
        relativeAuthPath: String,
        preferredId: UUID,
        preferredCreatedAt: Date
    ) throws {
        let data = try file.data()
        guard let rootJSON = try? JSON(data: data) else { return }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        var changed = false

        if getString(rootObject, path: ["nolon", "account", "id"]) == nil {
            setValue(preferredId.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "name"]) != nil {
            removeValue(path: ["nolon", "account", "name"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "createdAt"]) == nil {
            setValue(Self.makeISOFormatter().string(from: preferredCreatedAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "updatedAt"]) == nil {
            setValue(Self.makeISOFormatter().string(from: preferredCreatedAt), path: ["nolon", "account", "updatedAt"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "relativeAuthPath"]) == nil {
            setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "kind"]) == nil,
           let derivedKind = deriveAccountKind(from: rootJSON)
        {
            setValue(derivedKind, path: ["nolon", "account", "kind"], dict: &rootObject)
            changed = true
        }

        if let email = deriveEmail(from: rootJSON) {
            if getString(rootObject, path: ["nolon", "account", "email"]) == nil {
                setValue(email, path: ["nolon", "account", "email"], dict: &rootObject)
                changed = true
            }
            if getString(rootObject, path: ["email"]) == nil {
                setValue(email, path: ["email"], dict: &rootObject)
                changed = true
            }
        }

        if changed {
            try file.overlay(with: Self.encodeJSONObject(rootObject))
        }
    }

    nonisolated func deriveEmail(from authJSON: JSON) -> String? {
        let trimmed: (String?) -> String? = { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }

        return trimmed(authJSON["email"].string)
            ?? trimmed(authJSON["user"]["email"].string)
            ?? trimmed(authJSON["nolon"]["account"]["email"].string)
    }

    private func makeConfiguredAccountPayload(
        name: String,
        apiKey: String,
        relay: ConfiguredRelay?,
        usageQuery: CodexHTTPUsageQuery?,
        preferredId: UUID,
        relativeAuthPath: String,
        createdAt: Date,
        updatedAt: Date,
        existingRootObject: JSONObject? = nil
    ) throws -> Data {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }

        var rootObject: JSONObject = existingRootObject ?? [:]
        rootObject["auth_mode"] = "apikey"
        rootObject["OPENAI_API_KEY"] = trimmedAPIKey
        rootObject["tokens"] = NSNull()
        rootObject["last_refresh"] = NSNull()

        setValue(preferredId.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
        setValue(relay == nil ? "officialAPIKey" : "relayProfile", path: ["nolon", "account", "kind"], dict: &rootObject)
        removeValue(path: ["nolon", "account", "name"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: createdAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: updatedAt), path: ["nolon", "account", "updatedAt"], dict: &rootObject)
        setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)

        if let relay {
            var relayObject: JSONObject = [
                "base_url": relay.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                "model_provider": relay.modelProvider.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            if !relay.queryParams.isEmpty {
                relayObject["query_params"] = relay.queryParams
            }
            if !relay.headers.isEmpty {
                relayObject["headers"] = relay.headers
            }
            setValue(relayObject, path: ["nolon", "relay"], dict: &rootObject)
        } else {
            removeValue(path: ["nolon", "relay"], dict: &rootObject)
        }

        if let usageQuery {
            setValue(try encodeJSONObjectObject(usageQuery), path: ["nolon", "usage_query"], dict: &rootObject)
        } else {
            removeValue(path: ["nolon", "usage_query"], dict: &rootObject)
        }

        return try Self.encodeJSONObject(rootObject)
    }

    private func sanitizedConfiguredAccountName(name: String, relay: ConfiguredRelay?) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let relay {
            let modelProvider = relay.modelProvider.trimmingCharacters(in: .whitespacesAndNewlines)
            if !modelProvider.isEmpty {
                return modelProvider
            }
            if let host = URL(string: relay.baseURL)?.host, !host.isEmpty {
                return host
            }
        }
        return "OpenAI Direct"
    }

    private func deriveAccountKind(from authJSON: JSON) -> String? {
        if let explicit = authJSON["nolon"]["account"]["kind"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty
        {
            return explicit
        }

        let authMode = Self.canonicalAuthMode(
            authJSON["auth_mode"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if authMode == "apikey" {
            return authJSON["nolon"]["relay"] != JSON.null ? "relayProfile" : "officialAPIKey"
        }
        if authMode == Self.canonicalChatGPTAuthMode {
            return "chatgptAccount"
        }
        return nil
    }
}

extension CodexAuthManager {
    public func validateImportAuthFiles(urls: [URL]) async -> [CodexImportValidationResult] {
        var results: [CodexImportValidationResult] = []
        results.reserveCapacity(urls.count)
        for url in urls {
            do {
                let candidates = try importCandidates(for: url)
                guard !candidates.isEmpty else {
                    results.append(
                        CodexImportValidationResult(
                            fileURL: url,
                            sourceGroupID: url.standardizedFileURL.path,
                            sourceGroupLabel: url.lastPathComponent,
                            isValid: false,
                            reason: "No auth JSON files found in archive",
                            suggestedName: nil,
                            email: nil,
                            authJSONString: nil
                        )
                    )
                    continue
                }
                for (candidateURL, sourceGroupID, sourceGroupLabel, data) in candidates {
                    var normalizedData = Self.normalizeImportedAuthJSONDataIfNeeded(data) ?? data
                    let enrichment = await enrichImportedAuthDataIfNeeded(normalizedData)
                    normalizedData = enrichment.data
                    guard let raw = String(data: normalizedData, encoding: .utf8) else {
                        results.append(
                            CodexImportValidationResult(
                                fileURL: candidateURL,
                                sourceGroupID: sourceGroupID,
                                sourceGroupLabel: sourceGroupLabel,
                                isValid: false,
                                reason: "Invalid UTF-8",
                                suggestedName: nil,
                                email: nil,
                                authJSONString: nil
                            )
                        )
                        continue
                    }
                    if let json = try? JSON(data: normalizedData) {
                        let type = json["type"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let type, !type.isEmpty, type.lowercased() != "codex" {
                            results.append(
                                CodexImportValidationResult(
                                    fileURL: candidateURL,
                                    sourceGroupID: sourceGroupID,
                                    sourceGroupLabel: sourceGroupLabel,
                                    isValid: false,
                                    reason: "Unsupported auth type: \(type)",
                                    suggestedName: nil,
                                    email: nil,
                                    authJSONString: nil
                                )
                            )
                            continue
                        }
                        if case let .invalid(reason) = credentialIdentityValidationResult(from: json) {
                            results.append(
                                CodexImportValidationResult(
                                    fileURL: candidateURL,
                                    sourceGroupID: sourceGroupID,
                                    sourceGroupLabel: sourceGroupLabel,
                                    isValid: false,
                                    reason: reason,
                                    suggestedName: nil,
                                    email: nil,
                                    authJSONString: nil
                                )
                            )
                            continue
                        }
                    }
                    guard hasImportableCredentials(authJSONString: raw) else {
                        var failureReason = enrichment.failureReason ?? "Missing required credentials"
                        if let parsed = try? JSON(data: normalizedData),
                           case let .invalid(reason) = credentialIdentityValidationResult(from: parsed)
                        {
                            failureReason = reason
                        }
                        results.append(
                            CodexImportValidationResult(
                                fileURL: candidateURL,
                                sourceGroupID: sourceGroupID,
                                sourceGroupLabel: sourceGroupLabel,
                                isValid: false,
                                reason: failureReason,
                                suggestedName: nil,
                                email: nil,
                                authJSONString: nil
                            )
                        )
                        continue
                    }
                    results.append(
                        CodexImportValidationResult(
                            fileURL: candidateURL,
                            sourceGroupID: sourceGroupID,
                            sourceGroupLabel: sourceGroupLabel,
                            isValid: true,
                            reason: nil,
                            suggestedName: deriveAccountName(fromAuthJSONString: raw),
                            email: deriveEmail(fromAuthJSONString: raw),
                            authJSONString: raw
                        )
                    )
                }
            } catch {
                results.append(
                    CodexImportValidationResult(
                        fileURL: url,
                        sourceGroupID: url.standardizedFileURL.path,
                        sourceGroupLabel: url.lastPathComponent,
                        isValid: false,
                        reason: error.localizedDescription,
                        suggestedName: nil,
                        email: nil,
                        authJSONString: nil
                    )
                )
            }
        }
        return results
    }

    @discardableResult
    public func importValidatedAuthFiles(
        results: [CodexImportValidationResult],
        destination: ImportDestination = .managedSnapshots
    ) async throws -> [CodexAuthAccount] {
        switch destination {
        case .managedSnapshots:
            var imported: [CodexAuthAccount] = []
            for result in results where result.isValid {
                guard let raw = result.authJSONString else { continue }
                let finalName = result.suggestedName ?? deriveAccountName(fromAuthJSONString: raw)
                let account = try await addAccount(name: finalName, authJSONString: raw)
                imported.append(account)
            }
            return imported
        case let .customSQLiteGroup(name):
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw CocoaError(.validationMissingMandatoryProperty, userInfo: [
                    NSLocalizedDescriptionKey: "Custom import group name is required.",
                ])
            }
            var imported: [CodexAuthAccount] = []
            for result in results where result.isValid {
                guard let raw = result.authJSONString else { continue }
                let finalName = result.suggestedName ?? deriveAccountName(fromAuthJSONString: raw)
                let account = try await addAccount(name: finalName, authJSONString: raw)
                try setCustomSQLiteGroup(trimmedName, for: account.id)
                imported.append(account)
            }
            try await persistValidatedImportsToSQLiteGroup(results: results, groupName: trimmedName)
            return imported
        }
    }

    private func importCandidates(for url: URL) throws -> [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] {
        try CodexAuthManagerSupport.importCandidates(for: url).map {
            ($0.candidateURL, $0.sourceGroupID, $0.sourceGroupLabel, $0.data)
        }
    }

    private struct ImportEnrichmentResult {
        let data: Data
        let failureReason: String?
    }

    private func enrichImportedAuthDataIfNeeded(_ data: Data) async -> ImportEnrichmentResult {
        guard var root = Self.decodeJSONObject(from: data) else {
            return ImportEnrichmentResult(data: data, failureReason: nil)
        }

        var changed = false
        var failureReason: String?
        var tokens = (root["tokens"] as? JSONObject) ?? [:]

        let idTokenBefore = firstNonEmptyString(in: root, keys: ["tokens.id_token", "tokens.idToken", "id_token", "idToken"])
        let accessTokenBefore = firstNonEmptyString(in: root, keys: ["tokens.access_token", "tokens.accessToken", "access_token", "accessToken"])
        let refreshToken = firstNonEmptyString(in: root, keys: ["tokens.refresh_token", "tokens.refreshToken", "refresh_token", "refreshToken"])

        // Compatibility for legacy Codex exports where `access_token` carries JWT claims while `id_token` is empty.
        if idTokenBefore == nil,
           let accessTokenBefore,
           CodexAuthSummary.decodeJWTPayloadJSON(accessTokenBefore) != nil
        {
            tokens["id_token"] = accessTokenBefore
            changed = true
        }

        if (idTokenBefore == nil || accessTokenBefore == nil), let refreshToken {
            do {
                let refreshed = try await refreshCodexTokenAction(refreshToken)
                tokens["id_token"] = refreshed.idToken
                tokens["access_token"] = refreshed.accessToken
                if let refreshedToken = refreshed.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines), !refreshedToken.isEmpty {
                    tokens["refresh_token"] = refreshedToken
                } else if tokens["refresh_token"] == nil {
                    tokens["refresh_token"] = refreshToken
                }
                if let expiresIn = refreshed.expiresIn, expiresIn > 0 {
                    let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
                    root["expires_at"] = Self.makeISOFormatter().string(from: expiresAt)
                }
                changed = true
            } catch {
                failureReason = "Token refresh failed: \(error.localizedDescription)"
            }
        }

        let idToken = firstNonEmptyString(in: tokens, keys: ["id_token", "idToken"])
            ?? firstNonEmptyString(in: root, keys: ["id_token", "idToken"])
        let payload = idToken.flatMap(CodexAuthSummary.decodeJWTPayloadJSON)
        let rootJSON: JSON = {
            guard let rootData = try? Self.encodeJSONObject(root) else { return JSON.null }
            return (try? JSON(data: rootData)) ?? .null
        }()
        let accountID = CodexAuthSummary.canonicalAccountID(json: rootJSON, payload: payload)
        if let accountID {
            if firstNonEmptyString(in: tokens, keys: ["account_id", "accountId"]) == nil {
                tokens["account_id"] = accountID
                changed = true
            }
            if firstNonEmptyString(in: root, keys: ["chatgpt_account_id", "chatgptAccountId", "account_id", "accountId"]) == nil {
                root["chatgpt_account_id"] = accountID
                changed = true
            }
        }

        if let derivedEmail = deriveEmail(from: rootJSON) ?? firstNonEmptyString(in: payload, paths: [["email"], ["https://api.openai.com/auth", "email"], ["auth", "email"]]),
           firstNonEmptyString(in: root, keys: ["email", "user.email", "nolon.account.email"]) == nil
        {
            root["email"] = derivedEmail
            changed = true
        }

        let derivedPlanType = firstNonEmptyString(in: root, keys: ["plan_type", "planType", "plan", "subscription.plan", "account.plan"])
            ?? firstNonEmptyString(in: payload, paths: [["https://api.openai.com/auth", "chatgpt_plan_type"], ["auth", "chatgpt_plan_type"], ["plan"]])
        if let derivedPlanType {
            if firstNonEmptyString(in: root, keys: ["plan_type", "planType"]) == nil {
                root["plan_type"] = derivedPlanType
                changed = true
            }
            if firstNonEmptyString(in: root, keys: ["plan", "subscription.plan", "account.plan"]) == nil {
                root["plan"] = derivedPlanType
                changed = true
            }
        }

        let hasOAuthTokenPair = firstNonEmptyString(in: tokens, keys: ["id_token", "idToken"]) != nil
            && firstNonEmptyString(in: tokens, keys: ["access_token", "accessToken"]) != nil
        if hasOAuthTokenPair, firstNonEmptyString(in: root, keys: ["auth_mode"]) == nil {
            root["auth_mode"] = Self.canonicalChatGPTAuthMode
            changed = true
        }

        let accessToken = firstNonEmptyString(in: tokens, keys: ["access_token", "accessToken"])
            ?? firstNonEmptyString(in: root, keys: ["access_token", "accessToken"])
        if let accessToken {
            do {
                if let fetched = try await fetchCodexAccountInfoAction(accessToken) {
                    if let fetchedEmail = fetched.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fetchedEmail.isEmpty,
                       firstNonEmptyString(in: root, keys: ["email", "user.email", "nolon.account.email"]) == nil
                    {
                        root["email"] = fetchedEmail
                        changed = true
                    }
                    if let fetchedAccountID = fetched.accountID?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fetchedAccountID.isEmpty
                    {
                        if firstNonEmptyString(in: tokens, keys: ["account_id", "accountId"]) == nil {
                            tokens["account_id"] = fetchedAccountID
                            changed = true
                        }
                        if firstNonEmptyString(in: root, keys: ["chatgpt_account_id", "chatgptAccountId", "account_id", "accountId"]) == nil {
                            root["chatgpt_account_id"] = fetchedAccountID
                            changed = true
                        }
                    }
                    if let fetchedPlan = fetched.planType?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !fetchedPlan.isEmpty
                    {
                        if firstNonEmptyString(in: root, keys: ["plan_type", "planType"]) == nil {
                            root["plan_type"] = fetchedPlan
                            changed = true
                        }
                        if firstNonEmptyString(in: root, keys: ["plan", "subscription.plan", "account.plan"]) == nil {
                            root["plan"] = fetchedPlan
                            changed = true
                        }
                    }
                }
            } catch {
                // Ignore resource fetch failures and keep local/JWT-derived enrichment as fallback.
            }
        }

        if changed {
            root["tokens"] = tokens
            if let encoded = try? Self.encodeJSONObject(root) {
                return ImportEnrichmentResult(data: encoded, failureReason: failureReason)
            }
        }
        return ImportEnrichmentResult(data: data, failureReason: failureReason)
    }

    nonisolated private static func defaultRefreshCodexOAuthTokens(refreshToken: String) async throws -> RefreshedOAuthTokens {
        try await CodexAuthManagerSupport.refreshOAuthTokens(refreshToken: refreshToken)
    }

    nonisolated private static func defaultFetchCodexOAuthAccountInfo(accessToken: String) async throws -> FetchedOAuthAccountInfo? {
        try await CodexAuthManagerSupport.fetchOAuthAccountInfo(accessToken: accessToken)
    }

    private func firstNonEmptyString(in object: JSONObject, keys: [String]) -> String? {
        CodexAuthManagerSupport.firstNonEmptyString(in: object, keys: keys)
    }

    private func runDitto(arguments: [String]) throws {
        try CodexAuthManagerSupport.runDitto(arguments: arguments)
    }
}

private extension CodexAuthManager {
    private func withAuthFileLock<T>(_ body: () throws -> T) throws -> T {
        let lockFile = nolonCodexRootFolder().file(PathName.authLockFile.rawValue)
        _ = lockFile.parentFolder()?.createIfNotExists()
        if !lockFile.isExists {
            _ = try? lockFile.overlay(with: Data())
        }

        let fd = open(lockFile.url.path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { _ = close(fd) }

        guard flock(fd, LOCK_EX) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { _ = flock(fd, LOCK_UN) }
        return try body()
    }

    private func removeFileOrSymlinkIfPresent(_ file: STFile) throws {
        do {
            try FileManager.default.removeItem(at: file.url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return
        }
    }

    @discardableResult
    private func reconcileProviderAuthWithSnapshotsIfNeeded(for provider: Provider) throws -> CodexAuthAccount? {
        guard Self.isCodexTemplate(provider.templateId),
              let providerAuthFile = authFile(for: provider)
        else { return nil }

        let snapshots = try loadAccountsFromAuthFolder()

        if !providerAuthFile.isExists {
            if let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots),
               let active = snapshots.first(where: { $0.id == activeID }) {
                try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: active, provider: provider)
                return active
            }
            if let expectedHash = loadActiveFingerprintMap()[provider.id] {
                for snapshot in snapshots {
                    guard let data = try? readAccountAuthData(snapshot), !data.isEmpty else { continue }
                    if cleanedHashHex(for: data) == expectedHash {
                        try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: snapshot, provider: provider)
                        return snapshot
                    }
                }
            }
            if snapshots.count == 1, let lone = snapshots.first {
                try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: lone, provider: provider)
                return lone
            }
            return nil
        }

        if providerAuthFile.isSymbolicLink {
            if let destination = resolveSymlinkTarget(for: providerAuthFile) {
                if let destinationData = try? Data(contentsOf: destination.url),
                   let linked = matchAccount(authData: destinationData, accounts: snapshots) {
                    let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots)
                    if activeID != linked.id {
                        try setActiveAccount(linked, for: provider)
                        return linked
                    }
                    return nil
                }
                let standardizedDestination = standardizedPathString(destination)
                if let gatewayVirtual = loadGatewayVirtualAccount(byStandardizedPath: standardizedDestination) {
                    let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots)
                    if activeID != gatewayVirtual.id {
                        try setActiveAccount(gatewayVirtual, for: provider)
                        return gatewayVirtual
                    }
                    return nil
                }
            }
            if let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots),
               let active = snapshots.first(where: { $0.id == activeID }) {
                try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: active, provider: provider)
                return active
            }
            return nil
        }

        let providerData = (try? providerAuthFile.data()) ?? Data()
        let providerRaw = String(data: providerData, encoding: .utf8)
        let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots)
        let activeAccount = activeID.flatMap { id in snapshots.first(where: { $0.id == id }) }
        let preferred = resolvePreferredSourceCandidate(
            providerAuthData: providerData,
            providerAuthRaw: providerRaw,
            snapshots: snapshots,
            activeAccount: activeAccount
        )

        let resolved: CodexAuthAccount
        switch preferred.source {
        case .provider:
            guard let candidate = try? upsertSnapshotFromProviderData(
                authData: providerData,
                providerRaw: providerRaw,
                snapshots: snapshots,
                excludedAccountID: nil
            ) else {
                Self.logger.warning(
                    "Codex preflight skipped non-importable provider auth payload. provider=\(provider.id, privacy: .public)"
                )
                return nil
            }
            resolved = candidate
        case .snapshot:
            guard let account = preferred.account else {
                guard let candidate = try? upsertSnapshotFromProviderData(
                    authData: providerData,
                    providerRaw: providerRaw,
                    snapshots: snapshots,
                    excludedAccountID: nil
                ) else {
                    Self.logger.warning(
                        "Codex preflight skipped fallback upsert due to non-importable payload. provider=\(provider.id, privacy: .public)"
                    )
                    return nil
                }
                resolved = candidate
                break
            }
            resolved = account
        }

        try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: resolved, provider: provider)
        Self.logger.info(
            "Codex preflight reconciled detached provider auth. provider=\(provider.id, privacy: .public) source=\(preferred.source.rawValue, privacy: .public) score=\(preferred.score, privacy: .public)"
        )
        return resolved
    }

    private func relinkProviderAuth(providerAuthFile: STFile, resolved: CodexAuthAccount, provider: Provider) throws {
        try removeFileOrSymlinkIfPresent(providerAuthFile)
        let managedAuthFile = try materializeManagedActiveAuthFile(for: resolved, provider: provider)
        try FileManager.default.createSymbolicLink(
            atPath: providerAuthFile.url.path,
            withDestinationPath: managedAuthFile.url.path
        )
        try setActiveAccount(resolved, for: provider)
    }

    private func resolvePreferredSourceCandidate(
        providerAuthData: Data,
        providerAuthRaw: String?,
        snapshots: [CodexAuthAccount],
        activeAccount: CodexAuthAccount?
    ) -> AuthSourceCandidate {
        let providerSummary = CodexAuthSummary.fromJSONData(providerAuthData)
        let providerCandidate = AuthSourceCandidate(
            source: .provider,
            account: nil,
            data: providerAuthData,
            rawJSONString: providerAuthRaw,
            summary: providerSummary,
            score: scoreCandidate(
                summary: providerSummary,
                data: providerAuthData,
                rawJSONString: providerAuthRaw,
                preferredRecentSuccess: nil
            )
        )

        var snapshotCandidates: [AuthSourceCandidate] = []
        var seen = Set<UUID>()

        if let matched = matchAccount(authData: providerAuthData, accounts: snapshots),
           let candidate = makeSnapshotCandidate(matched),
           seen.insert(matched.id).inserted {
            snapshotCandidates.append(candidate)
        }

        if let activeAccount,
           let candidate = makeSnapshotCandidate(activeAccount),
           seen.insert(activeAccount.id).inserted {
            snapshotCandidates.append(candidate)
        }

        let bestSnapshot = snapshotCandidates.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.account?.createdAt ?? .distantPast < rhs.account?.createdAt ?? .distantPast
            }
            return lhs.score < rhs.score
        })

        guard let bestSnapshot else { return providerCandidate }
        if bestSnapshot.score > providerCandidate.score {
            return bestSnapshot
        }
        return providerCandidate
    }

    private func makeSnapshotCandidate(_ account: CodexAuthAccount) -> AuthSourceCandidate? {
        guard let data = try? readAccountAuthData(account), !data.isEmpty else { return nil }
        let summary = CodexAuthSummary.fromJSONData(data)
        let raw = String(data: data, encoding: .utf8)
        let score = scoreCandidate(
            summary: summary,
            data: data,
            rawJSONString: raw,
            preferredRecentSuccess: summary.lastSyncSucceededAt
        )
        return AuthSourceCandidate(
            source: .snapshot,
            account: account,
            data: data,
            rawJSONString: raw,
            summary: summary,
            score: score
        )
    }

    private func scoreCandidate(
        summary: CodexAuthSummary,
        data: Data,
        rawJSONString: String?,
        preferredRecentSuccess: Date?
    ) -> Int {
        var score = 0
        if !data.isEmpty { score += 1 }
        if Self.decodeJSONObject(from: data) != nil { score += 2 } else { score -= 6 }
        if let rawJSONString, hasImportableCredentials(authJSONString: rawJSONString) {
            score += 6
        }
        if normalizedEmail(summary.email) != nil { score += 4 }
        if let accountID = normalizedAccountID(summary.accountID),
           UUID(uuidString: accountID) == nil {
            score += 3
        }
        if summary.apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false { score += 2 }
        if preferredRecentSuccess != nil { score += 1 }
        return score
    }

    private func upsertSnapshotFromProviderData(
        authData: Data,
        providerRaw: String?,
        snapshots: [CodexAuthAccount],
        excludedAccountID: UUID?
    ) throws -> CodexAuthAccount {
        guard !authData.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let raw: String
        if let providerRaw, !providerRaw.isEmpty {
            raw = providerRaw
        } else if let converted = String(data: authData, encoding: .utf8), !converted.isEmpty {
            raw = converted
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        guard !isGatewayVirtualAuthPayload(authData),
              hasImportableCredentials(authJSONString: raw)
        else {
            if let matched = matchAccount(authData: authData, accounts: snapshots),
               matched.id != excludedAccountID {
                return matched
            }
            throw CocoaError(.validationMissingMandatoryProperty)
        }

        let authSummary = CodexAuthSummary.fromJSONData(authData)
        let authIdentity = accountIdentity(from: authData, summary: authSummary)
        if let strictMatch = matchAccountByStrictIdentity(
            authIdentity: authIdentity,
            snapshots: loadAccountSnapshots(for: snapshots),
            excludedAccountID: excludedAccountID
        ) {
            let normalized = try normalizeAccountPayloadData(
                authJSONString: raw,
                preferredId: strictMatch.id,
                preferredCreatedAt: strictMatch.createdAt,
                relativeAuthPath: strictMatch.relativeAuthPath
            )
            try saveAccountAuthData(strictMatch, data: normalized)
            return accountFromNormalizedPayloadData(normalized, fallbackRelativeAuthPath: strictMatch.relativeAuthPath)
        }

        if let matched = matchAccount(authData: authData, accounts: snapshots),
           matched.id != excludedAccountID {
            let normalized = try normalizeAccountPayloadData(
                authJSONString: raw,
                preferredId: matched.id,
                preferredCreatedAt: matched.createdAt,
                relativeAuthPath: matched.relativeAuthPath
            )
            try saveAccountAuthData(matched, data: normalized)
            return accountFromNormalizedPayloadData(normalized, fallbackRelativeAuthPath: matched.relativeAuthPath)
        }
        return try createSnapshotAccount(authJSONString: raw)
    }

    @discardableResult
    private func reconcileActiveSymlinkDriftIfNeeded(for provider: Provider) throws -> CodexAuthAccount? {
        guard Self.isCodexTemplate(provider.templateId),
              let providerAuthFile = authFile(for: provider),
              providerAuthFile.isExists,
              providerAuthFile.isSymbolicLink
        else { return nil }

        let accounts = try loadAccountsFromAuthFolder()
        let linkedAccount: CodexAuthAccount? = {
            guard let destination = resolveSymlinkTarget(for: providerAuthFile) else { return nil }
            guard let destinationData = try? Data(contentsOf: destination.url) else { return nil }
            return matchAccount(authData: destinationData, accounts: accounts)
        }()

        let registryActiveID = activeAccountIdFromRegistry(for: provider, accounts: accounts)
        let resolvedActive: CodexAuthAccount? = {
            if let registryActiveID,
               let account = accounts.first(where: { $0.id == registryActiveID }) {
                return account
            }
            return linkedAccount
        }()
        guard let activeAccount = resolvedActive else { return nil }
        if registryActiveID != activeAccount.id {
            try setActiveAccount(activeAccount, for: provider)
        }

        guard let activeData = try? readAccountAuthData(activeAccount), !activeData.isEmpty else { return nil }

        let currentHash = cleanedHashHex(for: activeData)
        var fingerprints = loadActiveFingerprintMap()
        if isGatewayVirtualAccount(activeAccount) {
            if fingerprints[provider.id] != currentHash {
                fingerprints[provider.id] = currentHash
                try saveActiveFingerprintMap(fingerprints)
            }
            return nil
        }
        guard let previousHash = fingerprints[provider.id] else {
            fingerprints[provider.id] = currentHash
            try saveActiveFingerprintMap(fingerprints)
            return nil
        }

        guard previousHash != currentHash else { return nil }

        guard let backupFile = latestBackup(for: provider, accountID: activeAccount.id, expectedHash: previousHash),
              let backupData = try? backupFile.data(),
              !backupData.isEmpty
        else {
            fingerprints[provider.id] = currentHash
            try saveActiveFingerprintMap(fingerprints)
            Self.logger.warning(
                "Codex active drift detected without valid backup; accept new fingerprint. provider=\(provider.id, privacy: .public) account=\(activeAccount.id.uuidString, privacy: .public)"
            )
            return nil
        }

        if isSameIdentity(backupData, activeData) {
            fingerprints[provider.id] = currentHash
            try saveActiveFingerprintMap(fingerprints)
            return nil
        }

        // External CLI switched account through active symlink:
        // restore original active snapshot from backup,
        // then place drifted auth payload into matched/new snapshot.
        try saveAccountAuthData(activeAccount, data: backupData)
        let restoredAccount = accountFromNormalizedPayloadData(backupData, fallbackRelativeAuthPath: activeAccount.relativeAuthPath)
        let refreshedSnapshots = try loadAccountsFromAuthFolder()
        let refreshedRestoredAccount = refreshedSnapshots.first(where: { $0.id == restoredAccount.id }) ?? restoredAccount
        _ = try upsertSnapshotFromProviderData(
            authData: activeData,
            providerRaw: String(data: activeData, encoding: .utf8),
            snapshots: refreshedSnapshots,
            excludedAccountID: refreshedRestoredAccount.id
        )
        try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: refreshedRestoredAccount, provider: provider)

        fingerprints[provider.id] = previousHash
        try saveActiveFingerprintMap(fingerprints)
        Self.logger.info(
            "Codex active snapshot restored from backup after external drift. provider=\(provider.id, privacy: .public) active=\(refreshedRestoredAccount.id.uuidString, privacy: .public)"
        )
        return refreshedRestoredAccount
    }

    private func isSameIdentity(_ lhsData: Data, _ rhsData: Data) -> Bool {
        let lhsSummary = CodexAuthSummary.fromJSONData(lhsData)
        let rhsSummary = CodexAuthSummary.fromJSONData(rhsData)
        let lhsIdentity = accountIdentity(from: lhsData, summary: lhsSummary)
        let rhsIdentity = accountIdentity(from: rhsData, summary: rhsSummary)

        if let leftAccountID = lhsIdentity.accountID,
           let rightAccountID = rhsIdentity.accountID
        {
            guard leftAccountID == rightAccountID else { return false }
            if let leftEmail = lhsIdentity.email,
               let rightEmail = rhsIdentity.email
            {
                return leftEmail == rightEmail
            }
            if lhsIdentity.email == nil, rhsIdentity.email == nil,
               let leftNolonID = lhsIdentity.nolonAccountID,
               let rightNolonID = rhsIdentity.nolonAccountID
            {
                return leftNolonID == rightNolonID
            }
            return false
        }

        if let leftEmail = lhsIdentity.email,
           let rightEmail = rhsIdentity.email
        {
            return leftEmail == rightEmail
        }
        return false
    }

    private func cleanedHashHex(for data: Data) -> String {
        let cleaned = Self.cleanedAuthJSONData(from: data) ?? data
        let digest = SHA256.hash(data: cleaned)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func persistActiveFingerprintIfNeeded(for provider: Provider) throws {
        guard Self.isCodexTemplate(provider.templateId) else { return }
        let accounts = try loadAccountsFromAuthFolder()
        var map = loadActiveFingerprintMap()
        guard let activeID = activeAccountIdFromRegistry(for: provider, accounts: accounts),
              let active = accounts.first(where: { $0.id == activeID })
        else {
            if map.removeValue(forKey: provider.id) != nil {
                try saveActiveFingerprintMap(map)
            }
            return
        }

        guard let data = try? readAccountAuthData(active), !data.isEmpty else { return }
        let hash = cleanedHashHex(for: data)
        if map[provider.id] != hash {
            map[provider.id] = hash
            try saveActiveFingerprintMap(map)
        }
    }

    private func loadActiveFingerprintMap() -> [String: String] {
        let file = activeFingerprintsFile()
        guard file.isExists,
              let data = try? file.data(),
              !data.isEmpty,
              let root = Self.decodeJSONObject(from: data),
              let providers = root["providers"] as? JSONObject
        else { return [:] }

        return providers.reduce(into: [String: String]()) { result, element in
            if let value = element.value as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result[element.key] = value
            }
        }
    }

    private func saveActiveFingerprintMap(_ map: [String: String]) throws {
        let file = activeFingerprintsFile()
        _ = file.parentFolder()?.createIfNotExists()
        let root: JSONObject = ["providers": map]
        try file.overlay(with: Self.encodeJSONObject(root))
    }

    private func backupActiveSnapshotIfNeeded(for provider: Provider, force: Bool, reason: String) throws {
        guard Self.isCodexTemplate(provider.templateId) else { return }
        let accounts = try loadAccountsFromAuthFolder()
        guard let activeID = activeAccountIdFromRegistry(for: provider, accounts: accounts),
              let active = accounts.first(where: { $0.id == activeID })
        else { return }

        guard let data = try? readAccountAuthData(active),
              !data.isEmpty
        else { return }

        let backupFolder = activeBackupFolder(for: provider)
        _ = backupFolder.createIfNotExists()
        guard shouldCreateBackup(for: backupFolder, accountID: active.id, force: force) else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(active.id.uuidString.lowercased())-\(timestamp).json"
        let backupFile = backupFolder.file(fileName)
        try backupFile.overlay(with: data)
        try cleanupBackupFiles(in: backupFolder)
        Self.logger.debug(
            "Codex active snapshot backup created. provider=\(provider.id, privacy: .public) account=\(active.id.uuidString, privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    private func shouldCreateBackup(for folder: STFolder, accountID: UUID, force: Bool) -> Bool {
        if force { return true }
        let files = (try? folder.files()) ?? []
        let prefix = accountID.uuidString.lowercased() + "-"
        let latest = files
            .filter { $0.attributes.name.hasPrefix(prefix) }
            .sorted(by: { $0.attributes.modificationDate > $1.attributes.modificationDate })
            .first
        guard let latest else { return true }
        return Date().timeIntervalSince(latest.attributes.modificationDate) >= 5 * 60
    }

    private func cleanupBackupFiles(in folder: STFolder) throws {
        let maxCount = 10
        let maxAge: TimeInterval = 30 * 24 * 60 * 60
        let now = Date()
        let files = ((try? folder.files()) ?? [])
            .filter { $0.attributes.nameComponents.extension?.lowercased() == "json" }
            .sorted(by: { $0.attributes.modificationDate > $1.attributes.modificationDate })

        for file in files where now.timeIntervalSince(file.attributes.modificationDate) > maxAge {
            try? file.delete()
        }

        let refreshed = ((try? folder.files()) ?? [])
            .filter { $0.attributes.nameComponents.extension?.lowercased() == "json" }
            .sorted(by: { $0.attributes.modificationDate > $1.attributes.modificationDate })
        if refreshed.count > maxCount {
            for file in refreshed.dropFirst(maxCount) {
                try? file.delete()
            }
        }
    }

    private func latestBackup(for provider: Provider, accountID: UUID, expectedHash: String?) -> STFile? {
        let folder = activeBackupFolder(for: provider)
        let allFiles = ((try? folder.files()) ?? [])
            .filter { $0.attributes.nameComponents.extension?.lowercased() == "json" }
            .sorted(by: { $0.attributes.modificationDate > $1.attributes.modificationDate })
        let files = allFiles
            .filter { $0.attributes.name.hasPrefix(accountID.uuidString.lowercased() + "-") }

        if let expectedHash {
            for file in files {
                guard let data = try? file.data(), !data.isEmpty else { continue }
                if cleanedHashHex(for: data) == expectedHash {
                    return file
                }
            }
            for file in allFiles {
                guard let data = try? file.data(), !data.isEmpty else { continue }
                if cleanedHashHex(for: data) == expectedHash {
                    return file
                }
            }
            return files.first ?? allFiles.first
        }

        return files.first ?? allFiles.first
    }

    private func activeBackupFolder(for provider: Provider) -> STFolder {
        nolonCodexRootFolder()
            .folder(PathName.backupsFolder.rawValue)
            .folder(PathName.activeBackupsFolder.rawValue)
            .folder(sanitizeFileStem(provider.id))
    }
}

extension CodexAuthManager {
    private func startProviderAuthPolling(for provider: Provider) {
        stopProviderAuthPolling(for: provider.id)
        guard let authFile = authFile(for: provider) else { return }
        let authFilePath = authFile.url.path
        if let raw = try? String(contentsOf: URL(fileURLWithPath: authFilePath), encoding: .utf8) {
            providerAuthLastHashes[provider.id] = CodexAuthAccount.hashHex(for: raw)
        }

        let providerID = provider.id
        let activeProviderKey = activeAccountProviderKey(for: provider)
        let task = Task { [providerID, activeProviderKey, authFilePath] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: providerAuthPollIntervalNanoseconds)
                await pollProviderAuthChange(
                    providerID: providerID,
                    activeProviderKey: activeProviderKey,
                    authFilePath: authFilePath
                )
            }
        }
        providerAuthPollingTasks[provider.id] = task
    }

    private func stopProviderAuthPolling(for providerID: String) {
        providerAuthPollingTasks[providerID]?.cancel()
        providerAuthPollingTasks[providerID] = nil
        providerAuthLastHashes[providerID] = nil
    }

    private func pollProviderAuthChange(providerID: String, activeProviderKey: String, authFilePath: String) async {
        let authURL = URL(fileURLWithPath: authFilePath)
        guard let data = try? Data(contentsOf: authURL),
              !data.isEmpty,
              let raw = String(data: data, encoding: .utf8)
        else {
            return
        }

        let newHash = CodexAuthAccount.hashHex(for: raw)
        if providerAuthLastHashes[providerID] == newHash {
            return
        }
        providerAuthLastHashes[providerID] = newHash

        let normalizedData = Self.normalizeImportedAuthJSONDataIfNeeded(data) ?? data
        guard let normalizedRaw = String(data: normalizedData, encoding: .utf8),
              hasImportableCredentials(authJSONString: normalizedRaw),
              let parsed = try? JSON(data: normalizedData)
        else {
            return
        }
        if case let .invalid(reason) = credentialIdentityValidationResult(from: parsed) {
            Self.logger.error("Provider auth polling ignored invalid identity combination. provider=\(providerID, privacy: .public) reason=\(reason, privacy: .public)")
            return
        }

        let activeMap = loadActiveAccountMap()
        let rawID = activeMap[activeProviderKey] ?? activeMap[providerID]
        guard let rawID,
              let activeID = UUID(uuidString: rawID),
              let account = (try? loadAccountsFromAuthFolder())?.first(where: { $0.id == activeID })
        else {
            return
        }

        do {
            let normalizedPayload = try normalizeAccountPayloadData(
                authJSONString: normalizedRaw,
                preferredId: account.id,
                preferredCreatedAt: account.createdAt,
                relativeAuthPath: account.relativeAuthPath
            )
            let reloaded = accountFromNormalizedPayloadData(normalizedPayload, fallbackRelativeAuthPath: account.relativeAuthPath)
            try upsertCodexAccountInSQLite(reloaded, authData: normalizedPayload)
        } catch {
            Self.logger.error("Provider auth polling failed to persist snapshot. provider=\(providerID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    private nonisolated func stableImportGroupID(for groupName: String) -> String {
        let normalized = groupName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let data = Data(normalized.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension CodexAuthManager {
    private struct SQLiteCodexAccountRow {
        let id: UUID
        let name: String
        let createdAt: Date
        let identityKey: String?
    }

    private nonisolated func codexAccountsSQLiteDatabaseURL() -> URL {
        accountsSQLiteFile().url
    }

    private func migrateAccountsStoreToSQLiteIfNeeded() throws {
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

    private func migrateActiveAccountProviderKeysIfNeeded() throws {
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

    private nonisolated func ensureCodexAccountsSQLiteSchema(databaseURL: URL) throws {
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

    private nonisolated func backfillCodexIdentityKeysIfNeeded(databaseURL: URL) throws {
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

    private func importSnapshotAccountsIntoSQLite() throws {
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

    private func importLegacyActiveAccountsFileIntoSQLiteIfNeeded() throws {
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

    private func loadCodexAccountsFromSQLite() throws -> [CodexAuthAccount] {
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

    private nonisolated func queryCodexAccountsRowsFromSQLite() throws -> [SQLiteCodexAccountRow] {
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

    private func upsertCodexAccountInSQLite(_ account: CodexAuthAccount, authData: Data? = nil) throws {
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

    private nonisolated func queryCodexAccountRowByIdentityKeyFromSQLite(
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

    private nonisolated func upsertCodexCredentialsInSQLite(
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
            ["base_url"], ["baseURL"],
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

    private nonisolated func upsertCodexAccountMetadataInSQLite(
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

        try executeSQLite(
            db,
            sql: """
            INSERT INTO codex_account_metadata (
                account_id, auth_mode, openai_api_key, tokens_account_id, expires_at, email, last_refresh,
                plan_type, custom_group_name, nolon_account_kind, nolon_account_email, nolon_account_last_login_at,
                nolon_account_last_sync_succeeded_at, nolon_account_last_sync_failed_at,
                nolon_account_last_sync_failure_message, usage_cache_json, usage_query_json, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                .text(updatedAtISO),
            ]
        )
    }

    private nonisolated func loadCodexAccountAuthDataFromSQLite(accountID: UUID) throws -> Data? {
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
            m.usage_query_json
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
        let legacyAuthJSON = hasLegacyAuthJSONColumn ? text(27) : nil

        let hasStructuredData = [
            idToken, accessToken, refreshToken, credentialAPIKey, baseURL, credentialEmail, credentialAccountID,
            authMode, metadataAPIKey, metadataAccountID, metadataEmail, metadataPlanType, customGroupName, kind, usageCacheJSON, usageQueryJSON,
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

        var nolonObject: JSONObject = ["account": nolonAccount]
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

    private func cleanupManagedSnapshotFilesIfNeeded() throws {
        let folder = nolonCodexAuthFolder()
        let fileNames = stableAuthSnapshotFileNames(in: folder)
        guard !fileNames.isEmpty else { return }
        for fileName in fileNames {
            let file = folder.file(fileName)
            try? file.delete()
        }
    }

    private func removeCodexAccountFromSQLite(id: UUID) throws {
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

    private nonisolated func loadActiveAccountMapFromSQLite() throws -> [String: String] {
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

    private func saveActiveAccountMapToSQLite(_ map: [String: String]) throws {
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

    private nonisolated func loadActiveProviderIDsFromSQLite(db: OpaquePointer?) throws -> [String] {
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

    private nonisolated func codexImportSQLiteDatabaseURL() -> URL {
        codexAccountsSQLiteDatabaseURL()
    }

    private func persistValidatedImportsToSQLiteGroup(
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

    private func setCustomSQLiteGroup(_ groupName: String, for accountID: UUID) throws {
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

    private nonisolated func upsertSQLiteImportRows(
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

    private enum SQLiteBindingValue {
        case text(String)
        case nullableText(String?)
    }

    private nonisolated var sqliteTransientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private nonisolated func executeSQLite(
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

    private nonisolated func sqliteColumnExists(db: OpaquePointer?, table: String, column: String) throws -> Bool {
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
