import XCTest
import NolonUIFoundation
@testable import nolon

final class CodexSessionsSectionDataBuilderTests: XCTestCase {
    func testBDD_GivenKnownProviderGroup_WhenBuildingSectionData_ThenUsesDisplayNameRawIDAndRewritablePresentation() throws {
        let section = makeSection(
            title: "openai",
            rewriteSourceLabel: "openai",
            rewriteSourceProviderID: "openai",
            providerCount: 1,
            editableThreadIDs: ["thread-live"]
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .provider,
            targetProviders: { currentProviderID in
                XCTAssertEqual(currentProviderID, "openai")
                return ["anthropic", "gemini"]
            }
        )

        XCTAssertEqual(data.presentationKind, .rewritableGroup)
        XCTAssertEqual(data.title, "OpenAI")
        XCTAssertEqual(data.titleSecondaryText, "openai")
        XCTAssertNil(data.subtitle)
        XCTAssertEqual(
            data.actions.map(\.title),
            [
                String(
                    format: NSLocalizedString(
                        "codex.sessions.action.move_group_to",
                        value: "Move Group to %@",
                        comment: "Move provider group to target provider"
                    ),
                    "Anthropic (anthropic)"
                ),
                String(
                    format: NSLocalizedString(
                        "codex.sessions.action.move_group_to",
                        value: "Move Group to %@",
                        comment: "Move provider group to target provider"
                    ),
                    "Gemini (gemini)"
                ),
            ]
        )
    }

    func testBDD_GivenMixedProviderTimeProjectGroup_WhenBuildingSectionData_ThenKeepsUnknownIDsAndUsesSingleSessionOnlyPresentation() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_712_812_800)
        let section = CodexSessionsTabViewModel.SessionSection(
            id: "time-project:2026-04-14|project-alpha",
            title: "2026-04-14 · project-alpha",
            rewriteSourceLabel: "2026-04-14 · project-alpha",
            rewriteSourceProviderID: nil,
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-live",
                    title: "Live Session",
                    summary: "Investigate rollout drift after account relink.",
                    modelProvider: "custom-relay",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: updatedAt,
                    stateRowCount: 3,
                    editable: true
                ),
                .init(
                    id: "sessions/archive-b.jsonl",
                    threadID: "thread-archive",
                    title: "Archive Session",
                    summary: "Historical verification row.",
                    modelProvider: "openai",
                    archived: true,
                    rolloutPath: "sessions/archive-b.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: updatedAt.addingTimeInterval(-600),
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            totalSessionCount: 2,
            editableThreadIDs: [],
            liveCount: 1,
            archivedCount: 1,
            providerCount: 2
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .timeProject,
            targetProviders: { providerID in
                switch providerID {
                case "custom-relay":
                    return ["openai"]
                case "openai":
                    return ["anthropic"]
                default:
                    XCTFail("Unexpected provider \(providerID)")
                    return []
                }
            }
        )

        XCTAssertEqual(data.presentationKind, .singleSessionOnly)
        XCTAssertEqual(
            data.subtitle,
            NSLocalizedString(
                "codex.sessions.section.subtitle.multi_provider",
                value: "This group contains multiple providers, so only single-session rewrite is available.",
                comment: "Multi-provider section subtitle"
            )
        )
        XCTAssertNil(data.titleSecondaryText)
        XCTAssertEqual(data.rows.map(\.providerName), ["custom-relay", "OpenAI (openai)"])
    }

    func testBDD_GivenEditableAndReadOnlyRows_WhenBuildingSectionData_ThenMovesStayPrimaryAndDiagnosticsMoveIntoMore() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_712_812_800)
        let section = makeSection(
            title: "provider-two",
            rewriteSourceLabel: "provider-two",
            rewriteSourceProviderID: "provider-two",
            providerCount: 1,
            editableThreadIDs: ["thread-live"],
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
            ]
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .provider,
            targetProviders: { currentProviderID in
                XCTAssertEqual(currentProviderID, "provider-two")
                return ["openai"]
            }
        )

        XCTAssertEqual(data.rows.count, 2)

        let editableRow = try XCTUnwrap(data.rows.first)
        XCTAssertEqual(editableRow.actions.map(\.targetProviderID), ["openai"])
        XCTAssertEqual(
            editableRow.actions.first?.title,
            String(
                format: NSLocalizedString(
                    "codex.sessions.action.move_session_to",
                    value: "Move Session to %@",
                    comment: "Move single session to target provider"
                ),
                "OpenAI (openai)"
            )
        )
        XCTAssertNil(editableRow.actionMenuTitle)
        XCTAssertEqual(
            editableRow.copyPathTitle,
            NSLocalizedString(
                "action.copy_path",
                value: "Copy Path",
                comment: "Copy a file path"
            )
        )
        XCTAssertEqual(editableRow.stateRowCount, 3)
        XCTAssertEqual(
            editableRow.showInFinderTitle,
            NSLocalizedString(
                "action.show_in_finder",
                value: "Show in Finder",
                comment: "Show in Finder"
            )
        )

        let readOnlyRow = try XCTUnwrap(data.rows.last)
        XCTAssertTrue(readOnlyRow.actions.isEmpty)
        XCTAssertNil(readOnlyRow.actionMenuTitle)
        XCTAssertEqual(
            readOnlyRow.copyPathTitle,
            NSLocalizedString(
                "action.copy_path",
                value: "Copy Path",
                comment: "Copy a file path"
            )
        )
        XCTAssertEqual(readOnlyRow.stateRowCount, 1)
        XCTAssertEqual(
            readOnlyRow.readOnlyText,
            NSLocalizedString(
                "codex.sessions.read_only",
                value: "Read Only",
                comment: "Read only session label"
            )
        )
    }

    private func makeSection(
        title: String,
        rewriteSourceLabel: String,
        rewriteSourceProviderID: String?,
        providerCount: Int,
        editableThreadIDs: [String],
        sessions: [CodexSessionsTabViewModel.SessionRow]? = nil
    ) -> CodexSessionsTabViewModel.SessionSection {
        let updatedAt = Date(timeIntervalSince1970: 1_712_812_800)
        let defaultSessions = sessions ?? [
            .init(
                id: "sessions/live-a.jsonl",
                threadID: "thread-live",
                title: "Live Session",
                summary: "Investigate rollout drift after account relink.",
                modelProvider: title,
                archived: false,
                rolloutPath: "sessions/live-a.jsonl",
                cwd: "/tmp/project-alpha",
                updatedAt: updatedAt,
                stateRowCount: 3,
                editable: true
            )
        ]

        return CodexSessionsTabViewModel.SessionSection(
            id: "section:\(title)",
            title: title,
            rewriteSourceLabel: rewriteSourceLabel,
            rewriteSourceProviderID: rewriteSourceProviderID,
            sessions: defaultSessions,
            totalSessionCount: defaultSessions.count,
            editableThreadIDs: editableThreadIDs,
            liveCount: defaultSessions.filter { !$0.archived }.count,
            archivedCount: defaultSessions.filter(\.archived).count,
            providerCount: providerCount,
            isCollapsed: true
        )
    }
}
