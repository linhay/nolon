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
    func clearReadOnlyRelayEvidenceFlag(for providerID: String) {
        readOnlyRelayEvidenceProviderIDs.remove(providerID)
    }

    func markReadOnlyRelayEvidenceUsed(for providerID: String) {
        readOnlyRelayEvidenceProviderIDs.insert(providerID)
    }

    func consumeReadOnlyRelayEvidenceFlag(for providerID: String) -> Bool {
        readOnlyRelayEvidenceProviderIDs.remove(providerID) != nil
    }

    func withAuthFileLock<T>(_ body: () throws -> T) throws -> T {
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

    func removeFileOrSymlinkIfPresent(_ file: STFile) throws {
        do {
            try FileManager.default.removeItem(at: file.url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return
        }
    }

    @discardableResult
    func reconcileProviderAuthWithSnapshotsIfNeeded(for provider: Provider) throws -> CodexAuthAccount? {
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
            if let destination = resolveSymlinkTarget(for: providerAuthFile),
               let destinationData = try? Data(contentsOf: destination.url),
               !destinationData.isEmpty {
                if let linked = matchAccount(authData: destinationData, accounts: snapshots) {
                    let activeID = activeAccountIdFromRegistry(for: provider, accounts: snapshots)
                    if let activeID,
                       activeID != linked.id,
                       let active = snapshots.first(where: { $0.id == activeID }) {
                        try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: active, provider: provider)
                        return active
                    }
                    if activeID == nil {
                        try setActiveAccount(linked, for: provider)
                        return linked
                    }
                }
                // Keep active symlink content intact here.
                // A changed symlink target is repaired in reconcileActiveSymlinkDriftIfNeeded,
                // which can restore the original active snapshot while preserving the drifted payload.
                return nil
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
                provider: provider,
                excludedAccountID: nil,
                preferredManagedAccount: activeAccount
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
                    provider: provider,
                    excludedAccountID: nil,
                    preferredManagedAccount: activeAccount
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

    func relinkProviderAuth(providerAuthFile: STFile, resolved: CodexAuthAccount, provider: Provider) throws {
        try removeFileOrSymlinkIfPresent(providerAuthFile)
        let managedAuthFile = try materializeManagedActiveAuthFile(for: resolved, provider: provider)
        try FileManager.default.createSymbolicLink(
            atPath: providerAuthFile.url.path,
            withDestinationPath: managedAuthFile.url.path
        )
        try setActiveAccount(resolved, for: provider)
    }

    func resolvePreferredSourceCandidate(
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

    func makeSnapshotCandidate(_ account: CodexAuthAccount) -> AuthSourceCandidate? {
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

    func scoreCandidate(
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

    func upsertSnapshotFromProviderData(
        authData: Data,
        providerRaw: String?,
        snapshots: [CodexAuthAccount],
        provider: Provider,
        excludedAccountID: UUID?,
        preferredManagedAccount: CodexAuthAccount? = nil
    ) throws -> CodexAuthAccount {
        guard !authData.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let preparedPayload = try prepareProviderPayloadForSnapshotUpsert(
            authData: authData,
            providerRaw: providerRaw,
            snapshots: snapshots,
            provider: provider
        )

        let raw: String
        if let providerRaw = preparedPayload.raw, !providerRaw.isEmpty {
            raw = providerRaw
        } else if let converted = String(data: preparedPayload.data, encoding: .utf8), !converted.isEmpty {
            raw = converted
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        guard hasImportableCredentials(authJSONString: raw) else {
            if let matched = matchAccount(authData: preparedPayload.data, accounts: snapshots),
               matched.id != excludedAccountID {
                return matched
            }
            throw CocoaError(.validationMissingMandatoryProperty)
        }

        let authSummary = CodexAuthSummary.fromJSONData(preparedPayload.data)
        let authIdentity = accountIdentity(from: preparedPayload.data, summary: authSummary)
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

        if let matched = matchAccount(authData: preparedPayload.data, accounts: snapshots),
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

        if let preferredAccount = preferredManagedAPIKeyAccount(
            authData: preparedPayload.data,
            authIdentity: authIdentity,
            preferredAccount: preferredManagedAccount
        ),
           preferredAccount.id != excludedAccountID
        {
            let normalized = try normalizeAccountPayloadData(
                authJSONString: raw,
                preferredId: preferredAccount.id,
                preferredCreatedAt: preferredAccount.createdAt,
                relativeAuthPath: preferredAccount.relativeAuthPath
            )
            try saveAccountAuthData(preferredAccount, data: normalized)
            return accountFromNormalizedPayloadData(normalized, fallbackRelativeAuthPath: preferredAccount.relativeAuthPath)
        }

        return try createSnapshotAccount(authJSONString: raw)
    }

    func prepareProviderPayloadForSnapshotUpsert(
        authData: Data,
        providerRaw: String?,
        snapshots: [CodexAuthAccount],
        provider: Provider
    ) throws -> (data: Data, raw: String?) {
        let baseData = authData
        let raw: String?
        if let providerRaw, !providerRaw.isEmpty {
            raw = providerRaw
        } else {
            raw = String(data: authData, encoding: .utf8)
        }

        guard let raw,
              let rawData = raw.data(using: .utf8),
              let authJSON = try? JSON(data: rawData),
              Self.canonicalAuthMode(authJSON["auth_mode"].string) == "apikey",
              authJSON["nolon"]["relay"] == JSON.null
        else {
            return (baseData, raw)
        }

        guard let matchedAccount = matchAccount(authData: baseData, accounts: snapshots),
              let relay = readOnlyRelayConfigEvidence(for: provider, matchedAccountID: matchedAccount.id)
        else {
            return (baseData, raw)
        }

        var rootObject = authJSON.dictionaryObject ?? [:]
        rootObject["base_url"] = relay.baseURL
        rootObject.removeValue(forKey: "baseURL")
        var nolon = (rootObject["nolon"] as? JSONObject) ?? [:]
        var relayObject: JSONObject = [
            "base_url": relay.baseURL,
            "model_provider": relay.modelProvider,
        ]
        if !relay.queryParams.isEmpty {
            relayObject["query_params"] = relay.queryParams
        }
        if !relay.headers.isEmpty {
            relayObject["headers"] = relay.headers
        }
        nolon["relay"] = relayObject
        rootObject["nolon"] = nolon

        let mergedData = try Self.encodeJSONObject(rootObject)
        markReadOnlyRelayEvidenceUsed(for: provider.id)
        return (mergedData, String(data: mergedData, encoding: .utf8))
    }

    @discardableResult
    func reconcileActiveSymlinkDriftIfNeeded(for provider: Provider, reason: String = "manual") throws -> CodexAuthAccount? {
        guard Self.isCodexTemplate(provider.templateId),
              let providerAuthFile = authFile(for: provider),
              providerAuthFile.isExists,
              providerAuthFile.isSymbolicLink
        else { return nil }

        let accounts = try loadAccountsFromAuthFolder()
        let currentProviderData: Data? = {
            guard let destination = resolveSymlinkTarget(for: providerAuthFile) else { return nil }
            return try? Data(contentsOf: destination.url)
        }()
        let linkedAccount: CodexAuthAccount? = {
            guard let currentProviderData, !currentProviderData.isEmpty else { return nil }
            return matchAccount(authData: currentProviderData, accounts: accounts)
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

        let activeData = currentProviderData ?? (try? readAccountAuthData(activeAccount))
        guard let activeData, !activeData.isEmpty else { return nil }

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

        let activeSummary = CodexAuthSummary.fromJSONData(activeData)
        let activeIdentity = accountIdentity(from: activeData, summary: activeSummary)
        let matchesPreferredManagedAPIKey =
            preferredManagedAPIKeyAccount(
                authData: activeData,
                authIdentity: activeIdentity,
                preferredAccount: activeAccount
            )?.id == activeAccount.id

        if isSameIdentity(backupData, activeData) || matchesPreferredManagedAPIKey {
            let refreshedActive = try upsertSnapshotFromProviderData(
                authData: activeData,
                providerRaw: String(data: activeData, encoding: .utf8),
                snapshots: accounts,
                provider: provider,
                excludedAccountID: nil,
                preferredManagedAccount: activeAccount
            )
            try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: refreshedActive, provider: provider)
            fingerprints[provider.id] = currentHash
            try saveActiveFingerprintMap(fingerprints)
            Self.logger.info(
                "Codex active snapshot updated from active symlink drift without account split. provider=\(provider.id, privacy: .public) active=\(refreshedActive.id.uuidString, privacy: .public)"
            )
            return refreshedActive
        }

        // External CLI switched account through active symlink:
        // restore original active snapshot from backup,
        // then place drifted auth payload into matched/new snapshot.
        try saveAccountAuthData(activeAccount, data: backupData)
        let restoredAccount = accountFromNormalizedPayloadData(backupData, fallbackRelativeAuthPath: activeAccount.relativeAuthPath)
        let refreshedSnapshots = try loadAccountsFromAuthFolder()
        let refreshedRestoredAccount = refreshedSnapshots.first(where: { $0.id == restoredAccount.id }) ?? restoredAccount
        let driftSummary = CodexAuthSummary.fromJSONData(activeData)
        let driftIdentity = accountIdentity(from: activeData, summary: driftSummary)
        let driftResolvedAccount: CodexAuthAccount
        if let strictMatch = matchAccountByStrictIdentity(
            authIdentity: driftIdentity,
            snapshots: loadAccountSnapshots(for: refreshedSnapshots),
            excludedAccountID: refreshedRestoredAccount.id
        ),
           let activeRaw = String(data: activeData, encoding: .utf8),
           hasImportableCredentials(authJSONString: activeRaw)
        {
            let normalized = try normalizeAccountPayloadData(
                authJSONString: activeRaw,
                preferredId: strictMatch.id,
                preferredCreatedAt: strictMatch.createdAt,
                relativeAuthPath: strictMatch.relativeAuthPath
            )
            try saveAccountAuthData(strictMatch, data: normalized)
            driftResolvedAccount = accountFromNormalizedPayloadData(
                normalized,
                fallbackRelativeAuthPath: strictMatch.relativeAuthPath
            )
        } else {
            driftResolvedAccount = try upsertSnapshotFromProviderData(
                authData: activeData,
                providerRaw: String(data: activeData, encoding: .utf8),
                snapshots: refreshedSnapshots,
                provider: provider,
                excludedAccountID: refreshedRestoredAccount.id
            )
        }

        if shouldClearActiveSelectionOnDriftDuringPreflight(reason: reason) {
            if hasStableCredentialIdentity(authData: activeData) {
                try setProviderAuthManagementPaused(false, for: provider)
                try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: driftResolvedAccount, provider: provider)
                try syncActiveProviderConfig(for: driftResolvedAccount, provider: provider)
                fingerprints[provider.id] = currentHash
                try saveActiveFingerprintMap(fingerprints)
                Self.logger.info(
                    "Codex passive drift adopted uniquely identified account and kept management. provider=\(provider.id, privacy: .public) active=\(driftResolvedAccount.id.uuidString, privacy: .public) reason=\(reason, privacy: .public)"
                )
                return driftResolvedAccount
            }
            try clearActiveSelectionAndRestoreProviderState(
                for: provider,
                preserveProviderAuthFile: true,
                pauseMonitoring: true
            )
            fingerprints.removeValue(forKey: provider.id)
            try saveActiveFingerprintMap(fingerprints)
            Self.logger.info(
                "Codex active selection cleared after passive preflight drift. provider=\(provider.id, privacy: .public) previousActive=\(refreshedRestoredAccount.id.uuidString, privacy: .public) reason=\(reason, privacy: .public)"
            )
            return nil
        }

        try relinkProviderAuth(providerAuthFile: providerAuthFile, resolved: refreshedRestoredAccount, provider: provider)

        fingerprints[provider.id] = previousHash
        try saveActiveFingerprintMap(fingerprints)
        Self.logger.info(
            "Codex active snapshot restored from backup after external drift. provider=\(provider.id, privacy: .public) active=\(refreshedRestoredAccount.id.uuidString, privacy: .public)"
        )
        return refreshedRestoredAccount
    }

    func isSameIdentity(_ lhsData: Data, _ rhsData: Data) -> Bool {
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

        if let leftNolonID = lhsIdentity.nolonAccountID,
           let rightNolonID = rhsIdentity.nolonAccountID
        {
            return leftNolonID == rightNolonID
        }
        return false
    }

    func cleanedHashHex(for data: Data) -> String {
        let cleaned = Self.cleanedAuthJSONData(from: data) ?? data
        let digest = SHA256.hash(data: cleaned)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func persistActiveFingerprintIfNeeded(for provider: Provider) throws {
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

    func loadActiveFingerprintMap() -> [String: String] {
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

    func saveActiveFingerprintMap(_ map: [String: String]) throws {
        let file = activeFingerprintsFile()
        _ = file.parentFolder()?.createIfNotExists()
        let root: JSONObject = ["providers": map]
        try file.overlay(with: Self.encodeJSONObject(root))
    }

    func loadPausedProviderAuthManagementMap() -> [String: Bool] {
        let file = pausedProviderAuthManagementFile()
        guard file.isExists,
              let data = try? file.data(),
              !data.isEmpty,
              let root = Self.decodeJSONObject(from: data),
              let providers = root["providers"] as? JSONObject
        else { return [:] }

        return providers.reduce(into: [String: Bool]()) { result, element in
            if let value = element.value as? Bool {
                result[element.key] = value
            }
        }
    }

    func savePausedProviderAuthManagementMap(_ map: [String: Bool]) throws {
        let file = pausedProviderAuthManagementFile()
        _ = file.parentFolder()?.createIfNotExists()
        let root: JSONObject = ["providers": map]
        try file.overlay(with: Self.encodeJSONObject(root))
    }

    func isProviderAuthManagementPaused(for provider: Provider) -> Bool {
        loadPausedProviderAuthManagementMap()[provider.id] == true
    }

    func setProviderAuthManagementPaused(_ paused: Bool, for provider: Provider) throws {
        var map = loadPausedProviderAuthManagementMap()
        if paused {
            map[provider.id] = true
        } else {
            map.removeValue(forKey: provider.id)
        }
        try savePausedProviderAuthManagementMap(map)
    }

    func hasStableCredentialIdentity(authData: Data) -> Bool {
        guard let json = try? JSON(data: authData) else { return false }
        if case .valid = credentialIdentityValidationResult(from: json) {
            return true
        }
        return false
    }

    func backupActiveSnapshotIfNeeded(for provider: Provider, force: Bool, reason: String) throws {
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

    func shouldCreateBackup(for folder: STFolder, accountID: UUID, force: Bool) -> Bool {
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

    func cleanupBackupFiles(in folder: STFolder) throws {
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

    func latestBackup(for provider: Provider, accountID: UUID, expectedHash: String?) -> STFile? {
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

    func activeBackupFolder(for provider: Provider) -> STFolder {
        nolonCodexRootFolder()
            .folder(PathName.backupsFolder.rawValue)
            .folder(PathName.activeBackupsFolder.rawValue)
            .folder(sanitizeFileStem(provider.id))
    }
}

extension CodexAuthManager {
    func startProviderAuthPolling(for provider: Provider) {
        stopProviderAuthPolling(for: provider.id)
        guard let authFile = authFile(for: provider) else { return }
        let authFilePath = authFile.url.path
        if let raw = try? String(contentsOf: URL(fileURLWithPath: authFilePath), encoding: .utf8) {
            providerAuthLastHashes[provider.id] = CodexAuthAccount.hashHex(for: raw)
        }

        let task = Task { [provider, authFilePath] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: providerAuthPollIntervalNanoseconds)
                await pollProviderAuthChange(for: provider, authFilePath: authFilePath)
            }
        }
        providerAuthPollingTasks[provider.id] = task
    }

    func stopProviderAuthPolling(for providerID: String) {
        providerAuthPollingTasks[providerID]?.cancel()
        providerAuthPollingTasks[providerID] = nil
        providerAuthLastHashes[providerID] = nil
    }

    func pollProviderAuthChange(for provider: Provider, authFilePath: String) async {
        let providerID = provider.id
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
              hasImportableCredentials(authJSONString: normalizedRaw)
        else {
            return
        }

        let wasPaused = isProviderAuthManagementPaused(for: provider)
        let hasStableIdentity = hasStableCredentialIdentity(authData: normalizedData)
        if wasPaused && hasStableIdentity == false {
            return
        }

        do {
            if wasPaused && hasStableIdentity {
                try setProviderAuthManagementPaused(false, for: provider)
            }
            _ = try await preflightManagedAuthIfNeeded(
                for: provider,
                forceBackup: false,
                reason: "background_poll"
            )
        } catch {
            Self.logger.error("Provider auth polling failed to process drift. provider=\(providerID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    nonisolated func stableImportGroupID(for groupName: String) -> String {
        let normalized = groupName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let data = Data(normalized.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
