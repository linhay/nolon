import Foundation
import STFilePath
import STJSON
import ProviderCatalog

public struct CodexCloudSyncConfiguration: Sendable, Equatable, Codable {
    public var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }
}

public enum CodexCloudSyncStatus: String, Codable, Sendable, Equatable {
    case localOnly
    case pendingUpload
    case synced
    case pendingDelete
    case conflict
    case invalidPending
}

public struct CodexCloudSyncState: Sendable, Equatable {
    public let accountID: UUID
    public var cloudRecordName: String?
    public var cloudRecordZone: String?
    public var recordSystemFieldsBase64: String?
    public var recordUpdatedAt: Date?
    public var lastSyncedAt: Date?
    public var syncStatus: CodexCloudSyncStatus
    public var isTombstone: Bool
    public var lastError: String?
    public var lastErrorAt: Date?
    public var deviceID: String?
    public var conflictPayloadJSONString: String?

    public init(
        accountID: UUID,
        cloudRecordName: String? = nil,
        cloudRecordZone: String? = nil,
        recordSystemFieldsBase64: String? = nil,
        recordUpdatedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        syncStatus: CodexCloudSyncStatus = .localOnly,
        isTombstone: Bool = false,
        lastError: String? = nil,
        lastErrorAt: Date? = nil,
        deviceID: String? = nil,
        conflictPayloadJSONString: String? = nil
    ) {
        self.accountID = accountID
        self.cloudRecordName = cloudRecordName
        self.cloudRecordZone = cloudRecordZone
        self.recordSystemFieldsBase64 = recordSystemFieldsBase64
        self.recordUpdatedAt = recordUpdatedAt
        self.lastSyncedAt = lastSyncedAt
        self.syncStatus = syncStatus
        self.isTombstone = isTombstone
        self.lastError = lastError
        self.lastErrorAt = lastErrorAt
        self.deviceID = deviceID
        self.conflictPayloadJSONString = conflictPayloadJSONString
    }
}

public struct CodexCloudSyncOverview: Sendable, Equatable {
    public let totalRecordCount: Int
    public let syncedCount: Int
    public let pendingCount: Int
    public let conflictCount: Int
    public let invalidPendingCount: Int
    public let lastSyncedAt: Date?
    public let recentError: String?
    public let recentErrorAt: Date?

    public init(
        totalRecordCount: Int = 0,
        syncedCount: Int = 0,
        pendingCount: Int = 0,
        conflictCount: Int = 0,
        invalidPendingCount: Int = 0,
        lastSyncedAt: Date? = nil,
        recentError: String? = nil,
        recentErrorAt: Date? = nil
    ) {
        self.totalRecordCount = totalRecordCount
        self.syncedCount = syncedCount
        self.pendingCount = pendingCount
        self.conflictCount = conflictCount
        self.invalidPendingCount = invalidPendingCount
        self.lastSyncedAt = lastSyncedAt
        self.recentError = recentError
        self.recentErrorAt = recentErrorAt
    }
}

public struct CodexCloudSyncPendingChange: Sendable, Equatable {
    public let account: CodexAuthAccount
    public let state: CodexCloudSyncState
    public let authData: Data?

    public init(account: CodexAuthAccount, state: CodexCloudSyncState, authData: Data?) {
        self.account = account
        self.state = state
        self.authData = authData
    }
}

public struct CodexCloudAttentionItem: Sendable, Equatable, Identifiable {
    public let account: CodexAuthAccount
    public let state: CodexCloudSyncState

    public var id: UUID { account.id }

    public init(account: CodexAuthAccount, state: CodexCloudSyncState) {
        self.account = account
        self.state = state
    }
}

public struct CodexCloudSyncRecordPayload: Sendable, Equatable, Codable {
    public let recordName: String
    public let zoneName: String?
    public let recordSystemFieldsBase64: String?
    public let accountPayloadData: Data?
    public let metadataJSONString: String?
    public let recordUpdatedAt: Date
    public let isTombstone: Bool
    public let originDeviceID: String?
    public let schemaVersion: Int

    public init(
        recordName: String,
        zoneName: String? = nil,
        recordSystemFieldsBase64: String? = nil,
        accountPayloadData: Data?,
        metadataJSONString: String? = nil,
        recordUpdatedAt: Date,
        isTombstone: Bool,
        originDeviceID: String? = nil,
        schemaVersion: Int = 1
    ) {
        self.recordName = recordName
        self.zoneName = zoneName
        self.recordSystemFieldsBase64 = recordSystemFieldsBase64
        self.accountPayloadData = accountPayloadData
        self.metadataJSONString = metadataJSONString
        self.recordUpdatedAt = recordUpdatedAt
        self.isTombstone = isTombstone
        self.originDeviceID = originDeviceID
        self.schemaVersion = schemaVersion
    }

    public func encodedJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decoded(from jsonString: String?) -> CodexCloudSyncRecordPayload? {
        guard let jsonString = jsonString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(CodexCloudSyncRecordPayload.self, from: data)
    }
}

public enum CodexCloudSyncPreflightBlock: LocalizedError, Sendable, Equatable {
    case tombstonedActiveAccount(accountID: UUID, status: CodexCloudSyncStatus)

    public var errorDescription: String? {
        switch self {
        case let .tombstonedActiveAccount(accountID, status):
            return "Cloud sync blocked preflight for active account \(accountID.uuidString) with status \(status.rawValue)."
        }
    }
}

public enum CodexRemoteCloudTombstoneResult: Sendable, Equatable {
    case removedLocally
    case invalidatedActiveAccount
}

enum CodexAccountCloudMergePolicy {
    static func mergeAuthData(
        localAuthData: Data,
        remoteAuthData: Data,
        localRecordUpdatedAt: Date?,
        remoteRecordUpdatedAt: Date?
    ) throws -> Data {
        let localSummary = CodexAuthSummary.fromJSONData(localAuthData)
        let remoteSummary = CodexAuthSummary.fromJSONData(remoteAuthData)
        let localCleaned = CodexAuthManager.cleanedAuthJSONData(from: localAuthData) ?? localAuthData
        let remoteCleaned = CodexAuthManager.cleanedAuthJSONData(from: remoteAuthData) ?? remoteAuthData

        if let localAccountID = normalized(localSummary.accountID),
           let remoteAccountID = normalized(remoteSummary.accountID),
           localAccountID == remoteAccountID
        {
            return preferNewerPayload(
                localAuthData: localAuthData,
                remoteAuthData: remoteAuthData,
                localRecordUpdatedAt: localRecordUpdatedAt,
                remoteRecordUpdatedAt: remoteRecordUpdatedAt
            )
        }

        if normalized(localSummary.accountID) == nil,
           normalized(remoteSummary.accountID) == nil,
           localCleaned == remoteCleaned
        {
            let remoteIsPreferred = prefersRemote(
                localRecordUpdatedAt: localRecordUpdatedAt,
                remoteRecordUpdatedAt: remoteRecordUpdatedAt
            )
            var base = try requireJSONObject(remoteIsPreferred ? remoteAuthData : localAuthData)
            let other = try requireJSONObject(remoteIsPreferred ? localAuthData : remoteAuthData)

            let latestLogin = maxISODate(
                string(at: ["nolon", "account", "lastLoginAt"], in: base),
                string(at: ["nolon", "account", "lastLoginAt"], in: other)
            )
            let latestSuccess = maxISODate(
                string(at: ["nolon", "account", "lastSyncSucceededAt"], in: base),
                string(at: ["nolon", "account", "lastSyncSucceededAt"], in: other)
            )
            let baseFailureAt = string(at: ["nolon", "account", "lastSyncFailedAt"], in: base)
            let otherFailureAt = string(at: ["nolon", "account", "lastSyncFailedAt"], in: other)
            let latestFailure = maxISODate(baseFailureAt, otherFailureAt)
            let failureMessage: String? = {
                guard let latestFailure else { return nil }
                if latestFailure == otherFailureAt {
                    return string(at: ["nolon", "account", "lastSyncFailureMessage"], in: other)
                }
                return string(at: ["nolon", "account", "lastSyncFailureMessage"], in: base)
            }()

            set(string: latestLogin, at: ["nolon", "account", "lastLoginAt"], in: &base)
            set(string: latestSuccess, at: ["nolon", "account", "lastSyncSucceededAt"], in: &base)
            set(string: latestFailure, at: ["nolon", "account", "lastSyncFailedAt"], in: &base)
            set(string: failureMessage, at: ["nolon", "account", "lastSyncFailureMessage"], in: &base)
            return try CodexAuthManager.encodeJSONObject(base)
        }

        return preferNewerPayload(
            localAuthData: localAuthData,
            remoteAuthData: remoteAuthData,
            localRecordUpdatedAt: localRecordUpdatedAt,
            remoteRecordUpdatedAt: remoteRecordUpdatedAt
        )
    }

    private static func preferNewerPayload(
        localAuthData: Data,
        remoteAuthData: Data,
        localRecordUpdatedAt: Date?,
        remoteRecordUpdatedAt: Date?
    ) -> Data {
        prefersRemote(localRecordUpdatedAt: localRecordUpdatedAt, remoteRecordUpdatedAt: remoteRecordUpdatedAt)
            ? remoteAuthData
            : localAuthData
    }

    private static func prefersRemote(localRecordUpdatedAt: Date?, remoteRecordUpdatedAt: Date?) -> Bool {
        switch (localRecordUpdatedAt, remoteRecordUpdatedAt) {
        case let (local?, remote?):
            return remote >= local
        case (nil, .some):
            return true
        default:
            return false
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value.lowercased()
    }

    private static func requireJSONObject(_ data: Data) throws -> [String: Any] {
        guard let object = CodexAuthManager.decodeJSONObject(from: data) else {
            throw NSError(domain: "CodexAccountCloudMergePolicy", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Expected JSON object auth payload.",
            ])
        }
        return object
    }

    private static func string(at path: [String], in object: [String: Any]) -> String? {
        var current: Any? = object
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        guard let raw = current as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func set(string value: String?, at path: [String], in object: inout [String: Any]) {
        guard !path.isEmpty else { return }
        if path.count == 1 {
            if let value {
                object[path[0]] = value
            } else {
                object.removeValue(forKey: path[0])
            }
            return
        }
        var head = (object[path[0]] as? [String: Any]) ?? [:]
        let tail = Array(path.dropFirst())
        set(string: value, at: tail, in: &head)
        if head.isEmpty {
            object.removeValue(forKey: path[0])
        } else {
            object[path[0]] = head
        }
    }

    private static func maxISODate(_ lhs: String?, _ rhs: String?) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            let left = formatter.date(from: lhs) ?? ISO8601DateFormatter().date(from: lhs)
            let right = formatter.date(from: rhs) ?? ISO8601DateFormatter().date(from: rhs)
            switch (left, right) {
            case let (left?, right?):
                return left >= right ? lhs : rhs
            case (.some, nil):
                return lhs
            case (nil, .some):
                return rhs
            default:
                return lhs >= rhs ? lhs : rhs
            }
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        default:
            return nil
        }
    }
}

extension CodexAuthManager {
    public nonisolated func cloudSyncConfigurationFile() -> STFile {
        nolonCodexRootFolder().file("cloud-sync-settings.json")
    }

    public func cloudSyncConfiguration() throws -> CodexCloudSyncConfiguration {
        let file = cloudSyncConfigurationFile()
        guard file.isExists else {
            return CodexCloudSyncConfiguration()
        }
        let raw = try file.read().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return CodexCloudSyncConfiguration()
        }
        let data = Data(raw.utf8)
        return (try? JSONDecoder().decode(CodexCloudSyncConfiguration.self, from: data))
            ?? CodexCloudSyncConfiguration()
    }

    public func setCloudSyncConfiguration(_ configuration: CodexCloudSyncConfiguration) throws {
        let file = cloudSyncConfigurationFile()
        _ = file.parentFolder()?.createIfNotExists()
        let data = try JSONEncoder().encode(configuration)
        try file.overlay(with: String(decoding: data, as: UTF8.self))
    }

    public func setCloudSyncEnabled(_ enabled: Bool) throws {
        try setCloudSyncConfiguration(CodexCloudSyncConfiguration(isEnabled: enabled))
        guard enabled else { return }
        try prepareAccountsForInitialCloudSyncUpload()
    }

    public func cloudSyncState(for accountID: UUID) throws -> CodexCloudSyncState? {
        try migrateAccountsStoreToSQLiteIfNeeded()
        return try loadCodexCloudSyncStateFromSQLite(accountID: accountID)
    }

    public func cloudSyncStates(for accounts: [CodexAuthAccount]) throws -> [UUID: CodexCloudSyncState] {
        try migrateAccountsStoreToSQLiteIfNeeded()
        var result: [UUID: CodexCloudSyncState] = [:]
        result.reserveCapacity(accounts.count)
        for account in accounts {
            guard let state = try loadCodexCloudSyncStateFromSQLite(accountID: account.id) else { continue }
            result[account.id] = state
        }
        return result
    }

    public func applyCloudSyncState(_ state: CodexCloudSyncState) throws {
        try migrateAccountsStoreToSQLiteIfNeeded()
        try upsertCodexCloudSyncStateInSQLite(state)
    }

    public func cloudSyncOverview() async throws -> CodexCloudSyncOverview {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        let rows = try queryCodexAccountsRowsFromSQLite()
        let states = try rows.compactMap { row in
            try loadCodexCloudSyncStateFromSQLite(accountID: row.id)
        }

        let latestErrorState = states
            .compactMap { state -> (Date, String)? in
                guard let errorAt = state.lastErrorAt,
                      let error = state.lastError?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !error.isEmpty
                else {
                    return nil
                }
                return (errorAt, error)
            }
            .max(by: { $0.0 < $1.0 })

        return CodexCloudSyncOverview(
            totalRecordCount: rows.count,
            syncedCount: states.filter { $0.syncStatus == .synced && !$0.isTombstone }.count,
            pendingCount: states.filter { state in
                switch state.syncStatus {
                case .pendingUpload, .pendingDelete:
                    return true
                case .localOnly, .synced, .conflict, .invalidPending:
                    return false
                }
            }.count,
            conflictCount: states.filter { $0.syncStatus == .conflict }.count,
            invalidPendingCount: states.filter { $0.syncStatus == .invalidPending }.count,
            lastSyncedAt: states.compactMap(\.lastSyncedAt).max(),
            recentError: latestErrorState?.1,
            recentErrorAt: latestErrorState?.0
        )
    }

    public func cloudSyncPendingChanges() async throws -> [CodexCloudSyncPendingChange] {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        let rows = try queryCodexAccountsRowsFromSQLite()
        return try rows.compactMap { row in
            guard let state = try loadCodexCloudSyncStateFromSQLite(accountID: row.id) else { return nil }
            switch state.syncStatus {
            case .pendingUpload, .pendingDelete:
                let account = CodexAuthAccount(
                    id: row.id,
                    name: row.name,
                    createdAt: row.createdAt,
                    relativeAuthPath: sqliteRelativeAuthPath(for: row.id)
                )
                let authData = state.syncStatus == .pendingDelete ? nil : try? readAccountAuthData(account)
                return CodexCloudSyncPendingChange(account: account, state: state, authData: authData)
            case .localOnly, .synced, .conflict, .invalidPending:
                return nil
            }
        }
    }

    public func cloudAttentionItems() async throws -> [CodexCloudAttentionItem] {
        let accounts = try await loadAccounts()
        let states = try cloudSyncStates(for: accounts)
        return accounts.compactMap { account in
            guard let state = states[account.id] else { return nil }
            switch state.syncStatus {
            case .conflict, .invalidPending:
                return CodexCloudAttentionItem(account: account, state: state)
            case .localOnly, .pendingUpload, .synced, .pendingDelete:
                return nil
            }
        }
        .sorted { lhs, rhs in
            let leftPriority = cloudAttentionPriority(lhs.state.syncStatus)
            let rightPriority = cloudAttentionPriority(rhs.state.syncStatus)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            if lhs.account.createdAt != rhs.account.createdAt {
                return lhs.account.createdAt > rhs.account.createdAt
            }
            return lhs.account.name.localizedCaseInsensitiveCompare(rhs.account.name) == .orderedAscending
        }
    }

    public func retryCloudSyncUpload(accountID: UUID) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        guard let existing = try cloudSyncState(for: accountID) else { return }
        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: accountID,
                cloudRecordName: existing.cloudRecordName ?? accountID.uuidString,
                cloudRecordZone: existing.cloudRecordZone,
                recordSystemFieldsBase64: CodexCloudSyncRecordPayload.decoded(from: existing.conflictPayloadJSONString)?.recordSystemFieldsBase64
                    ?? existing.recordSystemFieldsBase64,
                recordUpdatedAt: Date(),
                lastSyncedAt: existing.lastSyncedAt,
                syncStatus: .pendingUpload,
                isTombstone: false,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: existing.deviceID,
                conflictPayloadJSONString: nil
            )
        )
    }

    public func discardInvalidPendingManagedAccount(
        id: UUID,
        providers: [Provider]
    ) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        try withAuthFileLock {
            let accounts = try loadAccountsFromAuthFolder()
            guard accounts.contains(where: { $0.id == id }) else { return }

            for provider in providers where Self.isCodexTemplate(provider.templateId) {
                if activeAccountId(for: provider, accounts: accounts) == id {
                    try clearActiveAccount(for: provider)
                    if let providerAuthFile = authFile(for: provider) {
                        try removeFileOrSymlinkIfPresent(providerAuthFile)
                    }
                    try persistActiveFingerprintIfNeeded(for: provider)
                }
            }

            try removeCodexAccountFromSQLite(id: id)
        }
    }

    public func resetCloudSyncMetadataAfterRemotePurge() async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        let rows = try queryCodexAccountsRowsFromSQLite()
        for row in rows {
            try applyCloudSyncState(
                CodexCloudSyncState(
                    accountID: row.id,
                    cloudRecordName: nil,
                    cloudRecordZone: nil,
                    recordUpdatedAt: nil,
                    lastSyncedAt: nil,
                    syncStatus: .localOnly,
                    isTombstone: false,
                    lastError: nil,
                    lastErrorAt: nil,
                    deviceID: nil,
                    conflictPayloadJSONString: nil
                )
            )
        }
    }

    public func markCloudSyncSent(
        recordName: String,
        zoneName: String?,
        sentAt: Date,
        originDeviceID: String?,
        systemFieldsData: Data? = nil
    ) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        guard let account = try findCloudSyncAccount(recordName: recordName),
              let existing = try cloudSyncState(for: account.id)
        else {
            return
        }

        if existing.syncStatus == .pendingDelete || existing.isTombstone {
            try withAuthFileLock {
                try removeCodexAccountFromSQLite(id: account.id)
            }
            return
        }

        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: account.id,
                cloudRecordName: recordName,
                cloudRecordZone: zoneName ?? existing.cloudRecordZone,
                recordSystemFieldsBase64: systemFieldsData?.base64EncodedString() ?? existing.recordSystemFieldsBase64,
                recordUpdatedAt: existing.recordUpdatedAt ?? sentAt,
                lastSyncedAt: sentAt,
                syncStatus: .synced,
                isTombstone: false,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: originDeviceID ?? existing.deviceID,
                conflictPayloadJSONString: existing.conflictPayloadJSONString
            )
        )
    }

    public func markCloudSyncFailed(
        recordName: String,
        message: String,
        at date: Date,
        suggestedStatus: CodexCloudSyncStatus? = nil,
        conflictPayload: CodexCloudSyncRecordPayload? = nil
    ) async throws {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        guard let account = try findCloudSyncAccount(recordName: recordName),
              let existing = try cloudSyncState(for: account.id)
        else {
            return
        }

        let nextConflictPayload: String? = {
            if let conflictPayload {
                return conflictPayload.encodedJSONString()
            }
            if suggestedStatus == .conflict || existing.syncStatus == .conflict {
                return existing.conflictPayloadJSONString
            }
            return nil
        }()
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: account.id,
                cloudRecordName: existing.cloudRecordName ?? recordName,
                cloudRecordZone: existing.cloudRecordZone,
                recordUpdatedAt: existing.recordUpdatedAt,
                lastSyncedAt: existing.lastSyncedAt,
                syncStatus: suggestedStatus ?? existing.syncStatus,
                isTombstone: existing.isTombstone,
                lastError: trimmedMessage.isEmpty ? existing.lastError : trimmedMessage,
                lastErrorAt: trimmedMessage.isEmpty ? existing.lastErrorAt : date,
                deviceID: existing.deviceID,
                conflictPayloadJSONString: nextConflictPayload
            )
        )
    }

    @discardableResult
    public func adoptRemoteCloudConflict(
        accountID: UUID,
        providers: [Provider]
    ) async throws -> CodexAuthAccount? {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        guard let existingState = try cloudSyncState(for: accountID),
              existingState.syncStatus == .conflict,
              let conflictPayload = CodexCloudSyncRecordPayload.decoded(from: existingState.conflictPayloadJSONString),
              let accountPayloadData = conflictPayload.accountPayloadData
        else {
            return nil
        }

        let accounts = try await loadAccounts()
        guard let existingAccount = accounts.first(where: { $0.id == accountID }) else {
            return nil
        }

        let normalizedRemoteData = try normalizeAccountPayloadData(
            authJSONString: String(decoding: accountPayloadData, as: UTF8.self),
            preferredId: existingAccount.id,
            preferredCreatedAt: existingAccount.createdAt,
            relativeAuthPath: existingAccount.relativeAuthPath
        )
        let refreshedAccount = accountFromNormalizedPayloadData(
            normalizedRemoteData,
            fallbackRelativeAuthPath: existingAccount.relativeAuthPath
        )
        try upsertCodexAccountInSQLite(refreshedAccount, authData: normalizedRemoteData)

        for provider in providers where Self.isCodexTemplate(provider.templateId) {
            try refreshActiveProviderConfigIfNeeded(for: refreshedAccount, provider: provider)
        }

        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: refreshedAccount.id,
                cloudRecordName: conflictPayload.recordName,
                cloudRecordZone: conflictPayload.zoneName ?? existingState.cloudRecordZone,
                recordSystemFieldsBase64: conflictPayload.recordSystemFieldsBase64,
                recordUpdatedAt: conflictPayload.recordUpdatedAt,
                lastSyncedAt: Date(),
                syncStatus: .synced,
                isTombstone: false,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: conflictPayload.originDeviceID,
                conflictPayloadJSONString: nil
            )
        )
        return refreshedAccount
    }

    @discardableResult
    public func splitCloudConflictKeepingBoth(accountID: UUID) async throws -> (kept: CodexAuthAccount, duplicated: CodexAuthAccount)? {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        guard let existingState = try cloudSyncState(for: accountID),
              existingState.syncStatus == .conflict,
              let conflictPayload = CodexCloudSyncRecordPayload.decoded(from: existingState.conflictPayloadJSONString),
              let accountPayloadData = conflictPayload.accountPayloadData
        else {
            return nil
        }

        let accounts = try await loadAccounts()
        guard let existingAccount = accounts.first(where: { $0.id == accountID }) else {
            return nil
        }

        let duplicateID = UUID()
        let duplicateRelativePath = sqliteRelativeAuthPath(for: duplicateID)
        let normalizedRemoteData = try normalizeAccountPayloadData(
            authJSONString: String(decoding: accountPayloadData, as: UTF8.self),
            preferredId: duplicateID,
            preferredCreatedAt: Date(),
            relativeAuthPath: duplicateRelativePath
        )
        let remoteSummary = CodexAuthSummary.fromJSONData(normalizedRemoteData)
        let duplicateName = makeDuplicatedCloudConflictName(
            preferredBaseName: remoteSummary.preferredDisplayName(fallbackFileStem: existingAccount.name),
            excludingAccountID: existingAccount.id,
            accounts: accounts
        )
        let duplicatedAccount = CodexAuthAccount(
            id: duplicateID,
            name: duplicateName,
            createdAt: Date(),
            relativeAuthPath: duplicateRelativePath
        )
        try upsertCodexAccountInSQLite(duplicatedAccount, authData: normalizedRemoteData)

        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: existingAccount.id,
                cloudRecordName: existingState.cloudRecordName ?? existingAccount.id.uuidString,
                cloudRecordZone: existingState.cloudRecordZone,
                recordSystemFieldsBase64: conflictPayload.recordSystemFieldsBase64,
                recordUpdatedAt: Date(),
                lastSyncedAt: existingState.lastSyncedAt,
                syncStatus: .pendingUpload,
                isTombstone: false,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: existingState.deviceID,
                conflictPayloadJSONString: nil
            )
        )
        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: duplicatedAccount.id,
                cloudRecordName: duplicatedAccount.id.uuidString,
                cloudRecordZone: conflictPayload.zoneName ?? existingState.cloudRecordZone,
                recordSystemFieldsBase64: nil,
                recordUpdatedAt: Date(),
                lastSyncedAt: nil,
                syncStatus: .pendingUpload,
                isTombstone: false,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: conflictPayload.originDeviceID,
                conflictPayloadJSONString: nil
            )
        )

        return (existingAccount, duplicatedAccount)
    }

    @discardableResult
    public func applyRemoteCloudRecord(
        _ payload: CodexCloudSyncRecordPayload,
        provider: Provider?
    ) async throws -> CodexAuthAccount? {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        if payload.isTombstone {
            guard let accountID = UUID(uuidString: payload.recordName) else {
                return nil
            }
            _ = try await applyRemoteCloudTombstone(accountID: accountID, provider: provider)
            return nil
        }

        guard let accountPayloadData = payload.accountPayloadData else {
            throw NSError(
                domain: "CodexCloudSync",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Remote cloud record is missing account payload."]
            )
        }

        let recordAccountID = UUID(uuidString: payload.recordName) ?? UUID()
        let relativeAuthPath = sqliteRelativeAuthPath(for: recordAccountID)
        let normalizedRemoteData = try normalizeAccountPayloadData(
            authJSONString: String(decoding: accountPayloadData, as: UTF8.self),
            preferredId: recordAccountID,
            preferredCreatedAt: payload.recordUpdatedAt,
            relativeAuthPath: relativeAuthPath
        )
        let accounts = try await loadAccounts()
        if let matched = matchAccount(authData: normalizedRemoteData, accounts: accounts) {
            let localData = try readAccountAuthData(matched)
            let localState = try cloudSyncState(for: matched.id)
            let mergedData = try CodexAccountCloudMergePolicy.mergeAuthData(
                localAuthData: localData,
                remoteAuthData: normalizedRemoteData,
                localRecordUpdatedAt: localState?.recordUpdatedAt,
                remoteRecordUpdatedAt: payload.recordUpdatedAt
            )
            try saveAccountAuthData(matched, data: mergedData)
            let refreshed = accountFromNormalizedPayloadData(mergedData, fallbackRelativeAuthPath: matched.relativeAuthPath)
            try applyCloudSyncState(
                CodexCloudSyncState(
                    accountID: refreshed.id,
                    cloudRecordName: payload.recordName,
                    cloudRecordZone: payload.zoneName,
                    recordSystemFieldsBase64: payload.recordSystemFieldsBase64,
                    recordUpdatedAt: payload.recordUpdatedAt,
                    lastSyncedAt: Date(),
                    syncStatus: .synced,
                    isTombstone: false,
                    lastError: nil,
                    lastErrorAt: nil,
                    deviceID: payload.originDeviceID,
                    conflictPayloadJSONString: nil
                )
            )
            return refreshed
        }

        let created = accountFromNormalizedPayloadData(normalizedRemoteData, fallbackRelativeAuthPath: relativeAuthPath)
        try upsertCodexAccountInSQLite(created, authData: normalizedRemoteData)
        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: created.id,
                cloudRecordName: payload.recordName,
                cloudRecordZone: payload.zoneName,
                recordSystemFieldsBase64: payload.recordSystemFieldsBase64,
                recordUpdatedAt: payload.recordUpdatedAt,
                lastSyncedAt: Date(),
                syncStatus: .synced,
                isTombstone: false,
                lastError: nil,
                lastErrorAt: nil,
                deviceID: payload.originDeviceID,
                conflictPayloadJSONString: nil
            )
        )
        return created
    }

    public func markAccountPendingCloudDeletion(id: UUID) throws {
        let existing = try cloudSyncState(for: id)
        try applyCloudSyncState(
            CodexCloudSyncState(
                accountID: id,
                cloudRecordName: existing?.cloudRecordName,
                cloudRecordZone: existing?.cloudRecordZone,
                recordSystemFieldsBase64: existing?.recordSystemFieldsBase64,
                recordUpdatedAt: Date(),
                lastSyncedAt: existing?.lastSyncedAt,
                syncStatus: .pendingDelete,
                isTombstone: true,
                lastError: existing?.lastError,
                lastErrorAt: existing?.lastErrorAt,
                deviceID: existing?.deviceID,
                conflictPayloadJSONString: existing?.conflictPayloadJSONString
            )
        )
    }

    public func applyRemoteCloudTombstone(
        accountID: UUID,
        provider: Provider?
    ) async throws -> CodexRemoteCloudTombstoneResult {
        try await migrateLegacyIfNeeded()
        try migrateAccountsStoreToSQLiteIfNeeded()

        let accounts = try await loadAccounts()
        guard accounts.contains(where: { $0.id == accountID }) else {
            return .removedLocally
        }

        let isActive: Bool = {
            if let provider {
                return activeAccountId(for: provider, accounts: accounts) == accountID
            }
            let map = loadActiveAccountMap()
            return map.values.contains(accountID.uuidString)
        }()

        if isActive {
            let existing = try cloudSyncState(for: accountID)
            try applyCloudSyncState(
                CodexCloudSyncState(
                    accountID: accountID,
                    cloudRecordName: existing?.cloudRecordName ?? accountID.uuidString,
                    cloudRecordZone: existing?.cloudRecordZone,
                    recordSystemFieldsBase64: existing?.recordSystemFieldsBase64,
                    recordUpdatedAt: existing?.recordUpdatedAt ?? Date(),
                    lastSyncedAt: existing?.lastSyncedAt,
                    syncStatus: .invalidPending,
                    isTombstone: true,
                    lastError: existing?.lastError,
                    lastErrorAt: existing?.lastErrorAt,
                    deviceID: existing?.deviceID,
                    conflictPayloadJSONString: existing?.conflictPayloadJSONString
                )
            )
            return .invalidatedActiveAccount
        }

        try withAuthFileLock {
            try removeCodexAccountFromSQLite(id: accountID)
        }
        return .removedLocally
    }

    func preflightBlockedByCloudSync(for provider: Provider) throws -> CodexCloudSyncPreflightBlock? {
        let accounts = try loadAccountsFromAuthFolder()
        guard let activeID = activeAccountId(for: provider, accounts: accounts),
              let state = try loadCodexCloudSyncStateFromSQLite(accountID: activeID)
        else {
            return nil
        }
        guard state.isTombstone || state.syncStatus == .invalidPending else {
            return nil
        }
        return .tombstonedActiveAccount(accountID: activeID, status: state.syncStatus)
    }

    private func prepareAccountsForInitialCloudSyncUpload() throws {
        let rows = try queryCodexAccountsRowsFromSQLite()
        for row in rows {
            let existing = try loadCodexCloudSyncStateFromSQLite(accountID: row.id)
            guard let existing else {
                try applyCloudSyncState(
                    CodexCloudSyncState(
                        accountID: row.id,
                        cloudRecordName: row.id.uuidString,
                        cloudRecordZone: nil,
                        recordUpdatedAt: Date(),
                        lastSyncedAt: nil,
                        syncStatus: .pendingUpload,
                        isTombstone: false
                    )
                )
                continue
            }

            switch existing.syncStatus {
            case .pendingDelete, .conflict, .invalidPending:
                continue
            case .localOnly, .pendingUpload, .synced:
                try applyCloudSyncState(
                    CodexCloudSyncState(
                        accountID: row.id,
                        cloudRecordName: existing.cloudRecordName ?? row.id.uuidString,
                        cloudRecordZone: existing.cloudRecordZone,
                        recordSystemFieldsBase64: existing.recordSystemFieldsBase64,
                        recordUpdatedAt: existing.recordUpdatedAt ?? Date(),
                        lastSyncedAt: existing.lastSyncedAt,
                        syncStatus: .pendingUpload,
                        isTombstone: false,
                        lastError: existing.lastError,
                        lastErrorAt: existing.lastErrorAt,
                        deviceID: existing.deviceID,
                        conflictPayloadJSONString: existing.conflictPayloadJSONString
                    )
                )
            }
        }
    }

    private func findCloudSyncAccount(recordName: String) throws -> CodexAuthAccount? {
        let rows = try queryCodexAccountsRowsFromSQLite()
        for row in rows {
            let state = try loadCodexCloudSyncStateFromSQLite(accountID: row.id)
            let candidateNames = [
                state?.cloudRecordName,
                row.id.uuidString,
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard candidateNames.contains(recordName) else { continue }
            return CodexAuthAccount(
                id: row.id,
                name: row.name,
                createdAt: row.createdAt,
                relativeAuthPath: sqliteRelativeAuthPath(for: row.id)
            )
        }
        return nil
    }

    private func cloudAttentionPriority(_ status: CodexCloudSyncStatus) -> Int {
        switch status {
        case .invalidPending:
            return 0
        case .conflict:
            return 1
        case .localOnly, .pendingUpload, .synced, .pendingDelete:
            return 2
        }
    }

    private func makeDuplicatedCloudConflictName(
        preferredBaseName: String,
        excludingAccountID: UUID,
        accounts: [CodexAuthAccount]
    ) -> String {
        let trimmedBase = preferredBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedBase.isEmpty ? "account" : trimmedBase
        let usedNames = Set(
            accounts
                .filter { $0.id != excludingAccountID }
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        let primary = "\(baseName) (iCloud)"
        if !usedNames.contains(primary.lowercased()) {
            return primary
        }

        var index = 2
        while true {
            let candidate = "\(baseName) (iCloud \(index))"
            if !usedNames.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }
}
