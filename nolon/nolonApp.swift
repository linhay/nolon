//
//  nolonApp.swift
//  nolon
//
//  Created by linhey on 1/20/26.
//

import SwiftUI
import Sparkle
import Combine
import Observation
import OSLog
import Security
import ProviderCatalog
import ProviderUsage
import ProvidersShared
import NolonResourceKit
import NolonUI
#if canImport(CloudKit)
import CloudKit
#endif

// This view model class publishes when new updates can be checked by the user
@Observable
final class CheckForUpdatesViewModel {
    var canCheckForUpdates = false
    @ObservationIgnored private var updatesCancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        canCheckForUpdates = updater.canCheckForUpdates
        updatesCancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }
}

// This is the view for the Check for Updates menu item
// Note this intermediate view is necessary for the disabled state on the menu item to work properly before Monterey.
// See https://stackoverflow.com/questions/68553092/menu-not-updating-swiftui-bug for more info
struct CheckForUpdatesView: View {
    @State private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater

        // Create our view model for our CheckForUpdatesView
        self._checkForUpdatesViewModel = State(initialValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

final class SparkleFeedDelegate: NSObject, SPUUpdaterDelegate {
    private let lock = NSLock()
    private var feedURLStringStorage: String

    init(feedURLString: String) {
        self.feedURLStringStorage = feedURLString
    }

    func updateFeedURLString(_ value: String) {
        lock.lock()
        feedURLStringStorage = value
        lock.unlock()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        lock.lock()
        let value = feedURLStringStorage
        lock.unlock()
        return value
    }
}

// MARK: - URL Scheme Handler

/// Singleton to share pending URL across app
@MainActor
@Observable
final class URLSchemeHandler {
    private static let logger = Logger(subsystem: "com.nolon.app", category: "URLSchemeHandler")
    static let shared = URLSchemeHandler()
    
    var pendingURL: URL?
    
    private init() {}
    
    func handleURL(_ url: URL) {
        guard let httpsURL = Self.normalizeIncomingURL(url) else { return }
        Self.logger.info("Received URL: \(httpsURL.absoluteString, privacy: .public)")
        pendingURL = httpsURL
    }

    static func normalizeIncomingURL(_ url: URL) -> URL? {
        guard url.scheme == "nolon" || url.scheme == "nln" else { return nil }
        guard url.host != nil else { return nil }

        // Reconstruct the original URL:
        // nolon://github.com/owner/repo -> https://github.com/owner/repo
        // nln://github.com/owner/repo -> https://github.com/owner/repo
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.scheme = "https"
        return components?.url
    }
}

/// AppDelegate to handle URL events on macOS
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.nolon.app", category: "AppDelegate")

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        logger.info("Received URL count: \(urls.count, privacy: .public)")
        for url in urls {
            Task { @MainActor in
                URLSchemeHandler.shared.handleURL(url)
            }
        }
    }
}

@MainActor
final class CodexAuthBackgroundPoller {
    static let shared = CodexAuthBackgroundPoller()

    private static let logger = Logger(subsystem: "com.nolon.app", category: "CodexAuthBackgroundPoller")
    private let authManager = CodexAuthManager.shared
    private var pollTask: Task<Void, Never>?
    private let pollIntervalNanoseconds: UInt64 = 60 * 1_000_000_000
    private let enabledDefaultsKey = "codex.auth.background_poll.enabled"

    private init() {}

    func start() {
        guard !UITestSupport.isRunningUnitTests else { return }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoop()
        }
        Self.logger.info("Codex auth background poller started.")
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        Self.logger.info("Codex auth background poller stopped.")
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledDefaultsKey) as? Bool ?? true
    }

    private func runLoop() async {
        while !Task.isCancelled {
            if isEnabled {
                await pollOnce()
            }
            do {
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            } catch {
                break
            }
        }
    }

    private func pollOnce() async {
        let providers = ProviderSettings.shared.providers.filter { provider in
            provider.templateId == ProviderTemplate.codex.rawValue
                || provider.templateId == ProviderTemplate.codexXcode.rawValue
        }
        guard !providers.isEmpty else { return }

        for provider in providers {
            do {
                _ = try await authManager.preflightManagedAuthIfNeeded(
                    for: provider,
                    forceBackup: false,
                    reason: "background_poll"
                )
            } catch {
                Self.logger.error(
                    "Codex auth preflight failed in background poll. provider=\(provider.id, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}

@MainActor
final class CodexRuntimeHomeCleanupService {
    static let shared = CodexRuntimeHomeCleanupService()

    private static let logger = Logger(subsystem: "com.nolon.app", category: "CodexRuntimeHomeCleanup")
    private let authManager = CodexAuthManager.shared
    private var cleanupTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard !UITestSupport.isRunningUnitTests else { return }
        guard cleanupTask == nil else { return }
        cleanupTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer { self.cleanupTask = nil }
            do {
                let report = try await self.authManager.cleanupRuntimeHomesOnAppLaunch()
                Self.logger.info(
                    "Runtime home cleanup finished. scanned=\(report.scannedCount, privacy: .public) removed=\(report.removedCount, privacy: .public) active=\(report.preservedActiveCount, privacy: .public) recent=\(report.skippedRecentCount, privacy: .public) failed=\(report.failureCount, privacy: .public)"
                )
            } catch {
                Self.logger.error("Runtime home cleanup failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

#if canImport(CloudKit)
enum CodexiCloudSyncCloudKitCodec {
    nonisolated static let containerIdentifier = "iCloud.nolon.overloaded.com"
    nonisolated static let recordType = "CodexAccount"
    nonisolated static let zoneName = "CodexAccounts"
    nonisolated static let subscriptionID = "nolon.codex.accounts.subscription"
    nonisolated static let schemaVersion = 1

    enum Field {
        nonisolated static let accountPayload = "accountPayload"
        nonisolated static let metadataJSON = "metadataJSON"
        nonisolated static let recordUpdatedAt = "recordUpdatedAt"
        nonisolated static let isTombstone = "isTombstone"
        nonisolated static let originDeviceID = "originDeviceID"
        nonisolated static let schemaVersion = "schemaVersion"
    }

    nonisolated static func container() -> CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    nonisolated static func zoneID(zoneName: String = zoneName) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    nonisolated static func recordID(recordName: String, zoneName: String? = nil) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID(zoneName: zoneName ?? Self.zoneName))
    }

    nonisolated static func recordID(for change: CodexCloudSyncPendingChange) -> CKRecord.ID {
        recordID(
            recordName: change.state.cloudRecordName ?? change.account.id.uuidString,
            zoneName: change.state.cloudRecordZone
        )
    }

    nonisolated static func pendingRecordZoneChanges(
        from changes: [CodexCloudSyncPendingChange]
    ) -> [CKSyncEngine.PendingRecordZoneChange] {
        changes.map { change in
            switch change.state.syncStatus {
            case .pendingDelete:
                return .deleteRecord(recordID(for: change))
            case .pendingUpload:
                return .saveRecord(recordID(for: change))
            case .localOnly, .synced, .conflict, .invalidPending:
                return .saveRecord(recordID(for: change))
            }
        }
    }

    nonisolated static func makeRecord(
        from change: CodexCloudSyncPendingChange,
        originDeviceID: String
    ) -> CKRecord? {
        guard change.state.syncStatus != .pendingDelete,
              let authData = change.authData
        else {
            return nil
        }

        let targetRecordID = recordID(for: change)
        let record: CKRecord = {
            guard let encodedSystemFields = normalized(change.state.recordSystemFieldsBase64),
                  let data = Data(base64Encoded: encodedSystemFields),
                  let restoredRecord = makeRecord(fromSystemFieldsData: data),
                  restoredRecord.recordID == targetRecordID,
                  restoredRecord.recordType == recordType
            else {
                return CKRecord(recordType: recordType, recordID: targetRecordID)
            }
            return restoredRecord
        }()
        record[Field.accountPayload] = authData as NSData
        if let metadataJSON = normalized(change.state.conflictPayloadJSONString) {
            record[Field.metadataJSON] = metadataJSON as NSString
        }
        record[Field.recordUpdatedAt] = (change.state.recordUpdatedAt ?? Date()) as NSDate
        record[Field.isTombstone] = NSNumber(value: change.state.isTombstone)
        record[Field.originDeviceID] = originDeviceID as NSString
        record[Field.schemaVersion] = NSNumber(value: schemaVersion)
        return record
    }

    nonisolated static func makePayload(from record: CKRecord) -> CodexCloudSyncRecordPayload? {
        guard record.recordType == recordType else { return nil }

        let accountPayloadData = record[Field.accountPayload] as? Data
            ?? (record[Field.accountPayload] as? NSData).map(Data.init(referencing:))
        let metadataJSONString = normalized(record[Field.metadataJSON] as? String)
            ?? normalized((record[Field.metadataJSON] as? NSString) as String?)
        let recordUpdatedAt = (record[Field.recordUpdatedAt] as? Date)
            ?? (record[Field.recordUpdatedAt] as? NSDate).map { $0 as Date }
            ?? record.modificationDate
            ?? record.creationDate
            ?? Date()
        let isTombstone = (record[Field.isTombstone] as? NSNumber)?.boolValue ?? false
        let originDeviceID = normalized(record[Field.originDeviceID] as? String)
            ?? normalized((record[Field.originDeviceID] as? NSString) as String?)
        let schemaVersion = (record[Field.schemaVersion] as? NSNumber)?.intValue ?? schemaVersion

        return CodexCloudSyncRecordPayload(
            recordName: record.recordID.recordName,
            zoneName: record.recordID.zoneID.zoneName,
            recordSystemFieldsBase64: makeSystemFieldsData(from: record)?.base64EncodedString(),
            accountPayloadData: accountPayloadData,
            metadataJSONString: metadataJSONString,
            recordUpdatedAt: recordUpdatedAt,
            isTombstone: isTombstone,
            originDeviceID: originDeviceID,
            schemaVersion: schemaVersion
        )
    }

    nonisolated static func makeConflictPayload(from error: Error) -> CodexCloudSyncRecordPayload? {
        guard let ckError = error as? CKError,
              ckError.code == .serverRecordChanged,
              let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
        else {
            return nil
        }
        return makePayload(from: serverRecord)
    }

    nonisolated static func makeSystemFieldsData(from record: CKRecord) -> Data? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    nonisolated static func makeRecord(fromSystemFieldsData data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            return nil
        }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }

    nonisolated private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}

enum CodexiCloudSyncCloudKitRuntimeSupport {
    enum BootstrapState: Equatable {
        case ready
        case missingEntitlements
        case unreadableSigningInfo
    }

    nonisolated static func bootstrapState(
        signingEntitlements: [String: Any]? = currentSigningEntitlements()
    ) -> BootstrapState {
        guard let signingEntitlements else {
            return .unreadableSigningInfo
        }
        guard hasRequiredEntitlements(in: signingEntitlements) else {
            return .missingEntitlements
        }
        return .ready
    }

    nonisolated static func hasRequiredEntitlements(
        in signingEntitlements: [String: Any],
        containerIdentifier: String = CodexiCloudSyncCloudKitCodec.containerIdentifier
    ) -> Bool {
        let containerIdentifiers = stringArray(
            from: signingEntitlements["com.apple.developer.icloud-container-identifiers"]
        )
        let services = stringArray(
            from: signingEntitlements["com.apple.developer.icloud-services"]
        )
        return containerIdentifiers.contains(containerIdentifier) && services.contains("CloudKit")
    }

    nonisolated private static func currentSigningEntitlements() -> [String: Any]? {
        guard let executableURL = Bundle.main.executableURL else {
            return nil
        }

        var staticCode: SecStaticCode?
        let staticCodeStatus = SecStaticCodeCreateWithPath(executableURL as CFURL, [], &staticCode)
        guard staticCodeStatus == errSecSuccess, let staticCode else {
            return nil
        }

        var signingInfo: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )
        guard infoStatus == errSecSuccess,
              let signingInfoDictionary = signingInfo as? [String: Any],
              let entitlements = signingInfoDictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        else {
            return nil
        }
        return entitlements
    }

    nonisolated private static func stringArray(from value: Any?) -> [String] {
        switch value {
        case let array as [String]:
            return array
        case let array as [NSString]:
            return array.map(String.init)
        default:
            return []
        }
    }
}

actor CodexiCloudSyncLiveCoordinator: CKSyncEngineDelegate {
    private static let logger = Logger(subsystem: "com.nolon.app", category: "CodexiCloudSyncLiveCoordinator")

    private let authManager: CodexAuthManager
    private let container: CKContainer
    private let zoneID: CKRecordZone.ID
    private let stateFileURL: URL
    private let deviceIDFileURL: URL
    private var engine: CKSyncEngine?

    init(
        authManager: CodexAuthManager = .shared,
        container: CKContainer = CodexiCloudSyncCloudKitCodec.container()
    ) {
        self.authManager = authManager
        self.container = container
        self.zoneID = CodexiCloudSyncCloudKitCodec.zoneID()

        let baseURL = NolonHomeEnvironment.resolveApplicationSupportFolder(
            environment: ProcessInfo.processInfo.environment
        )
            .appendingPathComponent("nolon", isDirectory: true)
            .appendingPathComponent("codex-cloud-sync", isDirectory: true)
        self.stateFileURL = baseURL.appendingPathComponent("sync-engine-state.json", isDirectory: false)
        self.deviceIDFileURL = baseURL.appendingPathComponent("device-id.txt", isDirectory: false)
    }

    func accountAvailability() async -> CodexiCloudSyncService.Availability {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return .available
            case .restricted:
                return .restricted
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            case .noAccount:
                return .noAccount
            case .couldNotDetermine:
                return .couldNotDetermine
            @unknown default:
                return .unknown
            }
        } catch {
            Self.logger.error("CloudKit account status refresh failed: \(String(describing: error), privacy: .public)")
            return .couldNotDetermine
        }
    }

    func syncNow() async throws {
        let engine = try await ensureEngine()
        try ensurePersistenceDirectory()
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        try await primePendingChanges(in: engine)
        try await engine.sendChanges(.init(scope: .all))
        try await engine.fetchChanges(.init(scope: .zoneIDs([zoneID])))
    }

    func stop() async {
        guard let engine else { return }
        await engine.cancelOperations()
        self.engine = nil
    }

    func clearAllCloudRecords() async throws -> Int {
        if let engine {
            await engine.cancelOperations()
            self.engine = nil
        }

        let recordIDs = try await fetchAllCloudRecordIDs()
        if !recordIDs.isEmpty {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [],
                deleting: recordIDs,
                atomically: false
            )
        }

        do {
            _ = try await container.privateCloudDatabase.modifyRecordZones(
                saving: [],
                deleting: [zoneID]
            )
        } catch {
            guard isMissingZoneError(error) else { throw error }
        }

        try clearStateSerialization()
        return recordIDs.count
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            do {
                try saveStateSerialization(update.stateSerialization)
            } catch {
                Self.logger.error("Persisting CloudKit sync state failed: \(String(describing: error), privacy: .public)")
            }
        case .fetchedRecordZoneChanges(let event):
            await handleFetchedRecordZoneChanges(event)
        case .sentRecordZoneChanges(let event):
            await handleSentRecordZoneChanges(event)
        case .sentDatabaseChanges(let event):
            for failure in event.failedZoneSaves {
                Self.logger.error(
                    "CloudKit zone save failed. zone=\(failure.zone.zoneID.zoneName, privacy: .public) error=\(String(describing: failure.error), privacy: .public)"
                )
            }
            for (zoneID, error) in event.failedZoneDeletes {
                Self.logger.error(
                    "CloudKit zone delete failed. zone=\(zoneID.zoneName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pendingChanges.isEmpty else { return nil }

        let outgoingChanges = (try? await authManager.cloudSyncPendingChanges()) ?? []
        let originDeviceID = (try? localDeviceID()) ?? "unknown-device"
        var recordsByID: [CKRecord.ID: CKRecord] = [:]
        for change in outgoingChanges {
            guard let record = CodexiCloudSyncCloudKitCodec.makeRecord(
                from: change,
                originDeviceID: originDeviceID
            ) else {
                continue
            }
            recordsByID[record.recordID] = record
        }
        let immutableRecordsByID = recordsByID

        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: pendingChanges,
            recordProvider: { recordID in immutableRecordsByID[recordID] }
        )
    }

    func nextFetchChangesOptions(
        _ context: CKSyncEngine.FetchChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.FetchChangesOptions {
        .init(scope: .zoneIDs([zoneID]))
    }

    private func ensureEngine() async throws -> CKSyncEngine {
        if let engine {
            return engine
        }

        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: try loadStateSerialization(),
            delegate: self
        )
        configuration.automaticallySync = true
        configuration.subscriptionID = CodexiCloudSyncCloudKitCodec.subscriptionID

        let engine = CKSyncEngine(configuration)
        self.engine = engine
        return engine
    }

    private func primePendingChanges(in engine: CKSyncEngine) async throws {
        let pendingChanges = try await authManager.cloudSyncPendingChanges()
        guard !pendingChanges.isEmpty else { return }
        engine.state.add(
            pendingRecordZoneChanges: CodexiCloudSyncCloudKitCodec.pendingRecordZoneChanges(from: pendingChanges)
        )
    }

    private func handleFetchedRecordZoneChanges(_ event: CKSyncEngine.Event.FetchedRecordZoneChanges) async {
        for modification in event.modifications {
            guard let payload = CodexiCloudSyncCloudKitCodec.makePayload(from: modification.record) else { continue }
            do {
                _ = try await authManager.applyRemoteCloudRecord(payload, provider: nil)
            } catch {
                Self.logger.error(
                    "Applying fetched CloudKit record failed. record=\(modification.record.recordID.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        for deletion in event.deletions where deletion.recordType == CodexiCloudSyncCloudKitCodec.recordType {
            do {
                _ = try await authManager.applyRemoteCloudRecord(
                    CodexCloudSyncRecordPayload(
                        recordName: deletion.recordID.recordName,
                        zoneName: deletion.recordID.zoneID.zoneName,
                        accountPayloadData: nil,
                        metadataJSONString: nil,
                        recordUpdatedAt: Date(),
                        isTombstone: true,
                        originDeviceID: nil,
                        schemaVersion: CodexiCloudSyncCloudKitCodec.schemaVersion
                    ),
                    provider: nil
                )
            } catch {
                Self.logger.error(
                    "Applying fetched CloudKit deletion failed. record=\(deletion.recordID.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func handleSentRecordZoneChanges(_ event: CKSyncEngine.Event.SentRecordZoneChanges) async {
        for record in event.savedRecords {
            do {
                let sentAt = record.modificationDate ?? record.creationDate ?? Date()
                let originDeviceID = (record[CodexiCloudSyncCloudKitCodec.Field.originDeviceID] as? NSString) as String?
                    ?? record[CodexiCloudSyncCloudKitCodec.Field.originDeviceID] as? String
                try await authManager.markCloudSyncSent(
                    recordName: record.recordID.recordName,
                    zoneName: record.recordID.zoneID.zoneName,
                    sentAt: sentAt,
                    originDeviceID: originDeviceID,
                    systemFieldsData: CodexiCloudSyncCloudKitCodec.makeSystemFieldsData(from: record)
                )
            } catch {
                Self.logger.error(
                    "Persisting CloudKit save success failed. record=\(record.recordID.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        for deletedRecordID in event.deletedRecordIDs {
            do {
                try await authManager.markCloudSyncSent(
                    recordName: deletedRecordID.recordName,
                    zoneName: deletedRecordID.zoneID.zoneName,
                    sentAt: Date(),
                    originDeviceID: nil
                )
            } catch {
                Self.logger.error(
                    "Persisting CloudKit delete success failed. record=\(deletedRecordID.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        for failedSave in event.failedRecordSaves {
            do {
                try await authManager.markCloudSyncFailed(
                    recordName: failedSave.record.recordID.recordName,
                    message: failedSave.error.localizedDescription,
                    at: Date(),
                    suggestedStatus: failedSave.error.code == .serverRecordChanged ? .conflict : nil,
                    conflictPayload: CodexiCloudSyncCloudKitCodec.makeConflictPayload(from: failedSave.error)
                )
            } catch {
                Self.logger.error(
                    "Persisting CloudKit save failure failed. record=\(failedSave.record.recordID.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        for (recordID, error) in event.failedRecordDeletes {
            do {
                if error.code == .unknownItem {
                    try await authManager.markCloudSyncSent(
                        recordName: recordID.recordName,
                        zoneName: recordID.zoneID.zoneName,
                        sentAt: Date(),
                        originDeviceID: nil
                    )
                } else {
                    try await authManager.markCloudSyncFailed(
                        recordName: recordID.recordName,
                        message: error.localizedDescription,
                        at: Date(),
                        suggestedStatus: nil
                    )
                }
            } catch {
                Self.logger.error(
                    "Persisting CloudKit delete failure failed. record=\(recordID.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func ensurePersistenceDirectory() throws {
        try FileManager.default.createDirectory(
            at: stateFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func fetchAllCloudRecordIDs() async throws -> [CKRecord.ID] {
        let query = CKQuery(
            recordType: CodexiCloudSyncCloudKitCodec.recordType,
            predicate: NSPredicate(value: true)
        )

        var allRecordIDs: [CKRecord.ID] = []
        do {
            var response = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: zoneID,
                desiredKeys: [],
                resultsLimit: CKQueryOperation.maximumResults
            )
            allRecordIDs.append(contentsOf: response.matchResults.compactMap { recordID, result in
                guard case .success = result else { return nil }
                return recordID
            })

            while let cursor = response.queryCursor {
                response = try await container.privateCloudDatabase.records(
                    continuingMatchFrom: cursor,
                    desiredKeys: [],
                    resultsLimit: CKQueryOperation.maximumResults
                )
                allRecordIDs.append(contentsOf: response.matchResults.compactMap { recordID, result in
                    guard case .success = result else { return nil }
                    return recordID
                })
            }
        } catch {
            guard isMissingZoneError(error) else { throw error }
        }

        return allRecordIDs
    }

    private func loadStateSerialization() throws -> CKSyncEngine.State.Serialization? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: stateFileURL)
        return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) throws {
        try ensurePersistenceDirectory()
        let data = try JSONEncoder().encode(serialization)
        try data.write(to: stateFileURL, options: .atomic)
    }

    private func clearStateSerialization() throws {
        if FileManager.default.fileExists(atPath: stateFileURL.path) {
            try FileManager.default.removeItem(at: stateFileURL)
        }
    }

    private func localDeviceID() throws -> String {
        try ensurePersistenceDirectory()
        if let existing = try? String(contentsOf: deviceIDFileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty
        {
            return existing
        }

        let generated = UUID().uuidString
        try generated.write(to: deviceIDFileURL, atomically: true, encoding: .utf8)
        return generated
    }

    private func isMissingZoneError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        return ckError.code == .zoneNotFound
            || ckError.code == .userDeletedZone
            || ckError.code == .unknownItem
    }
}
#endif

@MainActor
@Observable
final class CodexiCloudSyncService {
    static let shared = CodexiCloudSyncService()

    enum OperationError: LocalizedError {
        case cloudKitUnavailable

        var errorDescription: String? {
            switch self {
            case .cloudKitUnavailable:
                return "当前构建不支持 CloudKit。"
            }
        }
    }

    enum Availability: Equatable {
        case unknown
        case unavailable
        case available
        case restricted
        case temporarilyUnavailable
        case noAccount
        case couldNotDetermine
    }

    enum Status: Equatable {
        case disabled
        case syncing
        case synced
        case paused
        case conflict
        case failed
    }

    struct Snapshot: Equatable {
        var isEnabled = false
        var availability: Availability = .unknown
        var status: Status = .disabled
        var lastSyncedAt: Date?
        var pendingChangeCount = 0
        var conflictCount = 0
        var invalidPendingCount = 0
        var recentError: String?
        var recentErrorAt: Date?
        var totalRecordCount = 0
    }

    private static let logger = Logger(subsystem: "com.nolon.app", category: "CodexiCloudSync")
    private let authManager: CodexAuthManager
    private(set) var snapshot = Snapshot()
    private var bootstrapTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    #if canImport(CloudKit)
    private let cloudKitBootstrapState: CodexiCloudSyncCloudKitRuntimeSupport.BootstrapState
    private var liveCoordinator: CodexiCloudSyncLiveCoordinator?
    #endif

    private init(authManager: CodexAuthManager = .shared) {
        self.authManager = authManager
        #if canImport(CloudKit)
        self.cloudKitBootstrapState = CodexiCloudSyncCloudKitRuntimeSupport.bootstrapState()
        self.liveCoordinator = nil
        #endif
    }

    func start() {
        guard !UITestSupport.isRunningUnitTests else { return }
        guard bootstrapTask == nil else { return }
        bootstrapTask = Task { [weak self] in
            guard let self else { return }
            defer { self.bootstrapTask = nil }
            await self.refresh()
            if self.snapshot.isEnabled, self.snapshot.availability == .available {
                await self.syncNow()
            }
        }
    }

    func refresh() async {
        await refreshSnapshot(isSyncing: false)
    }

    func setEnabled(_ enabled: Bool) async {
        do {
            try await authManager.setCloudSyncEnabled(enabled)
            Self.logger.info("Codex cloud sync toggle updated. enabled=\(enabled, privacy: .public)")
            if enabled {
                await syncNow()
            } else {
                #if canImport(CloudKit)
                if let liveCoordinator {
                    await liveCoordinator.stop()
                }
                #endif
                await refreshSnapshot(isSyncing: false)
            }
        } catch {
            Self.logger.error("Codex cloud sync toggle update failed: \(String(describing: error), privacy: .public)")
            await refreshSnapshot(isSyncing: false, transientError: error.localizedDescription)
        }
    }

    func syncNow() async {
        guard syncTask == nil else {
            await syncTask?.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshot(isSyncing: true)
            do {
                let isEnabled = (try? await self.authManager.cloudSyncConfiguration().isEnabled) ?? false
                if isEnabled {
                    let availability = await self.resolveAvailability(isEnabled: isEnabled)
                    if availability == .available {
                        #if canImport(CloudKit)
                        guard let liveCoordinator = self.makeLiveCoordinatorIfAvailable() else {
                            throw OperationError.cloudKitUnavailable
                        }
                        try await liveCoordinator.syncNow()
                        #endif
                    }
                }
                await self.refreshSnapshot(isSyncing: false)
            } catch {
                Self.logger.error("Codex cloud sync manual sync failed: \(String(describing: error), privacy: .public)")
                await self.refreshSnapshot(isSyncing: false, transientError: error.localizedDescription)
            }
        }
        syncTask = task
        await task.value
        syncTask = nil
    }

    func clearCloudData() async throws -> Int {
        #if canImport(CloudKit)
        guard let liveCoordinator = makeLiveCoordinatorIfAvailable() else {
            throw OperationError.cloudKitUnavailable
        }
        let deletedCount = try await liveCoordinator.clearAllCloudRecords()
        try await authManager.resetCloudSyncMetadataAfterRemotePurge()
        try await authManager.setCloudSyncEnabled(false)
        await refreshSnapshot(isSyncing: false)
        return deletedCount
        #else
        throw OperationError.cloudKitUnavailable
        #endif
    }

    private func refreshSnapshot(
        isSyncing: Bool,
        transientError: String? = nil
    ) async {
        let isEnabled = (try? await authManager.cloudSyncConfiguration().isEnabled) ?? false
        let overview = (try? await authManager.cloudSyncOverview()) ?? CodexCloudSyncOverview()
        let availability = await resolveAvailability(isEnabled: isEnabled)
        snapshot = Self.makeSnapshot(
            isEnabled: isEnabled,
            availability: availability,
            overview: overview,
            isSyncing: isSyncing,
            transientError: transientError
        )
        Self.logger.info(
            "Codex cloud sync snapshot refreshed. enabled=\(self.snapshot.isEnabled, privacy: .public) availability=\(String(describing: self.snapshot.availability), privacy: .public) status=\(String(describing: self.snapshot.status), privacy: .public) pending=\(self.snapshot.pendingChangeCount, privacy: .public) conflicts=\(self.snapshot.conflictCount, privacy: .public)"
        )
    }

    private func resolveAvailability(isEnabled: Bool) async -> Availability {
        guard isEnabled else {
            Self.logger.info("Codex cloud sync snapshot resolved as disabled.")
            return .unavailable
        }
        #if canImport(CloudKit)
        guard let liveCoordinator = makeLiveCoordinatorIfAvailable() else {
            return .unavailable
        }
        return await liveCoordinator.accountAvailability()
        #else
        Self.logger.info("Codex cloud sync availability unavailable because CloudKit is not supported in this build.")
        return .unavailable
        #endif
    }

    #if canImport(CloudKit)
    private func makeLiveCoordinatorIfAvailable() -> CodexiCloudSyncLiveCoordinator? {
        switch cloudKitBootstrapState {
        case .ready:
            if let liveCoordinator {
                return liveCoordinator
            }
            let coordinator = CodexiCloudSyncLiveCoordinator(authManager: authManager)
            liveCoordinator = coordinator
            return coordinator
        case .missingEntitlements:
            Self.logger.error("CloudKit bootstrap skipped because the signed app is missing required iCloud entitlements.")
            return nil
        case .unreadableSigningInfo:
            Self.logger.error("CloudKit bootstrap skipped because signing entitlements could not be read at runtime.")
            return nil
        }
    }
    #endif

    static func makeSnapshot(
        isEnabled: Bool,
        availability: Availability,
        overview: CodexCloudSyncOverview,
        isSyncing: Bool = false,
        transientError: String? = nil
    ) -> Snapshot {
        let effectiveError = normalizedMessage(transientError) ?? normalizedMessage(overview.recentError)
        let status: Status = {
            guard isEnabled else { return .disabled }
            if overview.conflictCount > 0 || overview.invalidPendingCount > 0 {
                return .conflict
            }
            if effectiveError != nil, availability == .available {
                return .failed
            }
            switch availability {
            case .available:
                if isSyncing || overview.pendingCount > 0 || overview.lastSyncedAt == nil {
                    return .syncing
                }
                return .synced
            case .unknown, .unavailable, .restricted, .temporarilyUnavailable, .noAccount, .couldNotDetermine:
                return .paused
            }
        }()

        return Snapshot(
            isEnabled: isEnabled,
            availability: availability,
            status: status,
            lastSyncedAt: overview.lastSyncedAt,
            pendingChangeCount: overview.pendingCount,
            conflictCount: overview.conflictCount,
            invalidPendingCount: overview.invalidPendingCount,
            recentError: effectiveError,
            recentErrorAt: effectiveError == nil ? nil : (transientError == nil ? overview.recentErrorAt : Date()),
            totalRecordCount: overview.totalRecordCount
        )
    }

    private static func normalizedMessage(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}

@main
struct nolonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    static var updaterController: SPUStandardUpdaterController?
    static var sparkleFeedDelegate: SparkleFeedDelegate?
    static let stableFeedURL = URL(string: "https://linhay.github.io/nolon/appcast.xml")!
    static let betaFeedURL = URL(string: "https://linhay.github.io/nolon/appcast-beta.xml")!
    static var appliedUpdateChannel: AppUpdateChannel?
    private let isRunningSwiftUIPreviews: Bool

    init() {
        self.isRunningSwiftUIPreviews = RuntimeEnvironment.isSwiftUIPreview()

        // Load provider template configurations from JSON
        ProviderTemplateLoader.shared.load()

        // Skip startup side effects in SwiftUI previews to keep launch fast/stable.
        if !isRunningSwiftUIPreviews {
            // Apply app settings (appearance, etc.)
            AppSettingsStore.shared.applyAllSettings()

            let initialFeedURL = Self.feedURL(for: AppSettingsStore.shared.updateChannel).absoluteString
            let feedDelegate = SparkleFeedDelegate(feedURLString: initialFeedURL)
            let controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: feedDelegate,
                userDriverDelegate: nil
            )
            Self.sparkleFeedDelegate = feedDelegate
            Self.updaterController = controller
            Self.applyUpdaterFeed(channel: AppSettingsStore.shared.updateChannel)
        }
    }

    static func feedURL(for channel: AppUpdateChannel) -> URL {
        switch channel {
        case .stable:
            return stableFeedURL
        case .beta:
            return betaFeedURL
        }
    }

    static func applyUpdaterFeed(channel: AppUpdateChannel) {
        guard let updater = updaterController?.updater else { return }
        let target = feedURL(for: channel).absoluteString
        sparkleFeedDelegate?.updateFeedURLString(target)
        if appliedUpdateChannel != channel {
            appliedUpdateChannel = channel
            updater.resetUpdateCycle()
        }
    }

    var body: some Scene {
        Window("nolon", id: "main") {
            rootContentView
        }
        .handlesExternalEvents(matching: [])  // Prevent new windows from URL events
        .commands {
            appCommands
        }

        Window(
            NSLocalizedString("detail.skill.window.title", value: "Skill Detail", comment: "Skill detail window title"),
            id: SkillDetailWindowCoordinator.windowID
        ) {
            SkillDetailWindowRootView()
        }
        .defaultSize(width: 1100, height: 720)

        Window(
            NSLocalizedString("resource.center.window.title", value: "Resource Center", comment: "Resource center window title"),
            id: ResourceCenterWindowCoordinator.windowID
        ) {
            ResourceCenterWindowRootView()
        }
        .defaultSize(width: 1180, height: 780)

        MenuBarExtra("nolon", systemImage: "arrow.triangle.2.circlepath.circle") {
            CodexQuickSwitchMenuBarView()
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var rootContentView: some View {
        if isRunningSwiftUIPreviews {
            PreviewBootstrapView()
        } else {
            ContentView()
                .onOpenURL { url in
                    URLSchemeHandler.shared.handleURL(url)
                }
                .task {
                    if !UITestSupport.isRunningUnitTests {
                        CodexiCloudSyncService.shared.start()
                        CodexRuntimeHomeCleanupService.shared.start()
                        CodexAuthBackgroundPoller.shared.start()
                    }
                }
        }
    }

    @CommandsBuilder
    private var appCommands: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .appSettings) {
            Button(NSLocalizedString("settings.app", value: "Settings...", comment: "Menu item")) {
                AppCommandState.shared.showingSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        #if DEBUG
        CommandMenu(NSLocalizedString("debug.menu.title", value: "Debug", comment: "Debug menu")) {
            Toggle(
                NSLocalizedString("debug.menu.page_markers", value: "Show Page Markers", comment: "Toggle debug page markers"),
                isOn: Binding(
                    get: { AppCommandState.shared.isDebugPageMarkersEnabled },
                    set: { AppCommandState.shared.isDebugPageMarkersEnabled = $0 }
                )
            )
        }
        #endif
        
        CommandGroup(after: .appInfo) {
            if let controller = Self.updaterController {
                CheckForUpdatesView(updater: controller.updater)
            }
        }
    }
}

private struct PreviewBootstrapView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
    }
}
