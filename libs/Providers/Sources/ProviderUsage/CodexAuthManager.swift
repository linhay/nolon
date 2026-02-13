import Foundation
import OSLog
import STFilePath
import ProviderCatalog
import STJSON
import ProvidersShared

public actor CodexAuthManager {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexAuthManager")
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
        rootFolder.folder("codex")
    }

    public nonisolated func nolonCodexAuthFolder() -> STFolder {
        nolonCodexRootFolder().folder("auth")
    }

    public nonisolated func activeAccountsFile() -> STFile {
        nolonCodexRootFolder().file("active-accounts.json")
    }

    public nonisolated func accountAuthFile(relativeAuthPath: String) -> STFile {
        nolonCodexRootFolder().file(relativeAuthPath)
    }

    public nonisolated static func cleanedAuthJSONData(from data: Data) -> Data? {
        guard var dict = decodeJSONObject(from: data) else { return nil }
        dict.removeValue(forKey: "nolon")
        return try? encodeJSONObject(dict)
    }

    // Usage cache encoding helpers are defined on CodexAuthUsageCache in ProviderUsage.

    public func codexHomeFolder(for provider: Provider) -> STFolder? {
        guard provider.templateId == ProviderTemplate.codex.rawValue else { return nil }
        let skillsPath = STPath(URL(fileURLWithPath: provider.defaultSkillsPath))
        return skillsPath.parentFolder()
    }

    public func authFile(for provider: Provider) -> STFile? {
        codexHomeFolder(for: provider)?.file("auth.json")
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
            preferredName: name,
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
            preferredName: account.name,
            preferredCreatedAt: account.createdAt
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
    /// - Else, try to match by email, then by auth data hash/content.
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

        if let email = deriveEmail(fromAuthJSONString: authJSONString),
           let matchedByEmail = try await findAccountByEmail(email) {
            try await updateAccount(matchedByEmail, authJSONString: authJSONString)
            return matchedByEmail
        }

        if let matchedByAuth = try await matchAccountByAuthData(data) {
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

    public func deleteAccount(id: UUID) async throws {
        let accounts = try await loadAccounts()
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        let file = accountAuthFile(account)
        try? file.delete()

        var map = loadActiveAccountMap()
        let before = map.count
        map = map.filter { $0.value != id.uuidString }
        if map.count != before {
            try saveActiveAccountMap(map)
        }
    }

    // MARK: - Accounts (folder-backed)

    private func loadAccountsFromAuthFolder() throws -> [CodexAuthAccount] {
        let folder = nolonCodexAuthFolder()
        let files = (try? folder.files()) ?? []

        var accounts: [CodexAuthAccount] = []
        accounts.reserveCapacity(files.count)

        for file in files where file.attributes.nameComponents.extension?.lowercased() == "json" {
            let fileName = file.attributes.name
            let relativeAuthPath = "auth/\(fileName)"
            do {
                let account = try loadAccount(file: file, relativeAuthPath: relativeAuthPath)
                accounts.append(account)
            } catch {
                Self.logger.error("Failed to load Codex account file: \(fileName, privacy: .public) error: \(String(describing: error), privacy: .public)")
            }
        }

        accounts.sort(by: { $0.createdAt > $1.createdAt })
        return accounts
    }

    public func readAuthJSONString(from provider: Provider) throws -> String? {
        guard let file = authFile(for: provider) else { return nil }
        guard file.isExists else { return nil }
        let raw = try file.read()
        return raw
    }

    public func readTokenPair(for account: CodexAuthAccount) throws -> (idToken: String, accessToken: String)? {
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

        guard let idToken, let accessToken else { return nil }
        return (idToken: idToken, accessToken: accessToken)
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

    public func setActiveAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        var map = loadActiveAccountMap()
        map[provider.id] = account.id.uuidString
        try saveActiveAccountMap(map)
    }

    /// Sync token fields from the active `~/.codex/auth.json` into the matching snapshot under `~/.nolon/codex/auth/`.
    /// Returns the updated snapshot file when a change is applied.
    public func syncActiveAuthTokensIfNeeded(for provider: Provider) async -> STFile? {
        guard let authFile = authFile(for: provider) else { return nil }
        guard authFile.isExists else { return nil }

        let authData: Data
        do {
            authData = try authFile.data()
        } catch {
            return nil
        }
        guard !authData.isEmpty,
              let authJSON = try? JSON(data: authData)
        else { return nil }

        let accounts = (try? await loadAccounts()) ?? []
        guard !accounts.isEmpty else { return nil }

        // If the active auth is a symlink to a snapshot, it is already in sync.
        if let destination = resolveSymlinkTarget(for: authFile) {
            let resolvedStandard = standardizedPathString(destination)
            if accounts.contains(where: { standardizedPathString(accountAuthFile($0)) == resolvedStandard }) {
                return nil
            }
        }

        guard let target = matchAccount(authData: authData, accounts: accounts) else { return nil }
        let targetFile = accountAuthFile(target)
        guard (try? syncAuthTokens(from: authJSON, to: targetFile)) == true else { return nil }
        return targetFile
    }

    public func activateAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        guard let authFile = authFile(for: provider) else { return }
        _ = authFile.parentFolder()?.createIfNotExists()

        // Replace existing auth.json (file or symlink) with a clean copy.
        if authFile.isExists {
            try authFile.delete()
        }
        
        let sourceFile = accountAuthFile(account)
        let data = try sourceFile.data()
        let cleanData = Self.cleanedAuthJSONData(from: data) ?? data
        try authFile.overlay(with: cleanData)

        Self.logger.info("Activated Codex auth by writing clean auth.json for provider: \(provider.id, privacy: .public)")
    }

    /// Activate snapshot into provider auth and persist active-account registry in one step.
    public func activateAccountAndMarkActive(_ account: CodexAuthAccount, for provider: Provider) throws {
        try activateAccount(account, for: provider)
        try setActiveAccount(account, for: provider)
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
        guard authFile.isExists else { return }
        if authFile.isSymbolicLink {
            // The active auth is already stored elsewhere; just detach so `codex login` can write a fresh file.
            try authFile.delete()
            return
        }

        // Regular file: if it matches an existing snapshot, just detach to avoid duplicating the account.
        if await activeAccountId(for: provider) != nil {
            try authFile.delete()
            return
        }

        // Regular file: snapshot it first, then remove.
        let raw = try authFile.read()
        let defaultName = deriveAccountName(fromAuthJSONString: raw)
        let name = (archiveAccountName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? defaultName
        _ = try await addAccount(name: name, authJSONString: raw)
        try authFile.delete()
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
        try activateAccount(account, for: provider)
        try setActiveAccount(account, for: provider)
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
                preferredName: item.name,
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
        if let email = summary.email?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty
        {
            return email
        }
        if let suffix = summary.apiKeySuffix, !suffix.isEmpty {
            return "key-\(suffix)"
        }
        return "account"
    }

    public nonisolated func deriveEmail(fromAuthJSONString authJSONString: String) -> String? {
        guard let data = authJSONString.data(using: .utf8),
              let json = try? JSON(data: data)
        else { return nil }
        return deriveEmail(from: json)
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

    private func resolveSymlinkTarget(for path: any STPathProtocol) -> STPath? {
        guard path.isSymbolicLink else { return nil }
        return try? path.destinationOfSymbolicLink()
    }

    private func standardizedPathString(_ path: any STPathProtocol) -> String {
        STPath.standardizedPath(path.url.path).path
    }

    private func jsonObjectsEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        AnyCodable(lhs) == AnyCodable(rhs)
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
            snapshots.append(AccountSnapshot(account: account, data: data, cleanedData: cleaned, summary: summary))
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
        let cleanedAuthData = Self.cleanedAuthJSONData(from: authData) ?? authData

        let snapshots = loadAccountSnapshots(for: accounts)
        if let match = snapshots.first(where: { $0.cleanedData == cleanedAuthData }) {
            return match.account
        }

        let authSummary = CodexAuthSummary.fromJSONData(authData)
        let authEmail = normalizedEmail(authSummary.email)
        let authSuffix = authSummary.apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let emailMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authEmail,
                  let email = normalizedEmail(snapshot.summary.email),
                  email == authEmail
            else { return nil }
            return snapshot.account
        }

        let suffixMatches = snapshots.compactMap { snapshot -> CodexAuthAccount? in
            guard let authSuffix,
                  let suffix = snapshot.summary.apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  suffix == authSuffix
            else { return nil }
            return snapshot.account
        }

        if let match = pickLatestAccount(from: emailMatches) {
            return match
        }
        return pickLatestAccount(from: suffixMatches)
    }

    func syncAuthTokens(from authJSON: JSON, to file: STFile) throws -> Bool {
        let data = try file.data()
        guard let rootJSON = try? JSON(data: data) else { return false }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        var changed = false

        if authJSON["tokens"].dictionary != nil {
            let tokensObject = authJSON["tokens"].dictionaryObject ?? [:]
            if !jsonObjectsEqual(rootObject["tokens"], tokensObject) {
                rootObject["tokens"] = tokensObject
                changed = true
            }
        }

        for key in Self.authTokenKeys {
            let value = authJSON[key]
            guard value != JSON.null else { continue }
            let object = value.object
            if !jsonObjectsEqual(rootObject[key], object) {
                rootObject[key] = object
                changed = true
            }
        }

        guard changed else { return false }
        try file.overlay(with: Self.encodeJSONObject(rootObject))
        return true
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

    func pickLatestAccount(from accounts: [CodexAuthAccount]) -> CodexAuthAccount? {
        guard !accounts.isEmpty else { return nil }
        return accounts.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    static let authTokenKeys: [String] = [
        "access_token",
        "refresh_token",
        "id_token",
        "token",
        "token_type",
        "expires_at",
        "expires_in",
        "api_key",
        "apiKey",
        "openai_api_key",
        "OPENAI_API_KEY",
        "tokenType",
        "expiresAt",
        "expiresIn",
    ]

    func loadAccount(file: STFile, relativeAuthPath: String) throws -> CodexAuthAccount {
        let data = try file.data()
        guard !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let rootJSON = try? JSON(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var rootObject = rootJSON.dictionaryObject ?? [:]
        let fallbackCreatedAt = max(file.attributes.creationDate, file.attributes.modificationDate)
        var changed = false

        let existingId = getString(rootObject, path: ["nolon", "account", "id"]).flatMap(UUID.init(uuidString:))
        let id = existingId ?? UUID()
        if existingId == nil {
            setValue(id.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
            changed = true
        }

        let existingCreatedAt = getString(rootObject, path: ["nolon", "account", "createdAt"]).flatMap { Self.makeISOFormatter().date(from: $0) }
        let createdAt = existingCreatedAt ?? fallbackCreatedAt
        if existingCreatedAt == nil {
            setValue(Self.makeISOFormatter().string(from: createdAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
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

        let existingName = getString(rootObject, path: ["nolon", "account", "name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (existingName?.isEmpty == false ? existingName : nil)
            ?? email
            ?? deriveAccountName(fromAuthJSONString: String(data: data, encoding: .utf8) ?? "")

        if existingName == nil || existingName?.isEmpty == true {
            setValue(name, path: ["nolon", "account", "name"], dict: &rootObject)
            changed = true
        }

        if changed {
            try file.overlay(with: Self.encodeJSONObject(rootObject))
        }

        return CodexAuthAccount(id: id, name: name, createdAt: createdAt, relativeAuthPath: relativeAuthPath)
    }

    func writeAccountFile(
        file: STFile,
        relativeAuthPath: String,
        authJSONString: String,
        preferredId: UUID,
        preferredName: String,
        preferredCreatedAt: Date
    ) throws {
        guard let data = authJSONString.data(using: .utf8),
              let rootJSON = try? JSON(data: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var rootObject = rootJSON.dictionaryObject ?? [:]

        setValue(preferredId.uuidString, path: ["nolon", "account", "id"], dict: &rootObject)
        setValue(preferredName, path: ["nolon", "account", "name"], dict: &rootObject)
        setValue(Self.makeISOFormatter().string(from: preferredCreatedAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
        setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)

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
                        preferredName: account.name,
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
        preferredName: String,
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
        if getString(rootObject, path: ["nolon", "account", "name"]) == nil {
            setValue(preferredName, path: ["nolon", "account", "name"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "createdAt"]) == nil {
            setValue(Self.makeISOFormatter().string(from: preferredCreatedAt), path: ["nolon", "account", "createdAt"], dict: &rootObject)
            changed = true
        }
        if getString(rootObject, path: ["nolon", "account", "relativeAuthPath"]) == nil {
            setValue(relativeAuthPath, path: ["nolon", "account", "relativeAuthPath"], dict: &rootObject)
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

        if let email = trimmed(authJSON["email"].string)
            ?? trimmed(authJSON["user"]["email"].string)
            ?? trimmed(authJSON["profile"]["email"].string)
            ?? trimmed(authJSON["nolon"]["account"]["email"].string)
        {
            return email
        }

        let idToken = trimmed(authJSON["tokens"]["id_token"].string)
            ?? trimmed(authJSON["tokens"]["idToken"].string)
            ?? trimmed(authJSON["id_token"].string)
            ?? trimmed(authJSON["idToken"].string)

        guard let idToken else { return nil }
        return decodeEmail(fromJWT: idToken)
    }

    nonisolated func decodeEmail(fromJWT jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadB64 = String(parts[1])
        guard let payloadData = base64URLDecode(payloadB64),
              let payloadJSON = try? JSON(data: payloadData)
        else { return nil }

        let trimmed: (String?) -> String? = { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }

        return trimmed(payloadJSON["email"].string)
            ?? trimmed(payloadJSON["https://api.openai.com/profile"]["email"].string)
            ?? trimmed(payloadJSON["profile"]["email"].string)
    }

    nonisolated func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }
}
