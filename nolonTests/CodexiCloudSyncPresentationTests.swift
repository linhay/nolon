import Testing
import Foundation
import ProviderUsage
@testable import nolon
#if canImport(CloudKit)
import CloudKit
#endif

@MainActor
struct CodexiCloudSyncPresentationTests {
    @Test("BDD: Given cloud sync disabled when building service snapshot then status stays disabled by default")
    func testBDD_GivenCloudSyncDisabled_WhenBuildingSnapshot_ThenStatusStaysDisabled() {
        let snapshot = CodexiCloudSyncService.makeSnapshot(
            isEnabled: false,
            availability: .unknown,
            overview: .init()
        )

        #expect(snapshot.isEnabled == false)
        #expect(snapshot.status == .disabled)
        #expect(snapshot.pendingChangeCount == 0)
    }

    @Test("BDD: Given enabled cloud sync with pending changes when building service snapshot then status resolves to syncing")
    func testBDD_GivenPendingChanges_WhenBuildingSnapshot_ThenStatusResolvesToSyncing() {
        let snapshot = CodexiCloudSyncService.makeSnapshot(
            isEnabled: true,
            availability: .available,
            overview: .init(
                totalRecordCount: 3,
                syncedCount: 1,
                pendingCount: 2,
                conflictCount: 0,
                invalidPendingCount: 0,
                lastSyncedAt: nil,
                recentError: nil,
                recentErrorAt: nil
            )
        )

        #expect(snapshot.status == .syncing)
        #expect(snapshot.totalRecordCount == 3)
        #expect(snapshot.pendingChangeCount == 2)
    }

    @Test("BDD: Given enabled cloud sync with conflicts when building service snapshot then conflict state wins over availability")
    func testBDD_GivenConflict_WhenBuildingSnapshot_ThenConflictStateWins() {
        let snapshot = CodexiCloudSyncService.makeSnapshot(
            isEnabled: true,
            availability: .available,
            overview: .init(
                totalRecordCount: 2,
                syncedCount: 1,
                pendingCount: 0,
                conflictCount: 1,
                invalidPendingCount: 0,
                lastSyncedAt: Date(timeIntervalSince1970: 10),
                recentError: "stale",
                recentErrorAt: Date(timeIntervalSince1970: 9)
            )
        )

        #expect(snapshot.status == .conflict)
        #expect(snapshot.conflictCount == 1)
    }

    @Test("BDD: Given failed cloud sync state when feature is off then account footer hides cloud sync tag and trailing text")
    func testBDD_GivenFailedCloudState_WhenFeatureIsOff_ThenCloudSyncFooterStaysHidden() {
        let state = CodexCloudSyncState(
            accountID: UUID(),
            syncStatus: .invalidPending,
            isTombstone: true,
            lastError: "cloud tombstone blocked activation"
        )

        #expect(ProviderUsageAccountsViewModel.CodexState.cloudSyncStatusTag(for: state) == nil)
        #expect(ProviderUsageAccountsViewModel.CodexState.cloudSyncTrailingText(for: state) == nil)
    }

    #if canImport(CloudKit)
    @Test("BDD: Given pending cloud changes when mapping to CKSyncEngine queue then uploads and tombstones become save/delete operations")
    func testBDD_GivenPendingChanges_WhenEncodingPendingOperations_ThenCloudKitQueueMatchesStatus() {
        let uploadAccount = CodexAuthAccount(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "upload",
            createdAt: Date(timeIntervalSince1970: 10),
            relativeAuthPath: "auth/upload.json"
        )
        let deleteAccount = CodexAuthAccount(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "delete",
            createdAt: Date(timeIntervalSince1970: 20),
            relativeAuthPath: "auth/delete.json"
        )

        let operations = CodexiCloudSyncCloudKitCodec.pendingRecordZoneChanges(
            from: [
                CodexCloudSyncPendingChange(
                    account: uploadAccount,
                    state: .init(
                        accountID: uploadAccount.id,
                        cloudRecordName: uploadAccount.id.uuidString,
                        cloudRecordZone: "CodexAccounts",
                        recordUpdatedAt: Date(timeIntervalSince1970: 30),
                        syncStatus: .pendingUpload,
                        isTombstone: false
                    ),
                    authData: Data(#"{"email":"upload@example.com"}"#.utf8)
                ),
                CodexCloudSyncPendingChange(
                    account: deleteAccount,
                    state: .init(
                        accountID: deleteAccount.id,
                        cloudRecordName: deleteAccount.id.uuidString,
                        cloudRecordZone: "CodexAccounts",
                        recordUpdatedAt: Date(timeIntervalSince1970: 40),
                        syncStatus: .pendingDelete,
                        isTombstone: true
                    ),
                    authData: nil
                ),
            ]
        )

        #expect(operations.count == 2)
        switch operations[0] {
        case .saveRecord(let recordID):
            #expect(recordID.recordName == uploadAccount.id.uuidString)
            #expect(recordID.zoneID.zoneName == "CodexAccounts")
        default:
            Issue.record("expected saveRecord for pending upload")
        }
        switch operations[1] {
        case .deleteRecord(let recordID):
            #expect(recordID.recordName == deleteAccount.id.uuidString)
            #expect(recordID.zoneID.zoneName == "CodexAccounts")
        default:
            Issue.record("expected deleteRecord for pending tombstone")
        }
    }

    @Test("BDD: Given pending upload change when encoding CKRecord then record stores auth payload and sync metadata")
    func testBDD_GivenPendingUpload_WhenEncodingCKRecord_ThenRecordContainsExpectedFields() throws {
        let accountID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let updatedAt = Date(timeIntervalSince1970: 55)
        let change = CodexCloudSyncPendingChange(
            account: .init(
                id: accountID,
                name: "upload",
                createdAt: Date(timeIntervalSince1970: 44),
                relativeAuthPath: "auth/upload.json"
            ),
            state: .init(
                accountID: accountID,
                cloudRecordName: accountID.uuidString,
                cloudRecordZone: "CodexAccounts",
                recordUpdatedAt: updatedAt,
                syncStatus: .pendingUpload,
                isTombstone: false,
                conflictPayloadJSONString: #"{"source":"local"}"#
            ),
            authData: Data(#"{"email":"codec@example.com"}"#.utf8)
        )

        let record = try #require(
            CodexiCloudSyncCloudKitCodec.makeRecord(from: change, originDeviceID: "device-a")
        )

        #expect(record.recordType == CodexiCloudSyncCloudKitCodec.recordType)
        #expect(record.recordID.recordName == accountID.uuidString)
        #expect(record.recordID.zoneID.zoneName == "CodexAccounts")
        #expect((record[CodexiCloudSyncCloudKitCodec.Field.accountPayload] as? NSData) != nil)
        #expect((record[CodexiCloudSyncCloudKitCodec.Field.metadataJSON] as? NSString) as String? == #"{"source":"local"}"#)
        #expect((record[CodexiCloudSyncCloudKitCodec.Field.originDeviceID] as? NSString) as String? == "device-a")
        #expect((record[CodexiCloudSyncCloudKitCodec.Field.isTombstone] as? NSNumber)?.boolValue == false)
        #expect((record[CodexiCloudSyncCloudKitCodec.Field.recordUpdatedAt] as? NSDate).map { $0 as Date } == updatedAt)
    }

    @Test("BDD: Given CloudKit record when decoding remote payload then provider-facing payload preserves record identity and auth blob")
    func testBDD_GivenCloudKitRecord_WhenDecodingPayload_ThenProviderPayloadIsRecoverable() throws {
        let recordID = CKRecord.ID(
            recordName: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD",
            zoneID: CodexiCloudSyncCloudKitCodec.zoneID()
        )
        let record = CKRecord(recordType: CodexiCloudSyncCloudKitCodec.recordType, recordID: recordID)
        let authData = Data(#"{"email":"remote@example.com"}"#.utf8)
        let updatedAt = Date(timeIntervalSince1970: 88)
        record[CodexiCloudSyncCloudKitCodec.Field.accountPayload] = authData as NSData
        record[CodexiCloudSyncCloudKitCodec.Field.recordUpdatedAt] = updatedAt as NSDate
        record[CodexiCloudSyncCloudKitCodec.Field.originDeviceID] = "device-b" as NSString
        record[CodexiCloudSyncCloudKitCodec.Field.schemaVersion] = NSNumber(value: 1)

        let payload = try #require(CodexiCloudSyncCloudKitCodec.makePayload(from: record))
        #expect(payload.recordName == recordID.recordName)
        #expect(payload.zoneName == CodexiCloudSyncCloudKitCodec.zoneName)
        #expect(payload.accountPayloadData == authData)
        #expect(payload.recordUpdatedAt == updatedAt)
        #expect(payload.originDeviceID == "device-b")
        #expect(payload.isTombstone == false)
        #expect(payload.schemaVersion == 1)
    }

    @Test("BDD: Given CloudKit record metadata when archiving and restoring system fields then record identity remains reusable for later saves")
    func testBDD_GivenCloudKitSystemFields_WhenRoundTripping_ThenRecordCanBeRestored() throws {
        let recordID = CKRecord.ID(
            recordName: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
            zoneID: CodexiCloudSyncCloudKitCodec.zoneID()
        )
        let record = CKRecord(recordType: CodexiCloudSyncCloudKitCodec.recordType, recordID: recordID)

        let systemFieldsData = try #require(CodexiCloudSyncCloudKitCodec.makeSystemFieldsData(from: record))
        let restoredRecord = try #require(CodexiCloudSyncCloudKitCodec.makeRecord(fromSystemFieldsData: systemFieldsData))

        #expect(restoredRecord.recordID == recordID)
        #expect(restoredRecord.recordType == CodexiCloudSyncCloudKitCodec.recordType)
    }

    @Test("BDD: Given mixed codex cloud states when building attention items then invalid pending rows sort ahead of conflicts and healthy rows are filtered out")
    func testBDD_GivenMixedCloudStates_WhenBuildingAttentionItems_ThenOnlyAttentionRowsRemainInStableOrder() {
        let olderConflict = CodexAuthAccount(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Older Conflict",
            createdAt: Date(timeIntervalSince1970: 10),
            relativeAuthPath: "auth/older-conflict.json"
        )
        let invalidPending = CodexAuthAccount(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Invalid Pending",
            createdAt: Date(timeIntervalSince1970: 20),
            relativeAuthPath: "auth/invalid.json"
        )
        let healthy = CodexAuthAccount(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Healthy",
            createdAt: Date(timeIntervalSince1970: 30),
            relativeAuthPath: "auth/healthy.json"
        )
        let newerConflict = CodexAuthAccount(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Newer Conflict",
            createdAt: Date(timeIntervalSince1970: 40),
            relativeAuthPath: "auth/newer-conflict.json"
        )

        let items = ProviderUsageAccountsViewModel.CodexState.makeCloudAttentionItems(
            accounts: [olderConflict, invalidPending, healthy, newerConflict],
            states: [
                olderConflict.id: .init(accountID: olderConflict.id, syncStatus: .conflict, isTombstone: false),
                invalidPending.id: .init(accountID: invalidPending.id, syncStatus: .invalidPending, isTombstone: true),
                healthy.id: .init(accountID: healthy.id, syncStatus: .synced, isTombstone: false),
                newerConflict.id: .init(accountID: newerConflict.id, syncStatus: .conflict, isTombstone: false),
            ]
        )

        #expect(items.map(\.account.id) == [invalidPending.id, newerConflict.id, olderConflict.id])
    }

    @Test("BDD: Given server-record-changed CloudKit error when extracting conflict payload then server record becomes provider-facing remote payload")
    func testBDD_GivenServerRecordChangedError_WhenExtractingConflictPayload_ThenServerRecordPayloadIsRecoverable() throws {
        let recordID = CKRecord.ID(
            recordName: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE",
            zoneID: CodexiCloudSyncCloudKitCodec.zoneID()
        )
        let serverRecord = CKRecord(recordType: CodexiCloudSyncCloudKitCodec.recordType, recordID: recordID)
        let authData = Data(#"{"email":"server-record@example.com"}"#.utf8)
        let updatedAt = Date(timeIntervalSince1970: 123)
        serverRecord[CodexiCloudSyncCloudKitCodec.Field.accountPayload] = authData as NSData
        serverRecord[CodexiCloudSyncCloudKitCodec.Field.recordUpdatedAt] = updatedAt as NSDate
        serverRecord[CodexiCloudSyncCloudKitCodec.Field.originDeviceID] = "device-server" as NSString
        serverRecord[CodexiCloudSyncCloudKitCodec.Field.schemaVersion] = NSNumber(value: 1)

        let error = CKError(
            .serverRecordChanged,
            userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord]
        )

        let payload = try #require(CodexiCloudSyncCloudKitCodec.makeConflictPayload(from: error))
        #expect(payload.recordName == recordID.recordName)
        #expect(payload.accountPayloadData == authData)
        #expect(payload.recordUpdatedAt == updatedAt)
        #expect(payload.originDeviceID == "device-server")
    }

    @Test("BDD: Given conflict state with stored remote payload when evaluating attention actions then adopt-remote entry is available")
    func testBDD_GivenConflictStateWithStoredPayload_WhenEvaluatingAttentionActions_ThenAdoptRemoteIsAvailable() {
        let payload = CodexCloudSyncRecordPayload(
            recordName: UUID().uuidString,
            zoneName: "CodexAccounts",
            accountPayloadData: Data(#"{"email":"remote@example.com"}"#.utf8),
            metadataJSONString: nil,
            recordUpdatedAt: Date(timeIntervalSince1970: 456),
            isTombstone: false,
            originDeviceID: "device-server",
            schemaVersion: 1
        )
        let conflictState = CodexCloudSyncState(
            accountID: UUID(),
            syncStatus: .conflict,
            isTombstone: false,
            conflictPayloadJSONString: payload.encodedJSONString()
        )
        let invalidState = CodexCloudSyncState(
            accountID: UUID(),
            syncStatus: .invalidPending,
            isTombstone: true,
            conflictPayloadJSONString: payload.encodedJSONString()
        )

        #expect(ProviderUsageAccountsViewModel.CodexState.canAdoptRemoteCloudConflict(for: conflictState) == true)
        #expect(ProviderUsageAccountsViewModel.CodexState.canAdoptRemoteCloudConflict(for: invalidState) == false)
    }

    @Test("BDD: Given cloud sync is disabled by product when evaluating runtime bootstrap then CloudKit startup is blocked before entitlement checks")
    func testBDD_GivenCloudSyncDisabledByProduct_WhenEvaluatingRuntimeBootstrap_ThenStartupIsBlockedBeforeEntitlementChecks() {
        let bootstrapState = CodexiCloudSyncCloudKitRuntimeSupport.bootstrapState(
            signingEntitlements: [
                "com.apple.developer.icloud-services": ["CloudKit"]
            ]
        )

        #expect(bootstrapState == .productDisabled)
    }

    @Test("BDD: Given cloud sync state is present on account cards when feature is off then cloud sync badges stay hidden")
    func testBDD_GivenCloudSyncStatePresent_WhenFeatureIsOff_ThenCloudSyncBadgesStayHidden() {
        let cloudState = CodexCloudSyncState(
            accountID: UUID(),
            lastSyncedAt: Date(timeIntervalSince1970: 456),
            syncStatus: .synced,
            isTombstone: false
        )

        #expect(ProviderUsageAccountsViewModel.CodexState.cloudSyncStatusTag(for: cloudState) == nil)
        #expect(ProviderUsageAccountsViewModel.CodexState.cloudSyncTrailingText(for: cloudState) == nil)
    }
    #endif
}
