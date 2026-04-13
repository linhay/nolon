import XCTest
import NolonUIFoundation
@testable import nolon

final class CodexSessionsSectionDataBuilderTests: XCTestCase {
    func testBDD_GivenEditableAndReadOnlySessions_WhenBuildingSectionData_ThenEverySessionShowsInFinderAndEditableRowsKeepRewriteActions() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_712_812_800)
        let section = CodexSessionsTabViewModel.SessionSection(
            id: "provider:provider-two",
            title: "provider-two",
            rewriteSourceLabel: "provider-two",
            rewriteSourceProviderID: "provider-two",
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-live",
                    title: "Live Session",
                    summary: "Investigate rollout drift after account relink.",
                    modelProvider: "provider-two",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: updatedAt,
                    stateRowCount: 3,
                    editable: true
                ),
                .init(
                    id: "archived_sessions/archive-b.jsonl",
                    threadID: nil,
                    title: "Archived Session",
                    summary: "Historical session retained for verification.",
                    modelProvider: "provider-two",
                    archived: true,
                    rolloutPath: "archived_sessions/archive-b.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: updatedAt.addingTimeInterval(-3_600),
                    stateRowCount: 1,
                    editable: false
                ),
            ],
            totalSessionCount: 2,
            editableThreadIDs: ["thread-live"],
            liveCount: 1,
            archivedCount: 1,
            providerCount: 1,
            isCollapsed: true
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .provider,
            targetProviders: { currentProviderID in
                XCTAssertEqual(currentProviderID, "provider-two")
                return ["openai", "provider-three"]
            }
        )

        XCTAssertEqual(data.rows.count, 2)
        XCTAssertTrue(data.isCollapsed)
        let showInFinderTitle = NSLocalizedString(
            "action.show_in_finder",
            value: "Show in Finder",
            comment: "Show in Finder"
        )
        XCTAssertEqual(data.rows.map(\.showInFinderTitle), [showInFinderTitle, showInFinderTitle])

        let editableRow = try XCTUnwrap(data.rows.first)
        XCTAssertEqual(editableRow.actions.map(\.targetProviderID), ["openai", "provider-three"])
        XCTAssertEqual(
            editableRow.actionMenuTitle,
            NSLocalizedString(
                "codex.sessions.action.move_session",
                value: "Move Session",
                comment: "Move single session"
            )
        )
        XCTAssertNil(editableRow.readOnlyText)

        let readOnlyRow = try XCTUnwrap(data.rows.last)
        XCTAssertTrue(readOnlyRow.actions.isEmpty)
        XCTAssertNil(readOnlyRow.actionMenuTitle)
        XCTAssertEqual(
            readOnlyRow.readOnlyText,
            NSLocalizedString(
                "codex.sessions.read_only",
                value: "Read Only",
                comment: "Read only session label"
            )
        )
    }
}
