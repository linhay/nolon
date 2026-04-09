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
    func reconcileActiveSymlinkDriftIfNeeded(for provider: Provider) throws -> CodexAuthAccount? {
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

    func stopProviderAuthPolling(for providerID: String) {
        providerAuthPollingTasks[providerID]?.cancel()
        providerAuthPollingTasks[providerID] = nil
        providerAuthLastHashes[providerID] = nil
    }

    func pollProviderAuthChange(providerID: String, activeProviderKey: String, authFilePath: String) async {
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

    nonisolated func stableImportGroupID(for groupName: String) -> String {
        let normalized = groupName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let data = Data(normalized.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
