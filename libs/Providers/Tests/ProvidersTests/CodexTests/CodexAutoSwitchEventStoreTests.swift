import Foundation
import Testing
import STFilePath
@testable import ProviderUsage

@Suite("CodexAutoSwitchEventStore")
struct CodexAutoSwitchEventStoreTests {
    @Test("Given events are appended, when loading recent events, then they are returned in reverse chronological order")
    func recentEventsAreReturnedNewestFirst() async throws {
        let root = try makeTempRoot("codex-auto-switch-events")
        defer { try? root.delete() }

        let file = root.file("events.jsonl")
        let store = CodexAutoSwitchEventStore(file: file)

        let first = CodexAutoSwitchEvent(
            providerID: "codex",
            reason: .thresholdNotReached,
            fromAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
            toAccountID: nil,
            currentRemainingPercent: 42,
            targetRemainingPercent: nil,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            cooldownUntil: nil
        )
        let second = CodexAutoSwitchEvent(
            providerID: "codex",
            reason: .switched,
            fromAccountID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
            toAccountID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"),
            currentRemainingPercent: 5,
            targetRemainingPercent: 78,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_100),
            cooldownUntil: nil
        )

        try await store.append(first)
        try await store.append(second)

        let events = await store.recentEvents(limit: 2)
        #expect(events == [second, first])
    }

    @Test("Given status snapshot is saved, when loading it back, then the latest decision is preserved")
    func statusSnapshotRoundTrips() async throws {
        let root = try makeTempRoot("codex-auto-switch-status")
        defer { try? root.delete() }

        let file = root.file("status.json")
        let store = CodexAutoSwitchStatusStore(file: file)
        let snapshot = CodexAutoSwitchStatusSnapshot(
            providerID: "codex",
            config: CodexAutoSwitchConfig(enabled: true, thresholdPercent: 15),
            lastDecision: CodexAutoSwitchDecision(
                reason: .switched,
                fromAccountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
                toAccountID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
                currentRemainingPercent: 9,
                targetRemainingPercent: 80,
                checkedAt: Date(timeIntervalSince1970: 1_700_000_200)
            ),
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_200)
        )

        try await store.save(snapshot)
        let loaded = await store.load()

        #expect(loaded == snapshot)
    }

    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        let folder = STFolder(url)
        _ = folder.createIfNotExists()
        return folder
    }
}
