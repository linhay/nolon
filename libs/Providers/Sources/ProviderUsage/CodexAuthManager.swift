import Foundation
import OSLog
import CryptoKit
import Darwin
import STFilePath
import ProviderCatalog
import STJSON
import ProvidersShared
import SKProcessRunner

public actor CodexAuthManager {
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
    private nonisolated static func isCodexTemplate(_ templateID: String?) -> Bool {
        templateID == ProviderTemplate.codex.rawValue || templateID == ProviderTemplate.codexXcode.rawValue
    }
    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
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
    private static let sub2APIJSONEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private typealias JSONObject = [String: Any]

    private nonisolated let rootFolder: STFolder

    public init(
        rootURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if let rootURL {
            self.rootFolder = STFolder(rootURL)
        } else {
            self.rootFolder = NolonHomeEnvironment.resolveNolonHomeFolder(environment: environment)
        }
    }

    public nonisolated func nolonCodexRootFolder() -> STFolder {
        rootFolder.folder(PathName.codexRoot.rawValue)
    }

    public nonisolated func nolonCodexAuthFolder() -> STFolder {
        nolonCodexRootFolder().folder(PathName.authFolder.rawValue)
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

    public nonisolated static func cleanedAuthJSONData(from data: Data) -> Data? {
        guard var dict = decodeJSONObject(from: data) else { return nil }
        dict.removeValue(forKey: "nolon")
        return try? encodeJSONObject(dict)
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
        let existingMode = get("auth_mode")
        if existingMode == nil {
            if trimmedNonEmpty(rootObject["OPENAI_API_KEY"]) != nil {
                rootObject["auth_mode"] = "apikey"
            } else if trimmedNonEmpty(tokens["id_token"]) != nil {
                rootObject["auth_mode"] = "chatgptAuthTokens"
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

    public func loadAccounts() async throws -> [CodexAuthAccount] {
        try await migrateLegacyIfNeeded()
        return try loadAccountsFromAuthFolder()
    }

    public func addAccount(name: String, authJSONString: String) async throws -> CodexAuthAccount {
        try await migrateLegacyIfNeeded()

        _ = nolonCodexAuthFolder().createIfNotExists()

        let fileName = uniqueAuthFileName(for: name, existing: existingAuthRelativePaths())
        let relativePath = "auth/\(fileName)"
        let file = nolonCodexRootFolder().file(relativePath)
        try writeAccountFile(
            file: file,
            relativeAuthPath: relativePath,
            authJSONString: authJSONString,
            preferredId: UUID(),
            preferredCreatedAt: Date()
        )
        return try loadAccount(file: file, relativeAuthPath: relativePath)
    }

    public func updateAccount(_ account: CodexAuthAccount, authJSONString: String) async throws {
        try await migrateLegacyIfNeeded()
        let file = accountAuthFile(account)
        try writeAccountFile(
            file: file,
            relativeAuthPath: account.relativeAuthPath,
            authJSONString: authJSONString,
            preferredId: account.id,
            preferredCreatedAt: account.createdAt
        )
    }

    public func addConfiguredAccount(
        name: String,
        apiKey: String,
        relay: ConfiguredRelay?,
        usageQuery: CodexHTTPUsageQuery? = nil
    ) async throws -> CodexAuthAccount {
        try await migrateLegacyIfNeeded()

        _ = nolonCodexAuthFolder().createIfNotExists()

        let preferredName = sanitizedConfiguredAccountName(name: name, relay: relay)
        let fileName = uniqueAuthFileName(for: preferredName, existing: existingAuthRelativePaths())
        let relativePath = "auth/\(fileName)"
        let file = nolonCodexRootFolder().file(relativePath)
        let payload = try makeConfiguredAccountPayload(
            name: preferredName,
            apiKey: apiKey,
            relay: relay,
            usageQuery: usageQuery,
            preferredId: UUID(),
            relativeAuthPath: relativePath,
            createdAt: Date(),
            updatedAt: Date()
        )
        try file.overlay(with: payload)
        return try loadAccount(file: file, relativeAuthPath: relativePath)
    }

    public func updateConfiguredAccount(
        _ account: CodexAuthAccount,
        name: String,
        apiKey: String,
        relay: ConfiguredRelay?,
        usageQuery: CodexHTTPUsageQuery? = nil
    ) async throws {
        try await migrateLegacyIfNeeded()
        let file = accountAuthFile(account)
        let payload = try makeConfiguredAccountPayload(
            name: sanitizedConfiguredAccountName(name: name, relay: relay),
            apiKey: apiKey,
            relay: relay,
            usageQuery: usageQuery,
            preferredId: account.id,
            relativeAuthPath: account.relativeAuthPath,
            createdAt: account.createdAt,
            updatedAt: Date(),
            existingRootObject: (try? file.data()).flatMap { Self.decodeJSONObject(from: $0) }
        )
        try file.overlay(with: payload)
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
            let sourceURL = accountAuthFile(account).url
            let preferredName = URL(fileURLWithPath: account.relativeAuthPath).deletingPathExtension().lastPathComponent
            let fileName = uniqueExportFileName(preferred: preferredName, usedNames: &usedNames)
            let destination = stagingFolder.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try runDitto(arguments: ["-c", "-k", "--keepParent", stagingRoot.path, destinationURL.path])
        return selectedAccounts.count
    }

    public func exportAccountsAsSub2API(accountIDs: [UUID], destinationURL: URL) async throws -> Sub2APIExportResult {
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

        var exportedAccounts: [Sub2APIAccount] = []
        var skippedRelayCount = 0
        var skippedUnsupportedCount = 0

        for account in selectedAccounts {
            let data = try accountAuthFile(account).data()
            guard !data.isEmpty, let authJSON = try? JSON(data: data) else {
                skippedUnsupportedCount += 1
                continue
            }

            let summary = CodexAuthSummary.fromJSONData(data)
            let fallbackFileStem = URL(fileURLWithPath: account.relativeAuthPath).deletingPathExtension().lastPathComponent
            switch makeSub2APIExportMapping(from: authJSON, summary: summary, fallbackFileStem: fallbackFileStem) {
            case let .exportable(exportable):
                exportedAccounts.append(exportable)
            case .skipRelay:
                skippedRelayCount += 1
            case .skipUnsupported:
                skippedUnsupportedCount += 1
            }
        }

        guard !exportedAccounts.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.Export",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "No supported sub2api accounts could be exported."]
            )
        }

        let payload = Sub2APIExportPayload(
            exportedAt: Self.makeSub2APIExportTimestamp(),
            accounts: exportedAccounts
        )
        let data = try Self.sub2APIJSONEncoder.encode(payload)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)

        return Sub2APIExportResult(
            exportedCount: exportedAccounts.count,
            skippedRelayCount: skippedRelayCount,
            skippedUnsupportedCount: skippedUnsupportedCount
        )
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

    public func exportValidatedAuthFilesAsSub2API(
        results: [CodexImportValidationResult],
        destinationURL: URL
    ) async throws -> Sub2APIExportResult {
        try await migrateLegacyIfNeeded()
        let selectedEntries = makeValidatedExportEntries(from: results)
        guard !selectedEntries.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.Export",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No valid import candidates selected for export."]
            )
        }

        var exportedAccounts: [Sub2APIAccount] = []
        var skippedRelayCount = 0
        var skippedUnsupportedCount = 0

        for entry in selectedEntries {
            switch makeSub2APIExportMapping(
                from: entry.authJSON,
                summary: entry.summary,
                fallbackFileStem: entry.preferredFileStem
            ) {
            case let .exportable(exportable):
                exportedAccounts.append(exportable)
            case .skipRelay:
                skippedRelayCount += 1
            case .skipUnsupported:
                skippedUnsupportedCount += 1
            }
        }

        guard !exportedAccounts.isEmpty else {
            throw NSError(
                domain: "CodexAuthManager.Export",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "No supported sub2api accounts could be exported."]
            )
        }

        let payload = Sub2APIExportPayload(
            exportedAt: Self.makeSub2APIExportTimestamp(),
            accounts: exportedAccounts
        )
        let data = try Self.sub2APIJSONEncoder.encode(payload)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)

        return Sub2APIExportResult(
            exportedCount: exportedAccounts.count,
            skippedRelayCount: skippedRelayCount,
            skippedUnsupportedCount: skippedUnsupportedCount
        )
    }

    public func findAccountByEmail(_ email: String) async throws -> CodexAuthAccount? {
        let normalized = normalizedEmail(email)
        guard let normalized else { return nil }
        let accounts = try await loadAccounts()
        for account in accounts {
            let file = accountAuthFile(account)
            guard let data = try? file.data(),
                  !data.isEmpty
            else { continue }
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
    /// - Else, if email matches existing snapshots, require exact account-id match to update.
    /// - Else, try to match by auth data hash/content.
    /// - If no match, create a new snapshot account.
    public func upsertAccountFromCLILogin(authJSONString: String, preferredAccountID: UUID?) async throws -> CodexAuthAccount {
        let data = Data(authJSONString.utf8)

        if let preferredAccountID {
            let accounts = try await loadAccounts()
            if let preferred = accounts.first(where: { $0.id == preferredAccountID }) {
                try await updateAccount(preferred, authJSONString: authJSONString)
                return preferred
            }
        }

        let accounts = try await loadAccounts()
        let summary = CodexAuthSummary.fromJSONData(data)
        let authEmail = normalizedEmail(summary.email)
        let authAccountID = normalizedAccountID(summary.accountID)

        if let authEmail {
            let snapshots = loadAccountSnapshots(for: accounts)
            let emailMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
                guard let email = normalizedEmail(snapshot.summary.email), email == authEmail else { return nil }
                return snapshot.account
            }

            if !emailMatches.isEmpty {
                if let authAccountID {
                    let accountIDMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
                        guard let email = normalizedEmail(snapshot.summary.email),
                              email == authEmail,
                              let accountID = normalizedAccountID(snapshot.summary.accountID),
                              accountID == authAccountID
                        else { return nil }
                        return snapshot.account
                    }
                    if let matchedByEmailAndAccountID = pickLatestAccount(from: accountIDMatches) {
                        try await updateAccount(matchedByEmailAndAccountID, authJSONString: authJSONString)
                        return matchedByEmailAndAccountID
                    }
                }

                let finalName = deriveAccountName(fromAuthJSONString: authJSONString)
                return try await addAccount(name: finalName, authJSONString: authJSONString)
            }
        }

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
        try withAuthFileLock {
            let accounts = try loadAccountsFromAuthFolder()
            guard let account = accounts.first(where: { $0.id == id }) else { return }

            let snapshotFile = accountAuthFile(account)
            let snapshotData = try? snapshotFile.data()
            let snapshotPath = standardizedPathString(snapshotFile)
            try removeFileOrSymlinkIfPresent(snapshotFile)

            var map = loadActiveAccountMap()
            let before = map.count
            map = map.filter { $0.value != id.uuidString }
            if map.count != before {
                try saveActiveAccountMap(map)
            }

            guard let provider,
                  Self.isCodexTemplate(provider.templateId),
                  let providerAuthFile = authFile(for: provider)
            else { return }

            let shouldDetachProviderAuth: Bool = {
                if providerAuthFile.isSymbolicLink,
                   let destination = resolveSymlinkTarget(for: providerAuthFile) {
                    return standardizedPathString(destination) == snapshotPath
                }

                guard providerAuthFile.isExists,
                      !providerAuthFile.isSymbolicLink,
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

    // MARK: - Accounts (folder-backed)

    private func loadAccountsFromAuthFolder() throws -> [CodexAuthAccount] {
        let folder = nolonCodexAuthFolder()
        let fileNames = stableAuthSnapshotFileNames(in: folder)

        var accounts: [CodexAuthAccount] = []
        accounts.reserveCapacity(fileNames.count)

        for fileName in fileNames {
            let relativeAuthPath = "auth/\(fileName)"
            let file = folder.file(fileName)
            do {
                let account = try loadAccount(file: file, relativeAuthPath: relativeAuthPath)
                accounts.append(account)
            } catch {
                Self.logger.error("Failed to load Codex account file: \(fileName, privacy: .public) error: \(String(describing: error), privacy: .public)")
            }
        }

        accounts = try healDuplicateAccountIDsIfNeeded(accounts)
        accounts = try pruneDuplicateSnapshotPayloadsIfNeeded(accounts)
        accounts = try alignSnapshotFileNamesWithEmailIfNeeded(accounts)
        accounts.sort(by: { $0.createdAt > $1.createdAt })
        return accounts
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
        let data = try accountAuthFile(account).data()
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
        let data = try accountAuthFile(account).data()
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
        let file = accountAuthFile(account)
        var rootObject = (try? file.data()).flatMap { Self.decodeJSONObject(from: $0) } ?? [:]
        var nolonObject = (rootObject["nolon"] as? JSONObject) ?? [:]
        if let cacheObject = nolonObject["usage_cache"], !(cacheObject is NSNull) {
            if let existing = try? Self.decodeUsageCache(from: cacheObject),
               Self.isUsageCacheEquivalent(existing, cache) {
                return
            }
        }
        nolonObject["usage_cache"] = cache
        rootObject["nolon"] = nolonObject
        try file.overlay(with: Self.encodeJSONObject(rootObject))
    }

    public func clearUsageCache(for account: CodexAuthAccount) throws {
        let file = accountAuthFile(account)
        var rootObject = (try? file.data()).flatMap { Self.decodeJSONObject(from: $0) } ?? [:]
        var nolonObject = (rootObject["nolon"] as? JSONObject) ?? [:]
        guard nolonObject["usage_cache"] != nil else { return }
        nolonObject.removeValue(forKey: "usage_cache")
        rootObject["nolon"] = nolonObject
        try file.overlay(with: Self.encodeJSONObject(rootObject))
    }

    public func updateSyncSuccess(for account: CodexAuthAccount, date: Date = Date()) throws {
        let file = accountAuthFile(account)
        try updateSyncMetadata(
            file: file,
            loginAt: nil,
            successAt: date,
            failureAt: nil,
            failureMessage: nil,
            clearFailure: true
        )
    }

    public func updateSyncFailure(for account: CodexAuthAccount, message: String, date: Date = Date()) throws {
        let file = accountAuthFile(account)
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(trimmed.prefix(220))
        try updateSyncMetadata(
            file: file,
            loginAt: nil,
            successAt: nil,
            failureAt: date,
            failureMessage: clipped.isEmpty ? nil : clipped,
            clearFailure: false
        )
    }

    public func updateLoginSuccess(for account: CodexAuthAccount, date: Date = Date()) throws {
        let file = accountAuthFile(account)
        try updateSyncMetadata(
            file: file,
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

        let file = accountAuthFile(account)
        let data = try file.data()
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
            try file.overlay(with: Self.encodeJSONObject(rootObject))
        }
        return changed
    }

    public func currentAuthHashHex(for provider: Provider) -> String? {
        guard let raw = try? readAuthJSONString(from: provider) else { return nil }
        return CodexAuthAccount.hashHex(for: raw)
    }

    public func activeAccountId(for provider: Provider) async -> UUID? {
        let accounts = (try? await loadAccounts()) ?? []
        guard let authFile = authFile(for: provider) else {
            return activeAccountIdFromRegistry(for: provider, accounts: accounts)
        }

        // Symlink form (older behavior / user created): resolve target and match by file URL.
        if let destination = resolveSymlinkTarget(for: authFile) {
            let resolvedStandard = standardizedPathString(destination)
            for account in accounts {
                if standardizedPathString(accountAuthFile(account)) == resolvedStandard {
                    return account.id
                }
            }
        }

        // Regular file: match by cleaned content (ignore Nolon metadata).
        guard let currentData = try? authFile.data(),
              !currentData.isEmpty
        else { return activeAccountIdFromRegistry(for: provider, accounts: accounts) }

        if let matched = matchAccount(authData: currentData, accounts: accounts)?.id {
            return matched
        }

        return activeAccountIdFromRegistry(for: provider, accounts: accounts)
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
                    let normalizedData = Self.normalizeImportedAuthJSONDataIfNeeded(data) ?? data
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
                    }
                    guard hasImportableCredentials(authJSONString: raw) else {
                        results.append(
                            CodexImportValidationResult(
                                fileURL: candidateURL,
                                sourceGroupID: sourceGroupID,
                                sourceGroupLabel: sourceGroupLabel,
                                isValid: false,
                                reason: "Missing required credentials",
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
    public func importValidatedAuthFiles(results: [CodexImportValidationResult]) async throws -> [CodexAuthAccount] {
        var imported: [CodexAuthAccount] = []
        for result in results where result.isValid {
            guard let raw = result.authJSONString else { continue }
            let finalName = result.suggestedName ?? deriveAccountName(fromAuthJSONString: raw)
            let account = try await addAccount(name: finalName, authJSONString: raw)
            imported.append(account)
        }
        return imported
    }

    public func setActiveAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        var map = loadActiveAccountMap()
        map[provider.id] = account.id.uuidString
        try saveActiveAccountMap(map)
    }

    public func activateAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        guard let authFile = authFile(for: provider) else { return }
        _ = authFile.parentFolder()?.createIfNotExists()

        // Replace existing auth.json (file or symlink) with a symlink to the selected snapshot.
        try removeFileOrSymlinkIfPresent(authFile)

        let sourceFile = accountAuthFile(account)
        try authFile.createSymbolicLink(to: sourceFile)

        Self.logger.info("Activated Codex auth by symlink for provider: \(provider.id, privacy: .public)")
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

        public var errorDescription: String? {
            switch self {
            case .codexHomeUnavailable:
                return "Codex home path is unavailable."
            case .authFileNotFound:
                return "No auth.json found."
            case .authFileInvalidEncoding:
                return "auth.json is not valid UTF-8."
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

    private func sanitizeEmailFileComponent(_ email: String) -> String {
        sanitizeSnapshotFileComponent(
            email,
            allowed: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@.+_-")),
            fallback: "unknown-email"
        )
    }

    private func sanitizeAccountIDFileComponent(_ accountID: String) -> String? {
        let sanitized = sanitizeSnapshotFileComponent(
            accountID,
            allowed: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")),
            fallback: ""
        )
        return sanitized.isEmpty ? nil : sanitized
    }

    private func sanitizeSnapshotFileComponent(_ value: String, allowed: CharacterSet, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let mapped = trimmed.unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(mapped)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
        return collapsed.isEmpty ? fallback : collapsed
    }

    private func findSnapshotAccountByEmail(_ email: String) throws -> CodexAuthAccount? {
        guard let normalized = normalizedEmail(email) else { return nil }
        let accounts = try loadAccountsFromAuthFolder()
        for account in accounts {
            let file = accountAuthFile(account)
            guard let data = try? file.data(),
                  !data.isEmpty
            else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            if let candidate = normalizedEmail(summary.email), candidate == normalized {
                return account
            }
        }
        return nil
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
            let file = nolonCodexRootFolder().file(relativePath)
            try writeAccountFile(
                file: file,
                relativeAuthPath: relativePath,
                authJSONString: item.authJSONString,
                preferredId: item.id,
                preferredCreatedAt: item.createdAt
            )
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
        if idToken != nil, accessToken != nil {
            return true
        }

        let authMode = trimmed(json["auth_mode"].string)
        if idToken != nil, authMode == "chatgptAuthTokens" {
            return true
        }

        let apiKey = trimmed(json["OPENAI_API_KEY"].string)
            ?? trimmed(json["openai_api_key"].string)
            ?? trimmed(json["api_key"].string)
            ?? trimmed(json["apiKey"].string)
        return apiKey != nil
    }

    private enum Sub2APIExportMapping {
        case exportable(Sub2APIAccount)
        case skipRelay
        case skipUnsupported
    }

    private struct ValidatedExportEntry {
        let preferredFileStem: String
        let rawJSONString: String
        let authJSON: JSON
        let summary: CodexAuthSummary
    }

    private nonisolated func makeSub2APIExportMapping(
        from authJSON: JSON,
        summary: CodexAuthSummary,
        fallbackFileStem: String
    ) -> Sub2APIExportMapping {
        let kind = summary.cardKind ?? resolveCardKind(for: authJSON)

        switch kind {
        case .relayProfile:
            return .skipRelay
        case .officialAPIKey:
            return makeSub2APIApiKeyAccount(from: authJSON, summary: summary, fallbackFileStem: fallbackFileStem)
        case .chatgptAccount:
            return makeSub2APIOAuthAccount(from: authJSON, summary: summary, fallbackFileStem: fallbackFileStem)
        case .none:
            return .skipUnsupported
        }
    }

    private nonisolated func makeSub2APIOAuthAccount(
        from authJSON: JSON,
        summary: CodexAuthSummary,
        fallbackFileStem: String
    ) -> Sub2APIExportMapping {
        guard let idToken = firstNonEmptyString(in: authJSON, paths: [
            ["tokens", "id_token"],
            ["tokens", "idToken"],
            ["id_token"],
            ["idToken"],
        ]),
        let accessToken = firstNonEmptyString(in: authJSON, paths: [
            ["tokens", "access_token"],
            ["tokens", "accessToken"],
            ["access_token"],
            ["accessToken"],
        ]) else {
            return .skipUnsupported
        }

        let payload = CodexAuthSummary.decodeJWTPayloadJSON(idToken)
        let name = summary.preferredDisplayName(fallbackFileStem: fallbackFileStem)

        var credentials: [String: String] = [
            "access_token": accessToken,
            "id_token": idToken,
        ]
        if let refreshToken = firstNonEmptyString(in: authJSON, paths: [
            ["tokens", "refresh_token"],
            ["tokens", "refreshToken"],
            ["refresh_token"],
            ["refreshToken"],
        ]) {
            credentials["refresh_token"] = refreshToken
        }
        if let expiresAt = firstNonEmptyString(in: authJSON, paths: [["expires_at"], ["expiresAt"]]) {
            credentials["expires_at"] = expiresAt
        }
        if let email = summary.email ?? deriveEmail(from: authJSON) {
            credentials["email"] = email
        }
        if let chatgptAccountID = summary.accountID {
            credentials["chatgpt_account_id"] = chatgptAccountID
        }
        if let chatgptUserID = firstNonEmptyString(in: authJSON, paths: [["chatgpt_user_id"], ["chatgptUserId"], ["user_id"], ["userId"]])
            ?? firstNonEmptyString(in: payload, paths: [["sub"], ["user_id"], ["userId"]])
        {
            credentials["chatgpt_user_id"] = chatgptUserID
        }
        if let organizationID = firstNonEmptyString(in: authJSON, paths: [["organization_id"], ["organizationId"], ["org_id"], ["orgId"]])
            ?? firstNonEmptyString(in: payload, paths: [["organization_id"], ["organizationId"], ["org_id"], ["orgId"]])
        {
            credentials["organization_id"] = organizationID
        }
        if let planType = firstNonEmptyString(in: authJSON, paths: [["plan_type"], ["planType"]]) ?? summary.plan {
            credentials["plan_type"] = planType
        }
        if let clientID = firstNonEmptyString(in: authJSON, paths: [["client_id"], ["clientId"]])
            ?? firstNonEmptyString(in: payload, paths: [["client_id"], ["clientId"], ["azp"], ["aud"]])
        {
            credentials["client_id"] = clientID
        }

        return .exportable(Sub2APIAccount(
            name: name,
            notes: "Codex OAuth account",
            type: "oauth",
            credentials: credentials,
            extra: [
                "openai_passthrough": true,
                "codex_cli_only": true,
            ],
            concurrency: 1,
            priority: 0,
            rateMultiplier: 1,
            autoPauseOnExpired: true
        ))
    }

    private nonisolated func makeSub2APIApiKeyAccount(
        from authJSON: JSON,
        summary: CodexAuthSummary,
        fallbackFileStem: String
    ) -> Sub2APIExportMapping {
        if authJSON["nolon"]["relay"] != JSON.null, authJSON["nolon"]["relay"].dictionaryObject?.isEmpty == false {
            return .skipRelay
        }

        guard let apiKey = firstNonEmptyString(in: authJSON, paths: [
            ["OPENAI_API_KEY"],
            ["openai_api_key"],
            ["api_key"],
            ["apiKey"],
        ]) else {
            return .skipUnsupported
        }

        let name = summary.preferredDisplayName(fallbackFileStem: fallbackFileStem)

        return .exportable(Sub2APIAccount(
            name: name,
            notes: "OpenAI API key account",
            type: "apikey",
            credentials: ["api_key": apiKey],
            extra: ["openai_passthrough": true],
            concurrency: 1,
            priority: 10,
            rateMultiplier: 1,
            autoPauseOnExpired: false
        ))
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
        for path in paths {
            var current = json ?? JSON.null
            for key in path {
                current = current[key]
            }
            if let value = current.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty
            {
                return value
            }
        }
        return nil
    }

    private static func makeSub2APIExportTimestamp(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter.string(from: now)
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

    private func importCandidates(for url: URL) throws -> [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] {
        if url.pathExtension.lowercased() == "zip" {
            return try importCandidatesFromArchive(url)
        }
        let data = try Data(contentsOf: url)
        return expandJSONArrayCandidateIfNeeded(
            candidateURL: url,
            sourceGroupID: url.standardizedFileURL.path,
            sourceGroupLabel: url.lastPathComponent,
            data: data
        )
    }

    private func importCandidatesFromArchive(_ archiveURL: URL) throws -> [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] {
        let fileManager = FileManager.default
        let extractionRoot = fileManager.temporaryDirectory.appendingPathComponent("codex-import-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: extractionRoot) }

        try runDitto(arguments: ["-x", "-k", archiveURL.path, extractionRoot.path])

        guard let enumerator = fileManager.enumerator(at: extractionRoot, includingPropertiesForKeys: nil) else {
            return []
        }

        let sourceGroupID = archiveURL.standardizedFileURL.path
        let sourceGroupLabel = archiveURL.lastPathComponent
        var candidates: [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "json" else { continue }
            let data = try Data(contentsOf: fileURL)
            candidates.append(
                contentsOf: expandJSONArrayCandidateIfNeeded(
                    candidateURL: fileURL,
                    sourceGroupID: sourceGroupID,
                    sourceGroupLabel: sourceGroupLabel,
                    data: data
                )
            )
        }
        return candidates.sorted { $0.candidateURL.lastPathComponent < $1.candidateURL.lastPathComponent }
    }

    private func expandJSONArrayCandidateIfNeeded(
        candidateURL: URL,
        sourceGroupID: String,
        sourceGroupLabel: String,
        data: Data
    ) -> [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] {
        guard let json = try? JSON(data: data),
              let array = json.arrayObject
        else {
            return [(candidateURL, sourceGroupID, sourceGroupLabel, data)]
        }

        let baseName = candidateURL.deletingPathExtension().lastPathComponent
        var expanded: [(candidateURL: URL, sourceGroupID: String, sourceGroupLabel: String, data: Data)] = []
        expanded.reserveCapacity(array.count)

        for (index, element) in array.enumerated() {
            guard let object = element as? JSONObject else { continue }
            guard let elementData = try? Self.encodeJSONObject(object) else { continue }
            let itemName = String(format: "%@-item-%02d.json", baseName, index + 1)
            let syntheticURL = candidateURL
                .deletingLastPathComponent()
                .appendingPathComponent(itemName)
            expanded.append((syntheticURL, sourceGroupID, sourceGroupLabel, elementData))
        }

        return expanded.isEmpty ? [(candidateURL, sourceGroupID, sourceGroupLabel, data)] : expanded
    }

    private func runDitto(arguments: [String]) throws {
        var payload = SKProcessPayload.executableURL(STPath("/usr/bin/ditto").url)
        payload.arguments = arguments
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 120_000
        let result = try SKProcessRunner.runSync(payload)

        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexAuthManager.Ditto",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "ditto failed" : message]
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
                    guard let data = try? accountAuthFile(snapshot).data(), !data.isEmpty else { continue }
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
                let standardizedDestination = standardizedPathString(destination)
                if let linked = snapshots.first(where: { standardizedPathString(accountAuthFile($0)) == standardizedDestination }) {
                    let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots)
                    if activeID != linked.id {
                        try setActiveAccount(linked, for: provider)
                        return linked
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
            resolved = try upsertSnapshotFromProviderData(
                authData: providerData,
                providerRaw: providerRaw,
                snapshots: snapshots,
                excludedAccountID: nil
            )
        case .snapshot:
            guard let account = preferred.account else {
                resolved = try upsertSnapshotFromProviderData(
                    authData: providerData,
                    providerRaw: providerRaw,
                    snapshots: snapshots,
                    excludedAccountID: nil
                )
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
        try providerAuthFile.createSymbolicLink(to: accountAuthFile(resolved))
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
        let file = accountAuthFile(account)
        guard let data = try? file.data(), !data.isEmpty else { return nil }
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

        if let matched = matchAccount(authData: authData, accounts: snapshots),
           matched.id != excludedAccountID {
            try writeAccountFile(
                file: accountAuthFile(matched),
                relativeAuthPath: matched.relativeAuthPath,
                authJSONString: raw,
                preferredId: matched.id,
                preferredCreatedAt: matched.createdAt
            )
            return try loadAccount(
                file: accountAuthFile(matched),
                relativeAuthPath: matched.relativeAuthPath
            )
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
            let target = standardizedPathString(destination)
            return accounts.first(where: { standardizedPathString(accountAuthFile($0)) == target })
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

        let activeFile = accountAuthFile(activeAccount)
        guard activeFile.isExists,
              let activeData = try? activeFile.data(),
              !activeData.isEmpty
        else { return nil }

        let currentHash = cleanedHashHex(for: activeData)
        var fingerprints = loadActiveFingerprintMap()
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

        let backupSummary = CodexAuthSummary.fromJSONData(backupData)
        let driftSummary = CodexAuthSummary.fromJSONData(activeData)
        if isSameIdentity(backupSummary, driftSummary) {
            fingerprints[provider.id] = currentHash
            try saveActiveFingerprintMap(fingerprints)
            return nil
        }

        // External CLI switched account through active symlink:
        // restore original active snapshot from backup,
        // then place drifted auth payload into matched/new snapshot.
        try activeFile.overlay(with: backupData)
        let restoredAccount = try loadAccount(file: activeFile, relativeAuthPath: activeAccount.relativeAuthPath)
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

    private func isSameIdentity(_ lhs: CodexAuthSummary, _ rhs: CodexAuthSummary) -> Bool {
        if let left = normalizedEmail(lhs.email),
           let right = normalizedEmail(rhs.email) {
            return left == right
        }
        if let left = normalizedAccountID(lhs.accountID),
           let right = normalizedAccountID(rhs.accountID) {
            return left == right
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

        let activeFile = accountAuthFile(active)
        guard let data = try? activeFile.data(), !data.isEmpty else { return }
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

        let activeFile = accountAuthFile(active)
        guard let data = try? activeFile.data(),
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

    private static func decodeJSONObject(from data: Data) -> JSONObject? {
        guard let root = try? jsonDecoder.decode([String: AnyDecodable].self, from: data) else { return nil }
        return root.mapValues { $0.value }
    }

    private static func encodeJSONObject(_ object: JSONObject) throws -> Data {
        let encodable = object.mapValues { AnyEncodable($0) }
        return try jsonEncoder.encode(encodable)
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
        guard let last = path.last else { return nil }
        let parent = getDictionary(dict, path: Array(path.dropLast()))
        return parent?[last] as? String
    }

    private func getDictionary(_ dict: JSONObject, path: [String]) -> JSONObject? {
        guard !path.isEmpty else { return dict }
        var current: Any = dict
        for key in path {
            guard let next = (current as? JSONObject)?[key] else { return nil }
            current = next
        }
        return current as? JSONObject
    }

    private func setValue(_ value: Any, path: [String], dict: inout JSONObject) {
        guard let key = path.first else { return }
        if path.count == 1 {
            dict[key] = value
            return
        }
        var child = dict[key] as? JSONObject ?? [:]
        setValue(value, path: Array(path.dropFirst()), dict: &child)
        dict[key] = child
    }

    private func removeValue(path: [String], dict: inout JSONObject) {
        guard let key = path.first else { return }
        if path.count == 1 {
            dict.removeValue(forKey: key)
            return
        }
        guard var child = dict[key] as? JSONObject else { return }
        removeValue(path: Array(path.dropFirst()), dict: &child)
        if child.isEmpty {
            dict.removeValue(forKey: key)
        } else {
            dict[key] = child
        }
    }

    private func encodeJSONObjectObject<T: Encodable>(_ value: T) throws -> JSONObject {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
            throw CocoaError(.coderInvalidValue)
        }
        return object
    }

    private func loadAccountSnapshots(for accounts: [CodexAuthAccount]) -> [AccountSnapshot] {
        var snapshots: [AccountSnapshot] = []
        snapshots.reserveCapacity(accounts.count)

        for account in accounts {
            let file = accountAuthFile(account)
            guard let data = try? file.data(),
                  !data.isEmpty
            else { continue }
            let cleaned = Self.cleanedAuthJSONData(from: data) ?? data
            let summary = CodexAuthSummary.fromJSONData(data)
            let apiKey = extractAPIKey(from: data)
            snapshots.append(AccountSnapshot(account: account, data: data, cleanedData: cleaned, summary: summary, apiKey: apiKey))
        }

        return snapshots
    }

    private func existingAuthRelativePaths() -> Set<String> {
        let folder = nolonCodexAuthFolder()
        let files = (try? folder.files()) ?? []
        let rels = files
            .filter { $0.attributes.nameComponents.extension?.lowercased() == "json" }
            .map { "auth/\($0.attributes.name)" }
        return Set(rels)
    }

    private func activeAccountIdFromRegistry(for provider: Provider, accounts: [CodexAuthAccount]) -> UUID? {
        let map = loadActiveAccountMap()
        guard let raw = map[provider.id], let id = UUID(uuidString: raw) else { return nil }
        return accounts.contains(where: { $0.id == id }) ? id : nil
    }

    private func loadActiveAccountMap() -> [String: String] {
        let file = activeAccountsFile()
        guard file.isExists,
              let data = try? file.data(),
              !data.isEmpty,
              let root = Self.decodeJSONObject(from: data),
              let providers = root["providers"] as? JSONObject
        else { return [:] }

        return providers.reduce(into: [String: String]()) { result, element in
            if let value = element.value as? String,
               UUID(uuidString: value) != nil {
                result[element.key] = value
            }
        }
    }

    private func saveActiveAccountMap(_ map: [String: String]) throws {
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
        let authEmail = normalizedEmail(authSummary.email)
        let authAccountID = normalizedAccountID(authSummary.accountID)
        let authAPIKey = extractAPIKey(from: authData)

        let emailMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authEmail,
                  let email = normalizedEmail(snapshot.summary.email),
                  email == authEmail
            else { return nil }
            return snapshot.account
        }

        let accountIDMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authAccountID,
                  let accountID = normalizedAccountID(snapshot.summary.accountID),
                  accountID == authAccountID
            else { return nil }
            return snapshot.account
        }

        let apiKeyMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authAPIKey,
                  let apiKey = snapshot.apiKey,
                  apiKey == authAPIKey
            else { return nil }
            return snapshot.account
        }

        if let match = pickLatestAccount(from: accountIDMatches) {
            return match
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
        file: STFile,
        loginAt: Date?,
        successAt: Date?,
        failureAt: Date?,
        failureMessage: String?,
        clearFailure: Bool
    ) throws {
        var rootObject = (try? file.data()).flatMap { Self.decodeJSONObject(from: $0) } ?? [:]
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
        try file.overlay(with: Self.encodeJSONObject(rootObject))
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

    func pickLatestAccount(from accounts: [CodexAuthAccount]) -> CodexAuthAccount? {
        guard !accounts.isEmpty else { return nil }
        return accounts.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    func createSnapshotAccount(authJSONString: String) throws -> CodexAuthAccount {
        _ = nolonCodexAuthFolder().createIfNotExists()

        let name = deriveAccountName(fromAuthJSONString: authJSONString)
        let fileName = uniqueAuthFileName(for: name, existing: existingAuthRelativePaths())
        let relativePath = "auth/\(fileName)"
        let file = nolonCodexRootFolder().file(relativePath)
        try writeAccountFile(
            file: file,
            relativeAuthPath: relativePath,
            authJSONString: authJSONString,
            preferredId: UUID(),
            preferredCreatedAt: Date()
        )
        return try loadAccount(file: file, relativeAuthPath: relativePath)
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

    func healDuplicateAccountIDsIfNeeded(_ accounts: [CodexAuthAccount]) throws -> [CodexAuthAccount] {
        guard !accounts.isEmpty else { return accounts }

        var healed = accounts
        var seen = Set<UUID>()

        for index in healed.indices {
            let account = healed[index]
            if seen.insert(account.id).inserted {
                continue
            }

            let file = accountAuthFile(account)
            do {
                let raw = try file.read()
                let newID = UUID()
                try writeAccountFile(
                    file: file,
                    relativeAuthPath: account.relativeAuthPath,
                    authJSONString: raw,
                    preferredId: newID,
                    preferredCreatedAt: account.createdAt
                )
                let reloaded = try loadAccount(file: file, relativeAuthPath: account.relativeAuthPath)
                healed[index] = reloaded
                _ = seen.insert(reloaded.id)
                Self.logger.warning(
                    "Detected duplicate Codex snapshot id, reassigned account identity. file=\(account.relativeAuthPath, privacy: .public) old=\(account.id.uuidString, privacy: .public) new=\(reloaded.id.uuidString, privacy: .public)"
                )
            } catch {
                Self.logger.error(
                    "Failed to heal duplicate Codex snapshot id. file=\(account.relativeAuthPath, privacy: .public) id=\(account.id.uuidString, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        return healed
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
                let duplicateFile = accountAuthFile(duplicate.account)
                do {
                    if duplicateFile.isExists {
                        try duplicateFile.delete()
                    }
                    removedIDs.insert(duplicate.account.id)
                    replacementByRemovedID[duplicate.account.id] = keeper.account.id
                    Self.logger.warning(
                        "Removed duplicate Codex snapshot payload. removed=\(duplicate.account.relativeAuthPath, privacy: .public) kept=\(keeper.account.relativeAuthPath, privacy: .public)"
                    )
                } catch {
                    Self.logger.error(
                        "Failed to remove duplicate Codex snapshot payload. file=\(duplicate.account.relativeAuthPath, privacy: .public) error=\(String(describing: error), privacy: .public)"
                    )
                }
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
        guard !accounts.isEmpty else { return accounts }

        var aligned = accounts
        var usedPaths = Set(accounts.map(\.relativeAuthPath))

        for index in aligned.indices {
            let account = aligned[index]
            let file = accountAuthFile(account)
            guard let data = try? file.data(), !data.isEmpty else { continue }
            let summary = CodexAuthSummary.fromJSONData(data)
            guard let email = normalizedEmail(summary.email),
                  let accountID = normalizedAccountID(summary.accountID),
                  let accountIDComponent = sanitizeAccountIDFileComponent(accountID)
            else { continue }

            usedPaths.remove(account.relativeAuthPath)
            let emailComponent = sanitizeEmailFileComponent(email)
            let expectedStem = "\(emailComponent)(\(accountIDComponent))"
            let expectedFileName = uniqueAuthFileName(forStem: expectedStem, existing: usedPaths)
            let expectedRelativePath = "auth/\(expectedFileName)"
            guard expectedRelativePath != account.relativeAuthPath else {
                usedPaths.insert(account.relativeAuthPath)
                continue
            }

            let targetFile = accountAuthFile(relativeAuthPath: expectedRelativePath)
            do {
                if targetFile.isExists {
                    try targetFile.delete()
                }
                try file.move(to: targetFile)
                let movedRaw = try targetFile.read()
                try writeAccountFile(
                    file: targetFile,
                    relativeAuthPath: expectedRelativePath,
                    authJSONString: movedRaw,
                    preferredId: account.id,
                    preferredCreatedAt: account.createdAt
                )
                let reloaded = try loadAccount(file: targetFile, relativeAuthPath: expectedRelativePath)
                aligned[index] = reloaded
                usedPaths.insert(expectedRelativePath)
                Self.logger.warning(
                    "Renamed Codex snapshot to align file name with email(account_id). from=\(account.relativeAuthPath, privacy: .public) to=\(expectedRelativePath, privacy: .public)"
                )
            } catch {
                usedPaths.insert(account.relativeAuthPath)
                Self.logger.error(
                    "Failed to align Codex snapshot file name with email(account_id). file=\(account.relativeAuthPath, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        return aligned
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

        let authMode = authJSON["auth_mode"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        if authMode == "apikey" {
            return authJSON["nolon"]["relay"] != JSON.null ? "relayProfile" : "officialAPIKey"
        }
        if authMode == "chatgpt" || authMode == "chatgptAuthTokens" {
            return "chatgptAccount"
        }
        return nil
    }
}
