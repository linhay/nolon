import XCTest
import NolonUIFoundation
@testable import nolon

final class CodexSessionsShareContentBuilderTests: XCTestCase {
    func testBDD_GivenDetailPanelData_WhenBuildingSessionShareData_ThenIncludesCoreSessionFacts() throws {
        let payload = try XCTUnwrap(
            CodexSessionsShareContentBuilder.makeSessionShareData(
                from: .init(
                    threadIDText: "thread-refactor",
                    threadIDCopyValue: "thread-refactor",
                    providerText: "OpenAI (openai)",
                    startedAtText: "2026-04-15 19:58",
                    lastActivityText: "2026-04-15 20:30",
                    projectPath: "/tmp/project-alpha",
                    groupTitle: "project-alpha",
                    summary: "Move dense row metadata into an inline panel so browsing stays stable in large session lists.",
                    usage: .init(
                        totalText: "3.0K",
                        inputText: "2.4K",
                        outputText: "600",
                        cachedText: "400",
                        isPlaceholder: false
                    ),
                    rolloutPath: "sessions/2026/04/15/refactor.jsonl",
                    stateRowCount: 8,
                    metadataItems: [],
                    statusTexts: ["Live"],
                    resumeCommand: "codex resume --last thread-refactor",
                    shareData: nil,
                    rowData: .init(
                        id: "sessions/2026/04/15/refactor.jsonl",
                        title: "Refactor session detail layout",
                        idText: "thread-refactor",
                        timeText: "2026-04-15 20:30",
                        providerText: "OpenAI (openai)",
                        usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
                        isArchived: false,
                        isEditable: true,
                        summary: "Move dense row metadata into an inline panel so browsing stays stable in large session lists.",
                        rolloutPath: "sessions/2026/04/15/refactor.jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        actions: [],
                        readOnlyText: nil
                    )
                )
            )
        )
        let threadIDLabel = NSLocalizedString(
            "codex.sessions.detail.thread_id",
            value: "Thread ID",
            comment: "Thread identifier"
        )
        let providerLabel = NSLocalizedString(
            "codex.sessions.table.provider",
            value: "Provider",
            comment: "Session table column header"
        )
        let groupLabel = NSLocalizedString(
            "codex.sessions.share.group",
            value: "Group",
            comment: "Session share group label"
        )
        let projectLabel = NSLocalizedString(
            "codex.sessions.detail.copy_project",
            value: "Project",
            comment: "Project path"
        )
        let startedLabel = NSLocalizedString(
            "codex.sessions.share.started",
            value: "Started",
            comment: "Session share started time label"
        )
        let lastActivityLabel = NSLocalizedString(
            "codex.sessions.share.last_activity",
            value: "Last Activity",
            comment: "Session share last activity label"
        )
        let usageLabel = NSLocalizedString(
            "codex.sessions.table.usage",
            value: "Usage",
            comment: "Session table column header"
        )
        let commandLabel = NSLocalizedString(
            "codex.sessions.share.command",
            value: "Command",
            comment: "Session share command label"
        )
        let rolloutLabel = NSLocalizedString(
            "codex.sessions.share.rollout",
            value: "Rollout",
            comment: "Session share rollout label"
        )

        XCTAssertEqual(payload.title, "Refactor session detail layout")
        XCTAssertTrue(payload.item.contains("\(threadIDLabel): thread-refactor"))
        XCTAssertTrue(payload.item.contains("\(providerLabel): OpenAI (openai)"))
        XCTAssertTrue(payload.item.contains("\(groupLabel): project-alpha"))
        XCTAssertTrue(payload.item.contains("\(projectLabel): /tmp/project-alpha"))
        XCTAssertTrue(payload.item.contains("\(startedLabel): 2026-04-15 19:58"))
        XCTAssertTrue(payload.item.contains("\(lastActivityLabel): 2026-04-15 20:30"))
        XCTAssertTrue(payload.item.contains("\(usageLabel): 3.0K"))
        XCTAssertTrue(payload.item.contains("\(commandLabel): codex resume --last thread-refactor"))
        XCTAssertTrue(payload.item.contains("\(rolloutLabel): sessions/2026/04/15/refactor.jsonl"))
    }
}
