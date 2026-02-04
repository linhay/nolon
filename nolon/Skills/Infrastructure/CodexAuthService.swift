import Foundation
import OSLog
import STFilePath
import ProviderCatalog
import ProviderUsage
import STJSON

actor CodexAuthService {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexAuthService")

    private nonisolated let rootURL: URL

    init(rootURL: URL = NolonManager.shared.rootURL) {
        self.rootURL = rootURL
    }

    nonisolated func nolonCodexRootURL() -> URL {
        rootURL.appendingPathComponent("codex", isDirectory: true)
    }

    nonisolated func nolonCodexAuthFolderURL() -> URL {
        nolonCodexRootURL().appendingPathComponent("auth", isDirectory: true)
    }

    nonisolated func accountAuthFileURL(relativeAuthPath: String) -> URL {
        nolonCodexRootURL().appendingPathComponent(relativeAuthPath)
    }

    nonisolated static func cleanedAuthJSONData(from data: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              var dict = object as? [String: Any]
        else { return nil }

        dict.removeValue(forKey: "nolon")
        guard JSONSerialization.isValidJSONObject(dict) else { return nil }

        return try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }

    // Usage cache encoding helpers are defined on CodexAuthUsageCache in ProviderUsage.

    func codexHomeURL(for provider: Provider) -> URL? {
        guard provider.templateId == ProviderTemplate.codex.rawValue else { return nil }
        let skillsURL = URL(fileURLWithPath: provider.defaultSkillsPath)
        return skillsURL.deletingLastPathComponent()
    }

    func authFileURL(for provider: Provider) -> URL? {
        codexHomeURL(for: provider)?.appendingPathComponent("auth.json")
    }

    func accountAuthFileURL(_ account: CodexAuthAccount) -> URL {
        accountAuthFileURL(relativeAuthPath: account.relativeAuthPath)
    }

    func loadAccounts() async throws -> [CodexAuthAccount] {
        try await migrateLegacyIfNeeded()
        return try loadAccountsFromAuthFolder()
    }

    func addAccount(name: String, authJSONString: String) async throws -> CodexAuthAccount {
        try await migrateLegacyIfNeeded()

        try FileManager.default.createDirectory(at: nolonCodexAuthFolderURL(), withIntermediateDirectories: true, attributes: nil)

        let fileName = uniqueAuthFileName(for: name, existing: existingAuthRelativePaths())
        let relativePath = "auth/\(fileName)"
        let fileURL = nolonCodexRootURL().appendingPathComponent(relativePath)
        try writeAccountFile(
            fileURL: fileURL,
            relativeAuthPath: relativePath,
            authJSONString: authJSONString,
            preferredId: UUID(),
            preferredName: name,
            preferredCreatedAt: Date()
        )
        return try loadAccount(fileURL: fileURL, relativeAuthPath: relativePath)
    }

    func deleteAccount(id: UUID) async throws {
        let accounts = try await loadAccounts()
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        let fileURL = accountAuthFileURL(account)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Accounts (folder-backed)

    private func loadAccountsFromAuthFolder() throws -> [CodexAuthAccount] {
        let folderURL = nolonCodexAuthFolderURL()
        guard FileManager.default.fileExists(atPath: folderURL.path) else { return [] }

        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var accounts: [CodexAuthAccount] = []
        accounts.reserveCapacity(urls.count)

        for url in urls where url.pathExtension.lowercased() == "json" {
            let relativeAuthPath = "auth/\(url.lastPathComponent)"
            do {
                let account = try loadAccount(fileURL: url, relativeAuthPath: relativeAuthPath)
                accounts.append(account)
            } catch {
                Self.logger.error("Failed to load Codex account file: \(url.lastPathComponent, privacy: .public) error: \(String(describing: error), privacy: .public)")
            }
        }

        accounts.sort(by: { $0.createdAt > $1.createdAt })
        return accounts
    }

    func readAuthJSONString(from provider: Provider) throws -> String? {
        guard let fileURL = authFileURL(for: provider) else { return nil }
        guard STFile(fileURL).isExists else { return nil }
        let data = try Data(contentsOf: fileURL)
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    func readAuthJSONString(for account: CodexAuthAccount) throws -> String {
        let data = try Data(contentsOf: accountAuthFileURL(account))
        guard let raw = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return raw
    }

    func loadUsageCache(for account: CodexAuthAccount) throws -> CodexAuthUsageCache? {
        let data = try Data(contentsOf: accountAuthFileURL(account))
        guard !data.isEmpty else { return nil }

        guard let json = try? JSON(data: data) else { return nil }
        let cacheJSON = json["nolon"]["usage_cache"]
        guard cacheJSON != JSON.null else { return nil }
        guard let cacheData = try? cacheJSON.rawData() else { return nil }
        return try CodexAuthUsageCache.jsonDecoder().decode(CodexAuthUsageCache.self, from: cacheData)
    }

    func storeUsageCache(_ cache: CodexAuthUsageCache, for account: CodexAuthAccount) throws {
        let url = accountAuthFileURL(account)
        var rootJSON: JSON
        if let data = try? Data(contentsOf: url),
           let json = try? JSON(data: data) {
            rootJSON = json
        } else {
            rootJSON = JSON([:])
        }

        if rootJSON["nolon"].dictionary == nil {
            rootJSON["nolon"] = JSON([:])
        }

        let data = try CodexAuthUsageCache.jsonEncoder().encode(cache)
        let cacheJSON = try JSON(data: data)
        rootJSON["nolon"]["usage_cache"] = cacheJSON

        guard let raw = rootJSON.rawString() else { return }
        try raw.write(to: url, atomically: true, encoding: .utf8)
    }

    func currentAuthHashHex(for provider: Provider) -> String? {
        guard let raw = try? readAuthJSONString(from: provider) else { return nil }
        return CodexAuthAccount.hashHex(for: raw)
    }

    func activeAccountId(for provider: Provider) async -> UUID? {
        guard let authURL = authFileURL(for: provider) else { return nil }
        let accounts = (try? await loadAccounts()) ?? []

        // Symlink form (older behavior / user created): resolve target and match by file URL.
        if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: authURL.path) {
            let resolved: URL
            if destination.hasPrefix("/") {
                resolved = URL(fileURLWithPath: destination)
            } else {
                resolved = authURL.deletingLastPathComponent().appendingPathComponent(destination)
            }

            for account in accounts {
                if accountAuthFileURL(account).standardizedFileURL == resolved.standardizedFileURL {
                    return account.id
                }
            }
        }

        // Regular file: match by cleaned content (ignore Nolon metadata).
        guard let currentData = try? Data(contentsOf: authURL),
              !currentData.isEmpty
        else { return nil }

        let currentClean = Self.cleanedAuthJSONData(from: currentData) ?? currentData
        for account in accounts {
            let url = accountAuthFileURL(account)
            guard let data = try? Data(contentsOf: url),
                  !data.isEmpty
            else { continue }

            let clean = Self.cleanedAuthJSONData(from: data) ?? data
            if clean == currentClean {
                return account.id
            }
        }

        return nil
    }

    /// Sync token fields from the active `~/.codex/auth.json` into the matching snapshot under `~/.nolon/codex/auth/`.
    /// Returns the updated snapshot URL when a change is applied.
    func syncActiveAuthTokensIfNeeded(for provider: Provider) async -> URL? {
        guard let authURL = authFileURL(for: provider) else { return nil }
        guard FileManager.default.fileExists(atPath: authURL.path) else { return nil }

        let authData: Data
        do {
            authData = try Data(contentsOf: authURL)
        } catch {
            return nil
        }
        guard !authData.isEmpty,
              let authJSON = try? JSON(data: authData)
        else { return nil }

        let accounts = (try? await loadAccounts()) ?? []
        guard !accounts.isEmpty else { return nil }

        // If the active auth is a symlink to a snapshot, it is already in sync.
        if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: authURL.path) {
            let resolved: URL
            if destination.hasPrefix("/") {
                resolved = URL(fileURLWithPath: destination)
            } else {
                resolved = authURL.deletingLastPathComponent().appendingPathComponent(destination)
            }
            if accounts.contains(where: { accountAuthFileURL($0).standardizedFileURL == resolved.standardizedFileURL }) {
                return nil
            }
        }

        guard let target = matchAccount(for: authJSON, authData: authData, accounts: accounts) else { return nil }
        let targetURL = accountAuthFileURL(target)
        guard (try? syncAuthTokens(from: authJSON, to: targetURL)) == true else { return nil }
        return targetURL
    }

    func activateAccount(_ account: CodexAuthAccount, for provider: Provider) throws {
        guard let authURL = authFileURL(for: provider) else { return }
        try FileManager.default.createDirectory(at: authURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

        // Replace existing auth.json (file or symlink) with a clean copy.
        if FileManager.default.fileExists(atPath: authURL.path) {
            try FileManager.default.removeItem(at: authURL)
        }

        let sourceURL = accountAuthFileURL(account)
        let data = try Data(contentsOf: sourceURL)
        let cleanData = Self.cleanedAuthJSONData(from: data) ?? data
        try cleanData.write(to: authURL, options: [.atomic])

        Self.logger.info("Activated Codex auth by writing clean auth.json for provider: \(provider.id, privacy: .public)")
    }

    // MARK: - CLI Login Flow

    enum CLILoginError: LocalizedError, Sendable {
        case codexHomeUnavailable
        case authFileNotFound
        case authFileInvalidEncoding

        var errorDescription: String? {
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
    func prepareForCLILogin(provider: Provider, archiveAccountName: String?) async throws {
        try await migrateLegacyIfNeeded()

        guard let codexHome = codexHomeURL(for: provider) else { throw CLILoginError.codexHomeUnavailable }
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true, attributes: nil)

        guard let authURL = authFileURL(for: provider) else { throw CLILoginError.codexHomeUnavailable }
        guard FileManager.default.fileExists(atPath: authURL.path) else { return }

        let isSymlink = (try? FileManager.default.destinationOfSymbolicLink(atPath: authURL.path)) != nil
        if isSymlink {
            // The active auth is already stored elsewhere; just detach so `codex login` can write a fresh file.
            try FileManager.default.removeItem(at: authURL)
            return
        }

        // Regular file: if it matches an existing snapshot, just detach to avoid duplicating the account.
        if await activeAccountId(for: provider) != nil {
            try FileManager.default.removeItem(at: authURL)
            return
        }

        // Regular file: snapshot it first, then remove.
        let data = try Data(contentsOf: authURL)
        guard let raw = String(data: data, encoding: .utf8) else { throw CLILoginError.authFileInvalidEncoding }

        let defaultName = deriveAccountName(fromAuthJSONString: raw)
        let name = (archiveAccountName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? defaultName
        _ = try await addAccount(name: name, authJSONString: raw)
        try FileManager.default.removeItem(at: authURL)
    }

    /// After the user finishes `codex login`, call this to snapshot the freshly created `auth.json`
    /// into `~/.nolon/codex/auth/` and then activate it as the current account.
    @discardableResult
    func finalizeCLILogin(provider: Provider, newAccountName: String) async throws -> CodexAuthAccount {
        guard let authURL = authFileURL(for: provider) else { throw CLILoginError.codexHomeUnavailable }
        guard FileManager.default.fileExists(atPath: authURL.path) else { throw CLILoginError.authFileNotFound }

        let data = try Data(contentsOf: authURL)
        guard let raw = String(data: data, encoding: .utf8) else { throw CLILoginError.authFileInvalidEncoding }

        let trimmed = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? deriveAccountName(fromAuthJSONString: raw) : trimmed

        let account = try await addAccount(name: name, authJSONString: raw)
        try activateAccount(account, for: provider)
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
        let legacyURL = rootURL.appendingPathComponent("codex-accounts.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        let data = try Data(contentsOf: legacyURL)
        guard !data.isEmpty else {
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let legacy = try? decoder.decode([LegacyCodexAuthAccount].self, from: data) else { return }

        var accounts: [CodexAuthAccount] = []
        try FileManager.default.createDirectory(at: nolonCodexAuthFolderURL(), withIntermediateDirectories: true, attributes: nil)

        let existing = existingAuthRelativePaths()
        var used = existing
        for item in legacy {
            let fileName = uniqueAuthFileName(for: item.name, existing: used)
            let relativePath = "auth/\(fileName)"
            let fileURL = nolonCodexRootURL().appendingPathComponent(relativePath)
            try writeAccountFile(
                fileURL: fileURL,
                relativeAuthPath: relativePath,
                authJSONString: item.authJSONString,
                preferredId: item.id,
                preferredName: item.name,
                preferredCreatedAt: item.createdAt
            )
            used.insert(relativePath)
            accounts.append(CodexAuthAccount(id: item.id, name: item.name, createdAt: item.createdAt, relativeAuthPath: relativePath))
        }

        // Keep a backup instead of deleting to be safe.
        let backupURL = rootURL.appendingPathComponent("codex-accounts.legacy.json")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.moveItem(at: legacyURL, to: backupURL)
    }

    nonisolated func deriveAccountName(fromAuthJSONString authJSONString: String) -> String {
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
}

private extension CodexAuthService {
    func existingAuthRelativePaths() -> Set<String> {
        let folderURL = nolonCodexAuthFolderURL()
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        let rels = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { "auth/\($0.lastPathComponent)" }
        return Set(rels)
    }

    func matchAccount(for authJSON: JSON, authData: Data, accounts: [CodexAuthAccount]) -> CodexAuthAccount? {
        let cleanedAuthData = Self.cleanedAuthJSONData(from: authData) ?? authData
        for account in accounts {
            let url = accountAuthFileURL(account)
            guard let data = try? Data(contentsOf: url),
                  !data.isEmpty
            else { continue }
            let cleanedAccount = Self.cleanedAuthJSONData(from: data) ?? data
            if cleanedAccount == cleanedAuthData {
                return account
            }
        }

        let authSummary = CodexAuthSummary.fromJSONData(authData)
        let authEmail = normalizedEmail(authSummary.email)
        let authSuffix = authSummary.apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var emailMatches: [CodexAuthAccount] = []
        var suffixMatches: [CodexAuthAccount] = []

        for account in accounts {
            let url = accountAuthFileURL(account)
            guard let data = try? Data(contentsOf: url),
                  !data.isEmpty
            else { continue }

            let summary = CodexAuthSummary.fromJSONData(data)
            if let authEmail,
               let email = normalizedEmail(summary.email),
               email == authEmail
            {
                emailMatches.append(account)
            }

            if let authSuffix,
               let suffix = summary.apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               suffix == authSuffix
            {
                suffixMatches.append(account)
            }
        }

        if let match = pickLatestAccount(from: emailMatches) {
            return match
        }
        return pickLatestAccount(from: suffixMatches)
    }

    func syncAuthTokens(from authJSON: JSON, to url: URL) throws -> Bool {
        let data = try Data(contentsOf: url)
        guard var rootJSON = try? JSON(data: data) else { return false }

        var changed = false

        if authJSON["tokens"].dictionary != nil {
            if rootJSON["tokens"] != authJSON["tokens"] {
                rootJSON["tokens"] = authJSON["tokens"]
                changed = true
            }
        }

        for key in Self.authTokenKeys {
            let value = authJSON[key]
            guard value != JSON.null else { continue }
            if rootJSON[key] != value {
                rootJSON[key] = value
                changed = true
            }
        }

        guard changed, let raw = rootJSON.rawString() else { return false }
        try raw.write(to: url, atomically: true, encoding: .utf8)
        return true
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

    func loadAccount(fileURL url: URL, relativeAuthPath: String) throws -> CodexAuthAccount {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard var rootJSON = try? JSON(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fallbackCreatedAt = (fileAttributes?[.creationDate] as? Date)
            ?? (fileAttributes?[.modificationDate] as? Date)
            ?? Date()

        var changed = false

        if rootJSON["nolon"].dictionary == nil {
            rootJSON["nolon"] = JSON([:])
            changed = true
        }
        if rootJSON["nolon"]["account"].dictionary == nil {
            rootJSON["nolon"]["account"] = JSON([:])
            changed = true
        }

        let existingId = rootJSON["nolon"]["account"]["id"].string.flatMap(UUID.init(uuidString:))
        let id = existingId ?? UUID()
        if existingId == nil {
            rootJSON["nolon"]["account"]["id"] = JSON(id.uuidString)
            changed = true
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let existingCreatedAt = rootJSON["nolon"]["account"]["createdAt"].string.flatMap { iso.date(from: $0) }
        let createdAt = existingCreatedAt ?? fallbackCreatedAt
        if existingCreatedAt == nil {
            rootJSON["nolon"]["account"]["createdAt"] = JSON(iso.string(from: createdAt))
            changed = true
        }

        let derivedEmail = deriveEmail(from: rootJSON)
        let existingEmail = rootJSON["nolon"]["account"]["email"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (existingEmail?.isEmpty == false ? existingEmail : nil) ?? derivedEmail

        if let email, (existingEmail == nil || existingEmail?.isEmpty == true) {
            rootJSON["nolon"]["account"]["email"] = JSON(email)
            changed = true
        }
        let topEmail = rootJSON["email"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, (topEmail == nil || topEmail?.isEmpty == true) {
            rootJSON["email"] = JSON(email)
            changed = true
        }

        let existingName = rootJSON["nolon"]["account"]["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (existingName?.isEmpty == false ? existingName : nil)
            ?? email
            ?? deriveAccountName(fromAuthJSONString: String(data: data, encoding: .utf8) ?? "")

        if existingName == nil || existingName?.isEmpty == true {
            rootJSON["nolon"]["account"]["name"] = JSON(name)
            changed = true
        }

        if changed, let raw = rootJSON.rawString() {
            try raw.write(to: url, atomically: true, encoding: .utf8)
        }

        return CodexAuthAccount(id: id, name: name, createdAt: createdAt, relativeAuthPath: relativeAuthPath)
    }

    func writeAccountFile(
        fileURL: URL,
        relativeAuthPath: String,
        authJSONString: String,
        preferredId: UUID,
        preferredName: String,
        preferredCreatedAt: Date
    ) throws {
        guard let data = authJSONString.data(using: .utf8),
              var rootJSON = try? JSON(data: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        if rootJSON["nolon"].dictionary == nil {
            rootJSON["nolon"] = JSON([:])
        }
        if rootJSON["nolon"]["account"].dictionary == nil {
            rootJSON["nolon"]["account"] = JSON([:])
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        rootJSON["nolon"]["account"]["id"] = JSON(preferredId.uuidString)
        rootJSON["nolon"]["account"]["name"] = JSON(preferredName)
        rootJSON["nolon"]["account"]["createdAt"] = JSON(iso.string(from: preferredCreatedAt))
        rootJSON["nolon"]["account"]["relativeAuthPath"] = JSON(relativeAuthPath)

        if let email = deriveEmail(from: rootJSON) {
            if rootJSON["nolon"]["account"]["email"].string == nil {
                rootJSON["nolon"]["account"]["email"] = JSON(email)
            }
            if rootJSON["email"].string == nil {
                rootJSON["email"] = JSON(email)
            }
        }

        guard let raw = rootJSON.rawString() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try raw.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func migrateLegacyIndexFileIfNeeded() throws {
        let rootURL = nolonCodexRootURL()
        let candidates = [
            rootURL.appendingPathComponent("account.json"),
            rootURL.appendingPathComponent("accounts.json"),
        ]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            let data = (try? Data(contentsOf: url)) ?? Data()
            guard !data.isEmpty else {
                try? FileManager.default.removeItem(at: url)
                continue
            }

            guard let accounts = try? decoder.decode([CodexAuthAccount].self, from: data) else {
                try? FileManager.default.removeItem(at: url)
                continue
            }

            for account in accounts {
                let fileURL = accountAuthFileURL(relativeAuthPath: account.relativeAuthPath)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                do {
                    try ensureAccountMetadata(
                        for: fileURL,
                        relativeAuthPath: account.relativeAuthPath,
                        preferredId: account.id,
                        preferredName: account.name,
                        preferredCreatedAt: account.createdAt
                    )
                } catch {
                    Self.logger.error("Failed to migrate Codex account index entry: \(account.relativeAuthPath, privacy: .public) error: \(String(describing: error), privacy: .public)")
                }
            }

            try? FileManager.default.removeItem(at: url)
        }
    }

    func ensureAccountMetadata(
        for url: URL,
        relativeAuthPath: String,
        preferredId: UUID,
        preferredName: String,
        preferredCreatedAt: Date
    ) throws {
        let data = try Data(contentsOf: url)
        guard var rootJSON = try? JSON(data: data) else { return }

        var changed = false
        if rootJSON["nolon"].dictionary == nil {
            rootJSON["nolon"] = JSON([:])
            changed = true
        }
        if rootJSON["nolon"]["account"].dictionary == nil {
            rootJSON["nolon"]["account"] = JSON([:])
            changed = true
        }

        if rootJSON["nolon"]["account"]["id"].string == nil {
            rootJSON["nolon"]["account"]["id"] = JSON(preferredId.uuidString)
            changed = true
        }
        if rootJSON["nolon"]["account"]["name"].string == nil {
            rootJSON["nolon"]["account"]["name"] = JSON(preferredName)
            changed = true
        }
        if rootJSON["nolon"]["account"]["createdAt"].string == nil {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            rootJSON["nolon"]["account"]["createdAt"] = JSON(iso.string(from: preferredCreatedAt))
            changed = true
        }
        if rootJSON["nolon"]["account"]["relativeAuthPath"].string == nil {
            rootJSON["nolon"]["account"]["relativeAuthPath"] = JSON(relativeAuthPath)
            changed = true
        }

        if let email = deriveEmail(from: rootJSON) {
            if rootJSON["nolon"]["account"]["email"].string == nil {
                rootJSON["nolon"]["account"]["email"] = JSON(email)
                changed = true
            }
            if rootJSON["email"].string == nil {
                rootJSON["email"] = JSON(email)
                changed = true
            }
        }

        if changed, let raw = rootJSON.rawString() {
            try raw.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func deriveEmail(from authJSON: JSON) -> String? {
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

    func decodeEmail(fromJWT jwt: String) -> String? {
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

    func base64URLDecode(_ string: String) -> Data? {
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
