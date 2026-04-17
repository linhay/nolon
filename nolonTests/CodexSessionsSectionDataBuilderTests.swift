import XCTest
import CodexProvider
import NolonUIFoundation
@testable import nolon

final class CodexSessionsSectionDataBuilderTests: XCTestCase {
    func testBDD_GivenProjectSection_WhenBuildingSectionData_ThenUsesFixedColumnsAndExpansionCopy() throws {
        let section = makeSection(
            title: "project-alpha",
            titleSecondaryText: "/tmp/project-alpha",
            rewriteSourceProviderID: "openai",
            providerCount: 1,
            totalSessionCount: 8,
            visibleCount: 5,
            isExpanded: false
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .project,
            targetProviders: { currentProviderID in
                XCTAssertEqual(currentProviderID, "openai")
                return ["anthropic"]
            },
            usageState: { _ in .placeholder }
        )

        XCTAssertEqual(data.title, "project-alpha")
        XCTAssertEqual(data.titleSecondaryText, "/tmp/project-alpha")
        XCTAssertEqual(data.actionMenuTitle, "Move Project Sessions")
        XCTAssertEqual(data.expansionTitle, "Expand 3 More")
        XCTAssertEqual(data.badges.map(\.id), ["live", "archived"])

        let row = try XCTUnwrap(data.rows.first)
        XCTAssertEqual(row.idText, "thread-live")
        XCTAssertEqual(
            row.idSecondaryText,
            String(
                format: NSLocalizedString(
                    "codex.sessions.metadata.forked_from",
                    value: "Forked from %@",
                    comment: "Codex sessions forked from metadata"
                ),
                "parent-thre…"
            )
        )
        XCTAssertEqual(row.providerText, "OpenAI (openai)")
        XCTAssertEqual(row.timeText, "2024-04-11 10:00")
        XCTAssertEqual(row.usage, .placeholder(text: "Loading…"))
        XCTAssertTrue(row.nameMetadataItems.isEmpty)
        XCTAssertEqual(
            row.menuMetadataItems.map { $0.text },
            [
                String(
                    format: NSLocalizedString(
                        "codex.sessions.metadata.forked_from",
                        value: "Forked from %@",
                        comment: "Codex sessions forked from metadata"
                    ),
                    "parent-thread-123456"
                ),
                String(
                    format: NSLocalizedString(
                        "codex.sessions.metadata.source",
                        value: "Source: %@",
                        comment: "Codex sessions source metadata"
                    ),
                    "cli"
                ),
                String(
                    format: NSLocalizedString(
                        "codex.sessions.metadata.originator",
                        value: "Originator: %@",
                        comment: "Codex sessions originator metadata"
                    ),
                    "codex"
                ),
            ]
        )
    }

    func testBDD_GivenMixedProviderProjectSection_WhenBuildingSectionData_ThenKeepsRowScopedRewriteOnly() throws {
        let section = CodexSessionsTabViewModel.SessionSection(
            id: "project:/tmp/project-alpha",
            title: "project-alpha",
            titleSecondaryText: "/tmp/project-alpha",
            rewriteSourceLabel: "project-alpha",
            rewriteSourceProviderID: nil,
            sessions: [
                .init(
                    id: "sessions/live-a.jsonl",
                    threadID: "thread-openai",
                    title: "OpenAI Session",
                    summary: "summary",
                    forkedFromID: "parent-openai",
                    originator: "codex",
                    source: "cli",
                    modelProvider: "openai",
                    archived: false,
                    rolloutPath: "sessions/live-a.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: Date(timeIntervalSince1970: 1_712_800_800),
                    stateRowCount: 3,
                    editable: true
                ),
                .init(
                    id: "sessions/live-b.jsonl",
                    threadID: "thread-custom",
                    title: "Custom Session",
                    summary: nil,
                    forkedFromID: nil,
                    originator: "gemini-cli",
                    source: "desktop",
                    modelProvider: "custom-relay",
                    archived: true,
                    rolloutPath: "sessions/live-b.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: Date(timeIntervalSince1970: 1_712_799_800),
                    stateRowCount: 1,
                    editable: true
                ),
            ],
            totalSessionCount: 2,
            editableThreadIDs: [],
            liveCount: 1,
            archivedCount: 1,
            providerCount: 2,
            isExpanded: false
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .project,
            targetProviders: { providerID in
                switch providerID {
                case "openai":
                    return ["anthropic"]
                case "custom-relay":
                    return ["openai"]
                default:
                    return []
                }
            },
            usageState: { _ in .failed }
        )

        XCTAssertEqual(data.presentationKind, .singleSessionOnly)
        XCTAssertTrue(data.actions.isEmpty)
        XCTAssertEqual(
            data.subtitle,
            "This project contains multiple providers, so rewrite remains row-scoped."
        )
        let providerTexts = data.rows.map { $0.providerText }
        let usageStates = data.rows.map { $0.usage }
        XCTAssertEqual(providerTexts, ["OpenAI (openai)", "custom-relay"])
        XCTAssertEqual(usageStates, [.failed(text: "Unavailable"), .failed(text: "Unavailable")])
    }

    func testBDD_GivenLoadedUsage_WhenBuildingRowData_ThenCompactsUsageSummary() throws {
        let section = makeSection(
            title: "project-alpha",
            titleSecondaryText: "/tmp/project-alpha",
            rewriteSourceProviderID: "openai",
            providerCount: 1,
            totalSessionCount: 1,
            visibleCount: 1,
            isExpanded: true
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .project,
            targetProviders: { _ in [] },
            usageState: { _ in .loaded(.init(inputTokens: 2_400, cachedInputTokens: 400, outputTokens: 600)) }
        )

        let row = try XCTUnwrap(data.rows.first)
        XCTAssertEqual(
            row.usage,
            .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600")
        )
    }

    func testBDD_GivenLoadedUsagesAcrossSection_WhenBuildingSectionData_ThenAggregatesGroupUsage() throws {
        let section = makeSection(
            title: "project-alpha",
            titleSecondaryText: "/tmp/project-alpha",
            rewriteSourceProviderID: "openai",
            providerCount: 1,
            totalSessionCount: 3,
            visibleCount: 3,
            isExpanded: true
        )

        let usageStates: [String: CodexSessionsTabViewModel.SessionUsageState] = [
            "sessions/live-0.jsonl": .loaded(.init(inputTokens: 2_400, cachedInputTokens: 0, outputTokens: 600)),
            "sessions/live-1.jsonl": .loaded(.init(inputTokens: 1_200, cachedInputTokens: 0, outputTokens: 400)),
            "sessions/live-2.jsonl": .placeholder,
        ]

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .project,
            targetProviders: { _ in [] },
            usageState: { usageStates[$0] ?? .failed }
        )

        XCTAssertEqual(
            data.usage,
            .value(primaryText: "4.6K", secondaryText: "in 3.6K · out 1.0K")
        )
    }

    func testBDD_GivenNoResolvedUsageAndFailures_WhenBuildingSectionData_ThenShowsUnavailableGroupUsage() throws {
        let section = makeSection(
            title: "project-alpha",
            titleSecondaryText: "/tmp/project-alpha",
            rewriteSourceProviderID: "openai",
            providerCount: 1,
            totalSessionCount: 2,
            visibleCount: 2,
            isExpanded: false
        )

        let data = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: .project,
            targetProviders: { _ in [] },
            usageState: { _ in .failed }
        )

        XCTAssertEqual(data.usage, .failed(text: "Unavailable"))
    }

    private func makeSection(
        title: String,
        titleSecondaryText: String?,
        rewriteSourceProviderID: String?,
        providerCount: Int,
        totalSessionCount: Int,
        visibleCount: Int,
        isExpanded: Bool
    ) -> CodexSessionsTabViewModel.SessionSection {
        var sessions: [CodexSessionsTabViewModel.SessionRow] = []
        sessions.reserveCapacity(visibleCount)

        for index in 0..<visibleCount {
            let id = "sessions/live-\(index).jsonl"
            let threadID = index == 0 ? "thread-live" : "thread-\(index)"
            let forkedFromID = index == 0 ? "parent-thread-123456" : nil
            let originator = index == 0 ? "codex" : nil
            let source = index == 0 ? "cli" : nil
            let updatedAt = Date(timeIntervalSince1970: 1_712_800_800 - Double(index * 60))

            let row = CodexSessionsTabViewModel.SessionRow(
                id: id,
                threadID: threadID,
                title: "Live Session \(index)",
                summary: "Investigate rollout drift after account relink.",
                forkedFromID: forkedFromID,
                originator: originator,
                source: source,
                modelProvider: "openai",
                archived: false,
                rolloutPath: id,
                cwd: "/tmp/project-alpha",
                updatedAt: updatedAt,
                stateRowCount: 3,
                editable: true
            )
            sessions.append(row)
        }

        return CodexSessionsTabViewModel.SessionSection(
            id: "project:/tmp/project-alpha",
            title: title,
            titleSecondaryText: titleSecondaryText,
            rewriteSourceLabel: title,
            rewriteSourceProviderID: rewriteSourceProviderID,
            sessions: sessions,
            totalSessionCount: totalSessionCount,
            editableThreadIDs: sessions.compactMap { $0.threadID },
            liveCount: sessions.filter { !$0.archived }.count,
            archivedCount: sessions.filter { $0.archived }.count,
            providerCount: providerCount,
            isExpanded: isExpanded
        )
    }
}
