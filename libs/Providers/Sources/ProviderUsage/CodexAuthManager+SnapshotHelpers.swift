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
    struct CodexAuthUsageCacheWrapper: Codable {
        let usageCache: CodexAuthUsageCache

        enum CodingKeys: String, CodingKey {
            case usageCache = "usage_cache"
        }
    }

    struct AccountSnapshot {
        let account: CodexAuthAccount
        let data: Data
        let cleanedData: Data
        let summary: CodexAuthSummary
        let apiKey: String?
        let identity: AccountIdentity
    }

    struct AccountIdentity {
        let accountID: String?
        let email: String?
        let nolonAccountID: String?
    }

    struct AuthSourceCandidate {
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
    static func decodeJSONObject(from data: Data) -> JSONObject? {
        CodexAuthManagerSupport.decodeJSONObject(from: data, decoder: jsonDecoder)
    }

    static func encodeJSONObject(_ object: JSONObject) throws -> Data {
        try CodexAuthManagerSupport.encodeJSONObject(object, encoder: jsonEncoder)
    }

    static func decodeUsageCache(from cacheObject: Any) throws -> CodexAuthUsageCache {
        let cacheData = try encodeJSONObject(["usage_cache": cacheObject])
        let wrapped = try CodexAuthUsageCache.jsonDecoder().decode(CodexAuthUsageCacheWrapper.self, from: cacheData)
        return wrapped.usageCache
    }

    static func isUsageCacheEquivalent(_ lhs: CodexAuthUsageCache, _ rhs: CodexAuthUsageCache) -> Bool {
        var left = lhs
        var right = rhs
        let referenceDate = Date(timeIntervalSince1970: 0)
        left.cachedAt = referenceDate
        right.cachedAt = referenceDate
        left.creditsRefreshedAt = nil
        right.creditsRefreshedAt = nil
        return left == right
    }

    nonisolated func resolveSymlinkTarget(for path: any STPathProtocol) -> STPath? {
        guard path.isSymbolicLink else { return nil }
        return try? path.destinationOfSymbolicLink()
    }

    nonisolated func standardizedPathString(_ path: any STPathProtocol) -> String {
        STPath.standardizedPath(path.url.path).path
    }

    func getString(_ dict: JSONObject, path: [String]) -> String? {
        CodexAuthManagerSupport.getString(dict, path: path)
    }

    func getDictionary(_ dict: JSONObject, path: [String]) -> JSONObject? {
        CodexAuthManagerSupport.getDictionary(dict, path: path)
    }

    func setValue(_ value: Any, path: [String], dict: inout JSONObject) {
        CodexAuthManagerSupport.setValue(value, path: path, dict: &dict)
    }

    func removeValue(path: [String], dict: inout JSONObject) {
        CodexAuthManagerSupport.removeValue(path: path, dict: &dict)
    }

    func encodeJSONObjectObject<T: Encodable>(_ value: T) throws -> JSONObject {
        try CodexAuthManagerSupport.encodeJSONObjectObject(value)
    }

    func loadAccountSnapshots(for accounts: [CodexAuthAccount]) -> [AccountSnapshot] {
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

    func accountIdentity(from data: Data, summary: CodexAuthSummary? = nil) -> AccountIdentity {
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

    func matchAccountByStrictIdentity(
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

    func existingAuthRelativePaths() -> Set<String> {
        let rows = (try? queryCodexAccountsRowsFromSQLite()) ?? []
        let sqlitePaths = rows.map { sqliteRelativeAuthPath(for: $0.id) }
        return Set(sqlitePaths)
    }

    func activeAccountIdFromRegistry(for provider: Provider, accounts: [CodexAuthAccount]) -> UUID? {
        let map = loadActiveAccountMap()
        guard let raw = resolveActiveAccountID(from: map, for: provider), let id = UUID(uuidString: raw) else { return nil }
        if accounts.contains(where: { $0.id == id }) {
            return id
        }
        return containsGatewayVirtualAccount(id: id) ? id : nil
    }

    func containsGatewayVirtualAccount(id: UUID) -> Bool {
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

    func loadGatewayVirtualAccount(byStandardizedPath path: String) -> CodexAuthAccount? {
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

    func isRelayProfileAccount(_ account: CodexAuthAccount) -> Bool {
        guard let data = try? readAccountAuthData(account), !data.isEmpty else { return false }
        return CodexAuthSummary.fromJSONData(data).cardKind == .relayProfile
    }

    func isGatewayVirtualAccount(_ account: CodexAuthAccount) -> Bool {
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

    func isGatewayVirtualAuthPayload(_ data: Data) -> Bool {
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

    func loadActiveAccountMap() -> [String: String] {
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

    func saveActiveAccountMap(_ map: [String: String]) throws {
        let sanitized = sanitizeActiveAccountMap(map)
        try migrateAccountsStoreToSQLiteIfNeeded()
        try saveActiveAccountMapToSQLite(sanitized)
        try writeActiveAccountMapJSONMirror(sanitized)
    }

    nonisolated func writeActiveAccountMapJSONMirror(_ map: [String: String]) throws {
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

    nonisolated func safeFileDates(for file: STFile) -> (creationDate: Date, modificationDate: Date) {
        let fallback = Date()
        let values = try? file.url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let creationDate = values?.creationDate ?? values?.contentModificationDate ?? fallback
        let modificationDate = values?.contentModificationDate ?? values?.creationDate ?? fallback
        return (creationDate, modificationDate)
    }

    func normalizeAccountPayloadData(
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

    func accountFromNormalizedPayloadData(_ data: Data, fallbackRelativeAuthPath: String) -> CodexAuthAccount {
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

    func readAccountAuthData(_ account: CodexAuthAccount) throws -> Data {
        if let data = try loadCodexAccountAuthDataFromSQLite(accountID: account.id), !data.isEmpty {
            return data
        }
        throw CocoaError(.fileNoSuchFile)
    }

    func saveAccountAuthData(_ account: CodexAuthAccount, data: Data) throws {
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

    func makeConfiguredAccountPayload(
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

    func sanitizedConfiguredAccountName(name: String, relay: ConfiguredRelay?) -> String {
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

    func deriveAccountKind(from authJSON: JSON) -> String? {
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
