import Foundation
import STFilePath
import ProviderCatalog
import SKProcessRunner
import ProvidersShared

public actor ClaudeAccountManager {
    private struct AccountsSnapshot: Codable, Sendable {
        var schemaVersion: Int
        var accounts: [ClaudeAccount]
    }

    private struct ActiveAccountSnapshot: Codable, Sendable {
        var accountID: UUID?
    }

    private struct CCSwitchProviderRow: Codable, Sendable {
        var id: String
        var name: String
        var settingsConfig: String
        var createdAt: Int64?
    }

    public typealias ValidationAction = @Sendable (ClaudeAccount) async -> ClaudeAccountValidationResult

    private static let currentSchemaVersion = 1
    private nonisolated let rootFolder: STFolder
    private let validationAction: ValidationAction

    public init(
        rootURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        validationAction: ValidationAction? = nil
    ) {
        if let rootURL {
            self.rootFolder = STFolder(rootURL)
        } else {
            self.rootFolder = NolonHomeEnvironment.resolveNolonHomeFolder(environment: environment)
        }
        self.validationAction = validationAction ?? { account in
            await Self.validateEffectiveness(for: account)
        }
    }

    public nonisolated func claudeDataFolder() -> STFolder {
        rootFolder.folder("claude")
    }

    public nonisolated func accountsFile() -> STFile {
        claudeDataFolder().file("accounts.json")
    }

    public nonisolated func activeAccountFile() -> STFile {
        claudeDataFolder().file("active-account.json")
    }

    public nonisolated func defaultClaudeSettingsFile() -> STFile {
        STFile("\(NSHomeDirectory())/.claude/settings.json")
    }

    public nonisolated func settingsFile(for provider: Provider?) -> STFile? {
        if let provider {
            guard provider.templateId == ProviderTemplate.claudeCode.rawValue else { return nil }
            let root = URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent()
            return STFile(root.appendingPathComponent("settings.json"))
        }
        return defaultClaudeSettingsFile()
    }

    public func loadAccounts() throws -> [ClaudeAccount] {
        try ensureStorage()
        guard accountsFile().isExists else { return [] }
        let data = try accountsFile().data()
        guard !data.isEmpty else { return [] }

        let decoded = try JSONDecoder().decode(AccountsSnapshot.self, from: data)
        return decoded.accounts
    }

    public func saveAccounts(_ accounts: [ClaudeAccount]) throws {
        try ensureStorage()
        let snapshot = AccountsSnapshot(schemaVersion: Self.currentSchemaVersion, accounts: accounts)
        try writeAccountsSnapshot(snapshot)
    }

    public func activeAccountID() throws -> UUID? {
        try ensureStorage()
        guard activeAccountFile().isExists else { return nil }
        let data = try activeAccountFile().data()
        guard !data.isEmpty else { return nil }
        return try JSONDecoder().decode(ActiveAccountSnapshot.self, from: data).accountID
    }

    public func setActiveAccountID(_ accountID: UUID?) throws {
        try ensureStorage()
        let snapshot = ActiveAccountSnapshot(accountID: accountID)
        try writeActiveAccountSnapshot(snapshot)
    }

    @discardableResult
    public func addAccount(
        name: String,
        credentialType: ClaudeCredentialType,
        credentialValue: String,
        baseURL: String,
        source: ClaudeAccountSource,
        usageQuery: CodexHTTPUsageQuery? = nil
    ) throws -> ClaudeAccount {
        var accounts = try loadAccounts()
        let now = Date()
        let account = ClaudeAccount(
            name: sanitizedName(name, baseURL: baseURL),
            credentialType: credentialType,
            credentialValue: credentialValue.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: normalizedBaseURL(baseURL),
            source: source,
            usageQuery: usageQuery,
            createdAt: now,
            updatedAt: now
        )
        accounts.append(account)
        try saveAccounts(accounts)
        return account
    }

    public func updateAccount(_ account: ClaudeAccount) throws {
        var accounts = try loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        var updated = account
        updated.name = sanitizedName(account.name, baseURL: account.baseURL)
        updated.baseURL = normalizedBaseURL(account.baseURL)
        updated.credentialValue = account.credentialValue.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()
        accounts[index] = updated
        try saveAccounts(accounts)
    }

    public func deleteAccount(id: UUID) throws {
        var accounts = try loadAccounts()
        accounts.removeAll { $0.id == id }
        try saveAccounts(accounts)
        if try activeAccountID() == id {
            try setActiveAccountID(nil)
        }
    }

    @discardableResult
    public func activateAccount(id: UUID, provider: Provider?) async throws -> ClaudeAccount {
        var accounts = try loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "ClaudeAccountManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Claude account not found."])
        }
        let account = accounts[index]
        try writeAccountToClaudeSettings(account: account, provider: provider)
        try setActiveAccountID(id)
        let validation = await validationAction(account)
        var updated = account
        updated.lastValidatedAt = validation.validatedAt
        updated.lastValidationStatus = validation.isEffective
        updated.updatedAt = Date()
        accounts[index] = updated
        try saveAccounts(accounts)
        return updated
    }

    @discardableResult
    public func importFromCurrentSettings(provider: Provider?) throws -> ClaudeAccount? {
        guard let settingsFile = settingsFile(for: provider), settingsFile.isExists else { return nil }
        let data = try settingsFile.data()
        guard !data.isEmpty else { return nil }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any],
              let env = root["env"] as? [String: Any]
        else {
            return nil
        }

        let rawToken = Self.stringValue(env["ANTHROPIC_AUTH_TOKEN"])
        let rawAPIKey = Self.stringValue(env["ANTHROPIC_API_KEY"])
        let rawBaseURL = Self.stringValue(env["ANTHROPIC_BASE_URL"])

        guard let baseURL = rawBaseURL, !baseURL.isEmpty else { return nil }

        let credentialType: ClaudeCredentialType
        let credentialValue: String
        if let token = rawToken, !token.isEmpty {
            credentialType = .authToken
            credentialValue = token
        } else if let apiKey = rawAPIKey, !apiKey.isEmpty {
            credentialType = .apiKey
            credentialValue = apiKey
        } else {
            return nil
        }

        return try importSingleCandidate(
            candidate: ClaudeAccount(
                name: Self.defaultName(baseURL: baseURL, suffixSeed: credentialValue),
                credentialType: credentialType,
                credentialValue: credentialValue,
                baseURL: normalizedBaseURL(baseURL),
                source: .migrated
            )
        )
    }

    public func importFromCCSwitch(dbURL: URL? = nil) async throws -> ClaudeCCSwitchImportReport {
        let resolved = resolvedCCSwitchDatabaseURL(explicit: dbURL)
        guard let resolved, STFile(resolved).isExists else {
            return ClaudeCCSwitchImportReport(totalCandidates: 0, importedCount: 0, replacedCount: 0, skippedCount: 0)
        }

        let rows = try queryCCSwitchClaudeProviders(dbURL: resolved)
        var candidates: [ClaudeAccount] = []
        candidates.reserveCapacity(rows.count)

        for row in rows {
            guard let candidate = Self.parseCCSwitchCandidate(row: row) else { continue }
            candidates.append(candidate)
        }

        var importedCount = 0
        var replacedCount = 0
        var skippedCount = 0

        for candidate in candidates {
            let result = try await importSingleCandidateWithResult(candidate: candidate)
            switch result {
            case .imported:
                importedCount += 1
            case .replaced:
                replacedCount += 1
            case .skipped:
                skippedCount += 1
            }
        }

        return ClaudeCCSwitchImportReport(
            totalCandidates: candidates.count,
            importedCount: importedCount,
            replacedCount: replacedCount,
            skippedCount: skippedCount
        )
    }

    public static func validateEffectiveness(for account: ClaudeAccount) async -> ClaudeAccountValidationResult {
        let validatedAt = Date()
        guard let endpoint = Self.messagesEndpoint(baseURL: account.baseURL) else {
            return ClaudeAccountValidationResult(isEffective: false, statusCode: nil, message: "Invalid base URL", validatedAt: validatedAt)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        switch account.credentialType {
        case .authToken:
            request.setValue(account.credentialValue, forHTTPHeaderField: "x-api-key")
        case .apiKey:
            request.setValue(account.credentialValue, forHTTPHeaderField: "x-api-key")
        }
        request.httpBody = Data("{}".utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ClaudeAccountValidationResult(isEffective: false, statusCode: nil, message: "Non-HTTP response", validatedAt: validatedAt)
            }
            let status = http.statusCode
            let isEffective = (200 ... 499).contains(status) && status != 401 && status != 403
            return ClaudeAccountValidationResult(
                isEffective: isEffective,
                statusCode: status,
                message: "HTTP \(status)",
                validatedAt: validatedAt
            )
        } catch {
            return ClaudeAccountValidationResult(isEffective: false, statusCode: nil, message: error.localizedDescription, validatedAt: validatedAt)
        }
    }

    // MARK: - Private

    private func ensureStorage() throws {
        _ = claudeDataFolder().createIfNotExists()
        if !accountsFile().isExists {
            let snapshot = AccountsSnapshot(schemaVersion: Self.currentSchemaVersion, accounts: [])
            try writeAccountsSnapshot(snapshot)
        }
        if !activeAccountFile().isExists {
            let snapshot = ActiveAccountSnapshot(accountID: nil)
            try writeActiveAccountSnapshot(snapshot)
        }
    }

    private func writeAccountsSnapshot(_ snapshot: AccountsSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try accountsFile().overlay(with: encoder.encode(snapshot))
    }

    private func writeActiveAccountSnapshot(_ snapshot: ActiveAccountSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try activeAccountFile().overlay(with: encoder.encode(snapshot))
    }

    private func writeAccountToClaudeSettings(account: ClaudeAccount, provider: Provider?) throws {
        guard let file = settingsFile(for: provider) else { return }
        _ = file.parentFolder()?.createIfNotExists()

        let existingObject: [String: Any]
        if file.isExists, let data = try? file.data(), !data.isEmpty,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            existingObject = json
        } else {
            existingObject = [:]
        }

        var merged = existingObject
        var env = (merged["env"] as? [String: Any]) ?? [:]
        env["ANTHROPIC_BASE_URL"] = normalizedBaseURL(account.baseURL)
        switch account.credentialType {
        case .authToken:
            env["ANTHROPIC_AUTH_TOKEN"] = account.credentialValue
            env.removeValue(forKey: "ANTHROPIC_API_KEY")
        case .apiKey:
            env["ANTHROPIC_API_KEY"] = account.credentialValue
            env.removeValue(forKey: "ANTHROPIC_AUTH_TOKEN")
        }
        merged["env"] = env

        let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try file.overlay(with: data)
    }

    private enum ImportOutcome {
        case imported
        case replaced
        case skipped
    }

    @discardableResult
    private func importSingleCandidate(candidate: ClaudeAccount) throws -> ClaudeAccount {
        var accounts = try loadAccounts()
        if let existingIndex = accounts.firstIndex(where: { $0.duplicateConflictKey() == candidate.duplicateConflictKey() }) {
            let existing = accounts[existingIndex]
            accounts[existingIndex] = mergePreferred(new: candidate, old: existing)
            try saveAccounts(accounts)
            return accounts[existingIndex]
        }

        accounts.append(candidate)
        try saveAccounts(accounts)
        return candidate
    }

    private func importSingleCandidateWithResult(candidate: ClaudeAccount) async throws -> ImportOutcome {
        var accounts = try loadAccounts()
        guard let existingIndex = accounts.firstIndex(where: { $0.duplicateConflictKey() == candidate.duplicateConflictKey() }) else {
            accounts.append(candidate)
            try saveAccounts(accounts)
            return .imported
        }

        let existing = accounts[existingIndex]
        let existingValidation = await validationAction(existing)
        let candidateValidation = await validationAction(candidate)

        if candidateValidation.isEffective && !existingValidation.isEffective {
            accounts[existingIndex] = mergePreferred(new: candidate, old: existing)
            accounts[existingIndex].lastValidatedAt = candidateValidation.validatedAt
            accounts[existingIndex].lastValidationStatus = candidateValidation.isEffective
            try saveAccounts(accounts)
            return .replaced
        }

        if candidateValidation.isEffective == existingValidation.isEffective,
           candidate.updatedAt > existing.updatedAt
        {
            accounts[existingIndex] = mergePreferred(new: candidate, old: existing)
            accounts[existingIndex].lastValidatedAt = candidateValidation.validatedAt
            accounts[existingIndex].lastValidationStatus = candidateValidation.isEffective
            try saveAccounts(accounts)
            return .replaced
        }

        return .skipped
    }

    private func mergePreferred(new: ClaudeAccount, old: ClaudeAccount) -> ClaudeAccount {
        ClaudeAccount(
            id: old.id,
            name: new.name,
            credentialType: new.credentialType,
            credentialValue: new.credentialValue,
            baseURL: normalizedBaseURL(new.baseURL),
            source: new.source,
            usageQuery: new.usageQuery ?? old.usageQuery,
            createdAt: old.createdAt,
            updatedAt: Date(),
            lastValidatedAt: old.lastValidatedAt,
            lastValidationStatus: old.lastValidationStatus
        )
    }

    private func normalizedBaseURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard let components = URLComponents(string: trimmed) else { return trimmed }
        var normalized = components
        normalized.query = nil
        normalized.fragment = nil
        let rendered = normalized.string ?? trimmed
        return rendered.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func sanitizedName(_ raw: String, baseURL: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return Self.defaultName(baseURL: baseURL, suffixSeed: UUID().uuidString)
    }

    private static func defaultName(baseURL: String, suffixSeed: String) -> String {
        let host = URL(string: baseURL)?.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHost = (host?.isEmpty == false ? host! : "claude")
        let suffix = suffixSeed.suffix(4)
        return "\(normalizedHost)-\(suffix)"
    }

    private static func messagesEndpoint(baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("v1/messages") {
            return url
        }
        if path.hasSuffix("v1") {
            return url.appendingPathComponent("messages")
        }
        return url.appendingPathComponent("v1").appendingPathComponent("messages")
    }

    private func queryCCSwitchClaudeProviders(dbURL: URL) throws -> [CCSwitchProviderRow] {
        let sql = """
        SELECT id, name, settings_config AS settingsConfig, created_at AS createdAt
        FROM providers
        WHERE app_type = 'claude'
        ORDER BY COALESCE(created_at, 0) ASC, id ASC;
        """
        let output = try runSQLiteJSONQuery(databasePath: dbURL.path, sql: sql)
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let data = Data(output.utf8)
        return try JSONDecoder().decode([CCSwitchProviderRow].self, from: data)
    }

    private static func parseCCSwitchCandidate(row: CCSwitchProviderRow) -> ClaudeAccount? {
        guard let configData = row.settingsConfig.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: configData),
              let root = object as? [String: Any]
        else {
            return nil
        }

        let env = extractBestCCSwitchEnvironment(from: root)
        let rawBaseURL = firstNonEmptyString([
            stringValue(env?["ANTHROPIC_BASE_URL"]),
            stringValue(root["ANTHROPIC_BASE_URL"]),
            stringValue(root["base_url"]),
            stringValue(root["baseURL"]),
            stringValue(root["apiEndpoint"]),
        ])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawBaseURL.isEmpty else { return nil }

        let authToken = firstNonEmptyString([
            stringValue(env?["ANTHROPIC_AUTH_TOKEN"]),
            stringValue(env?["OPENROUTER_API_KEY"]),
            stringValue(env?["OPENAI_API_KEY"]),
            stringValue(root["ANTHROPIC_AUTH_TOKEN"]),
            stringValue(root["OPENROUTER_API_KEY"]),
            stringValue(root["OPENAI_API_KEY"]),
        ])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = firstNonEmptyString([
            stringValue(env?["ANTHROPIC_API_KEY"]),
            stringValue(root["ANTHROPIC_API_KEY"]),
            stringValue(root["apiKey"]),
            stringValue(root["api_key"]),
        ])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentialType: ClaudeCredentialType
        let credentialValue: String
        if let authToken, !authToken.isEmpty {
            credentialType = .authToken
            credentialValue = authToken
        } else if let apiKey, !apiKey.isEmpty {
            credentialType = .apiKey
            credentialValue = apiKey
        } else {
            return nil
        }

        let createdAt = row.createdAt.map { Date(timeIntervalSince1970: TimeInterval($0 / 1000)) } ?? Date()

        return ClaudeAccount(
            name: row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultName(baseURL: rawBaseURL, suffixSeed: credentialValue) : row.name,
            credentialType: credentialType,
            credentialValue: credentialValue,
            baseURL: ClaudeAccount.normalized(urlString: rawBaseURL),
            source: .ccSwitch,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private nonisolated func runSQLiteJSONQuery(databasePath: String, sql: String) throws -> String {
        let payload = SKProcessPayload
            .command("/usr/bin/sqlite3")
            .arguments(["-json", databasePath, sql])
        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "ClaudeAccountManager.SQLite", code: Int(result.exitCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "sqlite3 query failed." : message,
            ])
        }
        return result.stdout
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private nonisolated func resolvedCCSwitchDatabaseURL(explicit: URL?) -> URL? {
        if let explicit {
            return explicit
        }

        let fileManager = FileManager.default
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let defaultURL = homeURL
            .appendingPathComponent(".cc-switch", isDirectory: true)
            .appendingPathComponent("cc-switch.db")
        if fileManager.fileExists(atPath: defaultURL.path) {
            return defaultURL
        }

        if let overrideDir = Self.detectCCSwitchAppConfigOverride(homeURL: homeURL) {
            let overrideDB = overrideDir.appendingPathComponent("cc-switch.db")
            if fileManager.fileExists(atPath: overrideDB.path) {
                return overrideDB
            }
        }

        return nil
    }

    private static func detectCCSwitchAppConfigOverride(homeURL: URL) -> URL? {
        let candidates = [
            homeURL
                .appendingPathComponent("Library/Application Support/com.ccswitch.desktop", isDirectory: true)
                .appendingPathComponent("app_paths.json"),
            homeURL
                .appendingPathComponent(".cc-switch", isDirectory: true)
                .appendingPathComponent("app_paths.json"),
        ]

        for fileURL in candidates {
            guard let data = try? Data(contentsOf: fileURL),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }
            guard let raw = stringValue(object["app_config_dir_override"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty
            else {
                continue
            }
            return expandTildePath(raw, homeURL: homeURL)
        }

        return nil
    }

    private static func expandTildePath(_ rawPath: String, homeURL: URL) -> URL {
        if rawPath == "~" {
            return homeURL
        }
        if rawPath.hasPrefix("~/") {
            return homeURL.appendingPathComponent(String(rawPath.dropFirst(2)))
        }
        return URL(fileURLWithPath: rawPath)
    }

    private static func extractBestCCSwitchEnvironment(from root: [String: Any]) -> [String: Any]? {
        if let env = root["env"] as? [String: Any], !env.isEmpty {
            return env
        }

        for (key, value) in root {
            guard key.hasSuffix(".env"), let env = value as? [String: Any], !env.isEmpty else { continue }
            return env
        }
        return nil
    }

    private static func firstNonEmptyString(_ values: [String?]) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
