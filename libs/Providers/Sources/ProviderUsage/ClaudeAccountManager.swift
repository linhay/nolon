import Foundation
import STFilePath
import ProviderCatalog
import SKProcessRunner
import ProvidersShared
import SQLite3

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

    public nonisolated func accountsSQLiteFile() -> STFile {
        rootFolder.file("nolon.sqlite3")
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
        return try loadAccountsFromSQLite()
    }

    public func saveAccounts(_ accounts: [ClaudeAccount]) throws {
        try ensureStorage()
        try saveAccountsToSQLite(accounts)
    }

    public func activeAccountID() throws -> UUID? {
        try ensureStorage()
        return try activeAccountIDFromSQLite()
    }

    public func setActiveAccountID(_ accountID: UUID?) throws {
        try ensureStorage()
        try setActiveAccountIDToSQLite(accountID)
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
        let modelValues = Self.resolveClaudeModels(
            model: Self.stringValue(env["ANTHROPIC_MODEL"]),
            reasoning: Self.stringValue(env["ANTHROPIC_REASONING_MODEL"]),
            haiku: Self.stringValue(env["ANTHROPIC_DEFAULT_HAIKU_MODEL"]),
            sonnet: Self.stringValue(env["ANTHROPIC_DEFAULT_SONNET_MODEL"]),
            opus: Self.stringValue(env["ANTHROPIC_DEFAULT_OPUS_MODEL"]),
            smallFast: Self.stringValue(env["ANTHROPIC_SMALL_FAST_MODEL"])
        )

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
                anthropicModel: modelValues.model,
                anthropicReasoningModel: modelValues.reasoning,
                anthropicDefaultHaikuModel: modelValues.haiku,
                anthropicDefaultSonnetModel: modelValues.sonnet,
                anthropicDefaultOpusModel: modelValues.opus,
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
            let (_, response) = try await dataWithInvalidReuseRetry(request: request)
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

    static func isInvalidReuseAfterInitializationFailure(error: Error) -> Bool {
        if containsInvalidReuseMarker(in: error.localizedDescription) {
            return true
        }

        let nsError = error as NSError
        if let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
           containsInvalidReuseMarker(in: description) {
            return true
        }
        if let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           containsInvalidReuseMarker(in: failureReason) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isInvalidReuseAfterInitializationFailure(error: underlying)
        }

        return false
    }

    private static func containsInvalidReuseMarker(in text: String) -> Bool {
        text.lowercased().contains("invalid reuse after initialization failure")
    }

    private static func dataWithInvalidReuseRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            guard isInvalidReuseAfterInitializationFailure(error: error) else {
                throw error
            }

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            return try await session.data(for: request)
        }
    }

    // MARK: - Private

    private func ensureStorage() throws {
        _ = claudeDataFolder().createIfNotExists()
        let dbURL = accountsSQLiteFile().url
        try ensureClaudeAccountsSQLiteSchema(databaseURL: dbURL)
        try migrateJSONSnapshotsToSQLiteIfNeeded(databaseURL: dbURL)
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
        env["ANTHROPIC_MODEL"] = account.anthropicModel
        if account.anthropicReasoningModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            env.removeValue(forKey: "ANTHROPIC_REASONING_MODEL")
        } else {
            env["ANTHROPIC_REASONING_MODEL"] = account.anthropicReasoningModel
        }
        env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = account.anthropicDefaultHaikuModel
        env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = account.anthropicDefaultSonnetModel
        env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = account.anthropicDefaultOpusModel
        env.removeValue(forKey: "ANTHROPIC_SMALL_FAST_MODEL")
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
            anthropicModel: new.anthropicModel,
            anthropicReasoningModel: new.anthropicReasoningModel,
            anthropicDefaultHaikuModel: new.anthropicDefaultHaikuModel,
            anthropicDefaultSonnetModel: new.anthropicDefaultSonnetModel,
            anthropicDefaultOpusModel: new.anthropicDefaultOpusModel,
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
        let modelValues = resolveClaudeModels(
            model: firstNonEmptyString([
                stringValue(env?["ANTHROPIC_MODEL"]),
                stringValue(root["ANTHROPIC_MODEL"]),
            ]),
            reasoning: firstNonEmptyString([
                stringValue(env?["ANTHROPIC_REASONING_MODEL"]),
                stringValue(root["ANTHROPIC_REASONING_MODEL"]),
            ]),
            haiku: firstNonEmptyString([
                stringValue(env?["ANTHROPIC_DEFAULT_HAIKU_MODEL"]),
                stringValue(root["ANTHROPIC_DEFAULT_HAIKU_MODEL"]),
            ]),
            sonnet: firstNonEmptyString([
                stringValue(env?["ANTHROPIC_DEFAULT_SONNET_MODEL"]),
                stringValue(root["ANTHROPIC_DEFAULT_SONNET_MODEL"]),
            ]),
            opus: firstNonEmptyString([
                stringValue(env?["ANTHROPIC_DEFAULT_OPUS_MODEL"]),
                stringValue(root["ANTHROPIC_DEFAULT_OPUS_MODEL"]),
            ]),
            smallFast: firstNonEmptyString([
                stringValue(env?["ANTHROPIC_SMALL_FAST_MODEL"]),
                stringValue(root["ANTHROPIC_SMALL_FAST_MODEL"]),
            ])
        )
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
            anthropicModel: modelValues.model,
            anthropicReasoningModel: modelValues.reasoning,
            anthropicDefaultHaikuModel: modelValues.haiku,
            anthropicDefaultSonnetModel: modelValues.sonnet,
            anthropicDefaultOpusModel: modelValues.opus,
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

    private static func resolveClaudeModels(
        model: String?,
        reasoning: String?,
        haiku: String?,
        sonnet: String?,
        opus: String?,
        smallFast: String?
    ) -> (model: String, reasoning: String, haiku: String, sonnet: String, opus: String) {
        let normalizedModel = firstNonEmptyString([model]) ?? ClaudeAccount.defaultAnthropicModel
        let normalizedReasoning = firstNonEmptyString([reasoning]) ?? ClaudeAccount.defaultAnthropicReasoningModel
        let normalizedSmallFast = firstNonEmptyString([smallFast])
        let normalizedHaiku = firstNonEmptyString([haiku, normalizedSmallFast, normalizedModel]) ?? ClaudeAccount.defaultAnthropicDefaultHaikuModel
        let normalizedSonnet = firstNonEmptyString([sonnet, normalizedModel, normalizedSmallFast]) ?? ClaudeAccount.defaultAnthropicDefaultSonnetModel
        let normalizedOpus = firstNonEmptyString([opus, normalizedModel, normalizedSmallFast]) ?? ClaudeAccount.defaultAnthropicDefaultOpusModel
        return (model: normalizedModel, reasoning: normalizedReasoning, haiku: normalizedHaiku, sonnet: normalizedSonnet, opus: normalizedOpus)
    }

    private nonisolated var sqliteTransientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private nonisolated func ensureClaudeAccountsSQLiteSchema(databaseURL: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Claude accounts SQLite database." : message,
            ])
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 5_000)
        _ = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)

        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS claude_accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                credential_type TEXT NOT NULL,
                credential_value TEXT NOT NULL,
                base_url TEXT NOT NULL,
                anthropic_model TEXT NOT NULL,
                anthropic_reasoning_model TEXT NOT NULL,
                anthropic_default_haiku_model TEXT NOT NULL,
                anthropic_default_sonnet_model TEXT NOT NULL,
                anthropic_default_opus_model TEXT NOT NULL,
                source TEXT NOT NULL,
                usage_query_json TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                last_validated_at TEXT,
                last_validation_status INTEGER
            );
            """
        )

        try executeSQLite(
            db,
            sql: """
            CREATE TABLE IF NOT EXISTS claude_active_accounts (
                scope TEXT PRIMARY KEY,
                account_id TEXT,
                updated_at TEXT NOT NULL
            );
            """
        )

        let now = ISO8601DateFormatter().string(from: Date())
        try executeSQLite(
            db,
            sql: """
            INSERT INTO claude_active_accounts(scope, account_id, updated_at)
            VALUES (?, NULL, ?)
            ON CONFLICT(scope) DO NOTHING;
            """,
            binds: ["default", now]
        )

        try executeSQLite(
            db,
            sql: """
            CREATE INDEX IF NOT EXISTS idx_claude_accounts_updated_at
            ON claude_accounts(updated_at DESC);
            """
        )

        try ensureSQLiteColumnExists(
            db,
            table: "claude_accounts",
            column: "anthropic_model",
            definition: "TEXT NOT NULL DEFAULT 'gpt-5'"
        )
        try ensureSQLiteColumnExists(
            db,
            table: "claude_accounts",
            column: "anthropic_default_haiku_model",
            definition: "TEXT NOT NULL DEFAULT 'gpt-5(minimal)'"
        )
        try ensureSQLiteColumnExists(
            db,
            table: "claude_accounts",
            column: "anthropic_reasoning_model",
            definition: "TEXT NOT NULL DEFAULT ''"
        )
        try ensureSQLiteColumnExists(
            db,
            table: "claude_accounts",
            column: "anthropic_default_sonnet_model",
            definition: "TEXT NOT NULL DEFAULT 'gpt-5(medium)'"
        )
        try ensureSQLiteColumnExists(
            db,
            table: "claude_accounts",
            column: "anthropic_default_opus_model",
            definition: "TEXT NOT NULL DEFAULT 'gpt-5(high)'"
        )
    }

    private nonisolated func executeSQLite(
        _ db: OpaquePointer?,
        sql: String,
        binds: [String?] = []
    ) throws {
        var statement: OpaquePointer?
        let prepareCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareCode == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(prepareCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "SQLite prepare failed." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        for (index, bind) in binds.enumerated() {
            let position = Int32(index + 1)
            if let bind {
                guard sqlite3_bind_text(statement, position, bind, -1, sqliteTransientDestructor) == SQLITE_OK else {
                    let code = sqlite3_errcode(db)
                    let message = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(code), userInfo: [
                        NSLocalizedDescriptionKey: message.isEmpty ? "SQLite bind failed." : message,
                    ])
                }
            } else {
                guard sqlite3_bind_null(statement, position) == SQLITE_OK else {
                    let code = sqlite3_errcode(db)
                    let message = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(code), userInfo: [
                        NSLocalizedDescriptionKey: message.isEmpty ? "SQLite bind null failed." : message,
                    ])
                }
            }
        }

        let stepCode = sqlite3_step(statement)
        guard stepCode == SQLITE_DONE || stepCode == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(stepCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "SQLite execution failed." : message,
            ])
        }
    }

    private nonisolated func ensureSQLiteColumnExists(
        _ db: OpaquePointer?,
        table: String,
        column: String,
        definition: String
    ) throws {
        guard try sqliteTableColumnExists(db, table: table, column: column) == false else { return }
        try executeSQLite(db, sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
    }

    private nonisolated func sqliteTableColumnExists(
        _ db: OpaquePointer?,
        table: String,
        column: String
    ) throws -> Bool {
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        let prepareCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareCode == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(prepareCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to inspect SQLite table." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let name = sqliteColumnText(statement, index: 1) else { continue }
            if name == column { return true }
        }
        return false
    }

    private func migrateJSONSnapshotsToSQLiteIfNeeded(databaseURL: URL) throws {
        let existingAccounts = try loadAccountsFromSQLite()
        if !existingAccounts.isEmpty {
            return
        }

        var jsonAccounts: [ClaudeAccount] = []
        if accountsFile().isExists {
            let data = try accountsFile().data()
            if !data.isEmpty, let decoded = try? JSONDecoder().decode(AccountsSnapshot.self, from: data) {
                jsonAccounts = decoded.accounts
            }
        }
        if !jsonAccounts.isEmpty {
            try saveAccountsToSQLite(jsonAccounts)
        }

        if let activeFromJSON = try readActiveAccountIDFromJSON() {
            try setActiveAccountIDToSQLite(activeFromJSON)
        }
    }

    private func readActiveAccountIDFromJSON() throws -> UUID? {
        guard activeAccountFile().isExists else { return nil }
        let data = try activeAccountFile().data()
        guard !data.isEmpty else { return nil }
        return try JSONDecoder().decode(ActiveAccountSnapshot.self, from: data).accountID
    }

    private func loadAccountsFromSQLite() throws -> [ClaudeAccount] {
        var db: OpaquePointer?
        let dbURL = accountsSQLiteFile().url
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "ClaudeAccountManager.SQLiteRead", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open SQLite database for Claude account read." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT id, name, credential_type, credential_value, base_url,
               anthropic_model, anthropic_reasoning_model, anthropic_default_haiku_model, anthropic_default_sonnet_model, anthropic_default_opus_model,
               source, usage_query_json, created_at, updated_at, last_validated_at, last_validation_status
        FROM claude_accounts
        ORDER BY datetime(updated_at) DESC, datetime(created_at) DESC, id ASC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ClaudeAccountManager.SQLiteRead", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare SQLite query for Claude accounts." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        var results: [ClaudeAccount] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idRaw = sqliteColumnText(statement, index: 0),
                let id = UUID(uuidString: idRaw),
                let name = sqliteColumnText(statement, index: 1),
                let credentialTypeRaw = sqliteColumnText(statement, index: 2),
                let credentialType = ClaudeCredentialType(rawValue: credentialTypeRaw),
                let credentialValue = sqliteColumnText(statement, index: 3),
                let baseURL = sqliteColumnText(statement, index: 4),
                let sourceRaw = sqliteColumnText(statement, index: 10),
                let source = ClaudeAccountSource(rawValue: sourceRaw),
                let createdAtRaw = sqliteColumnText(statement, index: 12),
                let createdAt = parseSQLiteDate(createdAtRaw),
                let updatedAtRaw = sqliteColumnText(statement, index: 13),
                let updatedAt = parseSQLiteDate(updatedAtRaw)
            else {
                continue
            }

            let modelValues = Self.resolveClaudeModels(
                model: sqliteColumnText(statement, index: 5),
                reasoning: sqliteColumnText(statement, index: 6),
                haiku: sqliteColumnText(statement, index: 7),
                sonnet: sqliteColumnText(statement, index: 8),
                opus: sqliteColumnText(statement, index: 9),
                smallFast: nil
            )
            let usageQuery: CodexHTTPUsageQuery? = {
                guard let raw = sqliteColumnText(statement, index: 11), !raw.isEmpty else { return nil }
                guard let data = raw.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(CodexHTTPUsageQuery.self, from: data)
            }()
            let lastValidatedAt: Date? = {
                guard let raw = sqliteColumnText(statement, index: 14), !raw.isEmpty else { return nil }
                return parseSQLiteDate(raw)
            }()
            let lastValidationStatus: Bool? = {
                guard sqlite3_column_type(statement, 15) != SQLITE_NULL else { return nil }
                return sqlite3_column_int(statement, 15) != 0
            }()

            results.append(
                ClaudeAccount(
                    id: id,
                    name: name,
                    credentialType: credentialType,
                    credentialValue: credentialValue,
                    baseURL: baseURL,
                    anthropicModel: modelValues.model,
                    anthropicReasoningModel: modelValues.reasoning,
                    anthropicDefaultHaikuModel: modelValues.haiku,
                    anthropicDefaultSonnetModel: modelValues.sonnet,
                    anthropicDefaultOpusModel: modelValues.opus,
                    source: source,
                    usageQuery: usageQuery,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    lastValidatedAt: lastValidatedAt,
                    lastValidationStatus: lastValidationStatus
                )
            )
        }

        return results
    }

    private func saveAccountsToSQLite(_ accounts: [ClaudeAccount]) throws {
        var db: OpaquePointer?
        let dbURL = accountsSQLiteFile().url
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "ClaudeAccountManager.SQLiteWrite", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open SQLite database for Claude account write." : message,
            ])
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 5_000)
        try executeSQLite(db, sql: "BEGIN IMMEDIATE;")
        do {
            try executeSQLite(
                db,
                sql: """
                INSERT INTO claude_accounts (
                    id, name, credential_type, credential_value, base_url,
                    anthropic_model, anthropic_reasoning_model, anthropic_default_haiku_model, anthropic_default_sonnet_model, anthropic_default_opus_model,
                    source, usage_query_json, created_at, updated_at, last_validated_at, last_validation_status
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    credential_type = excluded.credential_type,
                    credential_value = excluded.credential_value,
                    base_url = excluded.base_url,
                    anthropic_model = excluded.anthropic_model,
                    anthropic_reasoning_model = excluded.anthropic_reasoning_model,
                    anthropic_default_haiku_model = excluded.anthropic_default_haiku_model,
                    anthropic_default_sonnet_model = excluded.anthropic_default_sonnet_model,
                    anthropic_default_opus_model = excluded.anthropic_default_opus_model,
                    source = excluded.source,
                    usage_query_json = excluded.usage_query_json,
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at,
                    last_validated_at = excluded.last_validated_at,
                    last_validation_status = excluded.last_validation_status;
                """,
                bindRows: accounts.map { account in
                    [
                        account.id.uuidString,
                        account.name,
                        account.credentialType.rawValue,
                        account.credentialValue,
                        account.baseURL,
                        account.anthropicModel,
                        account.anthropicReasoningModel,
                        account.anthropicDefaultHaikuModel,
                        account.anthropicDefaultSonnetModel,
                        account.anthropicDefaultOpusModel,
                        account.source.rawValue,
                        encodeUsageQueryJSON(account.usageQuery),
                        formatSQLiteDate(account.createdAt),
                        formatSQLiteDate(account.updatedAt),
                        account.lastValidatedAt.map(formatSQLiteDate),
                        account.lastValidationStatus.map { $0 ? "1" : "0" },
                    ]
                }
            )

            if accounts.isEmpty {
                try executeSQLite(db, sql: "DELETE FROM claude_accounts;")
            } else {
                let placeholders = Array(repeating: "?", count: accounts.count).joined(separator: ",")
                let sql = "DELETE FROM claude_accounts WHERE id NOT IN (\(placeholders));"
                try executeSQLite(db, sql: sql, binds: accounts.map { $0.id.uuidString })
            }

            try executeSQLite(db, sql: "COMMIT;")
        } catch {
            _ = try? executeSQLite(db, sql: "ROLLBACK;")
            throw error
        }
    }

    private func activeAccountIDFromSQLite() throws -> UUID? {
        var db: OpaquePointer?
        let dbURL = accountsSQLiteFile().url
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "ClaudeAccountManager.SQLiteRead", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open SQLite database for Claude active account read." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT account_id FROM claude_active_accounts WHERE scope = 'default' LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ClaudeAccountManager.SQLiteRead", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare SQLite query for Claude active account." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let raw = sqliteColumnText(statement, index: 0), !raw.isEmpty else { return nil }
        return UUID(uuidString: raw)
    }

    private func setActiveAccountIDToSQLite(_ accountID: UUID?) throws {
        var db: OpaquePointer?
        let dbURL = accountsSQLiteFile().url
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let code = sqlite3_errcode(db)
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "ClaudeAccountManager.SQLiteWrite", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open SQLite database for Claude active account write." : message,
            ])
        }
        defer { sqlite3_close(db) }

        let now = formatSQLiteDate(Date())
        try executeSQLite(
            db,
            sql: """
            INSERT INTO claude_active_accounts(scope, account_id, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(scope) DO UPDATE SET
                account_id = excluded.account_id,
                updated_at = excluded.updated_at;
            """,
            binds: ["default", accountID?.uuidString, now]
        )
    }

    private nonisolated func sqliteColumnText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: raw)
    }

    private nonisolated func formatSQLiteDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private nonisolated func parseSQLiteDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private nonisolated func encodeUsageQueryJSON(_ usageQuery: CodexHTTPUsageQuery?) -> String? {
        guard let usageQuery else { return nil }
        guard let data = try? JSONEncoder().encode(usageQuery) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated func executeSQLite(
        _ db: OpaquePointer?,
        sql: String,
        bindRows: [[String?]]
    ) throws {
        guard !bindRows.isEmpty else { return }
        var statement: OpaquePointer?
        let prepareCode = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareCode == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(prepareCode), userInfo: [
                NSLocalizedDescriptionKey: message.isEmpty ? "SQLite prepare failed." : message,
            ])
        }
        defer { sqlite3_finalize(statement) }

        for row in bindRows {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            for (index, bind) in row.enumerated() {
                let position = Int32(index + 1)
                if let bind {
                    guard sqlite3_bind_text(statement, position, bind, -1, sqliteTransientDestructor) == SQLITE_OK else {
                        let code = sqlite3_errcode(db)
                        let message = String(cString: sqlite3_errmsg(db))
                        throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(code), userInfo: [
                            NSLocalizedDescriptionKey: message.isEmpty ? "SQLite bind failed." : message,
                        ])
                    }
                } else {
                    guard sqlite3_bind_null(statement, position) == SQLITE_OK else {
                        let code = sqlite3_errcode(db)
                        let message = String(cString: sqlite3_errmsg(db))
                        throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(code), userInfo: [
                            NSLocalizedDescriptionKey: message.isEmpty ? "SQLite bind null failed." : message,
                        ])
                    }
                }
            }

            let stepCode = sqlite3_step(statement)
            guard stepCode == SQLITE_DONE || stepCode == SQLITE_ROW else {
                let message = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "ClaudeAccountManager.SQLiteSchema", code: Int(stepCode), userInfo: [
                    NSLocalizedDescriptionKey: message.isEmpty ? "SQLite execution failed." : message,
                ])
            }
        }
    }

}
