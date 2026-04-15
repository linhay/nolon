import AppKit
import SnapshotTesting
import SwiftUI
import Testing
import NolonUI
import NolonUIFoundation

@MainActor
@Suite("Codex Sessions Card Snapshot")
struct CodexSessionsCardSnapshotTests {
    private static let regularSnapshotSize = CGSize(width: 980, height: 760)
    private static let mediumSnapshotSize = CGSize(width: 820, height: 820)
    private static let narrowSnapshotSize = CGSize(width: 620, height: 960)
    private static let snapshotDirectory: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("CodexSessionsCardSnapshotTests", isDirectory: true)
            .path
    }()

    @Test("project first overview and table use fixed six-column layout")
    func projectFirstOverviewAndTableUseFixedSixColumnLayout() {
        let overview = NolonUI.CodexSessionsOverviewCardView(
            data: .init(
                title: "Project Sessions",
                subtitle: "Browse sessions by project first. Rewrite and diagnostics stay available from group and row menus.",
                refreshTitle: "Refresh",
                groupingTitle: "Group By",
                groupingOptions: [
                    .init(id: "project", title: "Project"),
                    .init(id: "provider", title: "Provider"),
                ],
                selectedGroupingID: "project",
                statusMessage: "Moved 3 sessions to Anthropic (anthropic).",
                backgroundScanningMessage: "Scanning sessions in background…",
                paginationMessage: nil,
                metrics: [
                    .init(id: "sessions", title: "Total", value: "18"),
                    .init(id: "groups", title: "Groups", value: "4"),
                    .init(id: "rewritable", title: "Rewritable", value: "3"),
                    .init(id: "attention", title: "Needs Attention", value: "1"),
                ],
                isRefreshDisabled: false
            ),
            onRefresh: {},
            onSelectGroupingID: { _ in }
        )

        let section = makeSectionData(isExpanded: false, usage: .placeholder(text: "Loading…"))

        let host = makeHost(
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    section
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.Background.canvas)
            }
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.regularSnapshotSize),
                named: "project-first-overview-table",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("expanded project section keeps full table while usage is resolved")
    func expandedProjectSectionKeepsFullTableWhileUsageIsResolved() {
        let section = makeSectionData(
            isExpanded: true,
            usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600")
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignSystem.Colors.Background.canvas)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.regularSnapshotSize),
                named: "expanded-project-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("medium width keeps sessions table readable without collapsing the name column")
    func mediumWidthKeepsSessionsTableReadable() {
        let section = makeSectionData(
            isExpanded: true,
            usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600")
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignSystem.Colors.Background.canvas),
            size: Self.mediumSnapshotSize
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.mediumSnapshotSize),
                named: "medium-width-project-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("narrow width switches sessions rows into compact stacked details")
    func narrowWidthSwitchesSessionsRowsIntoCompactDetails() {
        let overview = NolonUI.CodexSessionsOverviewCardView(
            data: .init(
                title: "Project Sessions",
                subtitle: "Browse sessions by project first. Rewrite and diagnostics stay available from group and row menus.",
                refreshTitle: "Refresh",
                groupingTitle: "Group By",
                groupingOptions: [
                    .init(id: "project", title: "Project"),
                    .init(id: "provider", title: "Provider"),
                ],
                selectedGroupingID: "project",
                statusMessage: "Moved 3 sessions to Anthropic (anthropic).",
                backgroundScanningMessage: "Scanning sessions in background…",
                paginationMessage: nil,
                metrics: [
                    .init(id: "sessions", title: "Total", value: "18"),
                    .init(id: "groups", title: "Groups", value: "4"),
                    .init(id: "rewritable", title: "Rewritable", value: "3"),
                    .init(id: "attention", title: "Needs Attention", value: "1"),
                ],
                isRefreshDisabled: false
            ),
            onRefresh: {},
            onSelectGroupingID: { _ in }
        )

        let section = makeSectionData(
            isExpanded: true,
            usage: .placeholder(text: "Loading…")
        )

        let host = makeHost(
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    section
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.Background.canvas)
            },
            size: Self.narrowSnapshotSize
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.narrowSnapshotSize),
                named: "narrow-width-project-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("provider secondary grouping remains migration friendly")
    func providerSecondaryGroupingRemainsMigrationFriendly() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "provider-openai",
                title: "openai",
                titleSecondaryText: nil,
                subtitle: nil,
                presentationKind: .rewritableGroup,
                badges: [
                    .init(id: "live", text: "Live 12"),
                    .init(id: "archived", text: "Archived 4"),
                ],
                actions: [
                    .init(id: "anthropic", title: "Move Group to Anthropic (anthropic)", targetProviderID: "anthropic", primaryText: "Anthropic", secondaryText: "anthropic"),
                ],
                actionMenuTitle: "Move Group",
                isExpanded: false,
                expansionTitle: "Expand 2 More",
                rows: [
                    .init(
                        id: "row-1",
                        title: "Provider audit session",
                        idText: "thread-provider-1",
                        timeText: "2026-04-14 09:42",
                        providerText: "OpenAI (openai)",
                        usage: .failed(text: "Unavailable"),
                        isArchived: false,
                        isEditable: true,
                        summary: "Provider regrouping stays as a secondary but still direct workflow.",
                        rolloutPath: "sessions/provider-audit.jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 3,
                        actions: [
                            .init(id: "anthropic", title: "Move Session to Anthropic (anthropic)", targetProviderID: "anthropic", primaryText: "Anthropic", secondaryText: "anthropic"),
                        ],
                        readOnlyText: nil
                    ),
                ]
            ),
            onTapSectionAction: { _ in },
            onTapRowAction: { _, _ in },
            onRevealInFinder: { _ in }
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignSystem.Colors.Background.canvas)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.regularSnapshotSize),
                named: "provider-secondary-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    private func makeSectionData(
        isExpanded: Bool,
        usage: CodexSessionsUsageDisplayData
    ) -> NolonUI.CodexSessionsSectionCardView {
        NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "project-alpha",
                title: "project-alpha",
                titleSecondaryText: "/tmp/project-alpha",
                subtitle: nil,
                presentationKind: .rewritableGroup,
                badges: [
                    .init(id: "live", text: "Live 5"),
                    .init(id: "archived", text: "Archived 1"),
                    .init(id: "visible", text: isExpanded ? "Showing 6 / 6" : "Showing 5 / 6"),
                ],
                actions: [
                    .init(id: "anthropic", title: "Move Group to Anthropic (anthropic)", targetProviderID: "anthropic", primaryText: "Anthropic", secondaryText: "anthropic"),
                ],
                actionMenuTitle: "Move Project Sessions",
                isExpanded: isExpanded,
                expansionTitle: isExpanded ? "Collapse" : "Expand 1 More",
                rows: (0..<(isExpanded ? 6 : 5)).map { index in
                    .init(
                        id: "row-\(index)",
                        title: "Session \(index)",
                        nameMetadataItems: [
                            .init(id: "source-\(index)", icon: "paperplane", text: "Source: cli"),
                            .init(id: "originator-\(index)", icon: "person.crop.circle", text: index.isMultiple(of: 2) ? "Originator: codex" : "Originator: gemini-cli"),
                        ],
                        idText: "thread-\(index)",
                        idSecondaryText: index == 0 ? "Forked from parent-thre…" : nil,
                        timeText: "2026-04-14 1\(index):00",
                        providerText: index % 2 == 0 ? "OpenAI (openai)" : "Anthropic (anthropic)",
                        usage: usage,
                        isArchived: index == 5,
                        isEditable: true,
                        summary: "Fixed columns keep project browsing stable while background usage fills in.",
                        rolloutPath: "sessions/\(index).jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 4,
                        actions: [
                            .init(id: "anthropic", title: "Move Session to Anthropic (anthropic)", targetProviderID: "anthropic", primaryText: "Anthropic", secondaryText: "anthropic"),
                        ],
                        readOnlyText: nil,
                        menuMetadataItems: [
                            .init(id: "forked-\(index)", icon: "arrow.triangle.branch", text: "Forked from parent-thread-\(index)", style: .code),
                            .init(id: "source-\(index)", icon: "paperplane", text: "Source: cli"),
                            .init(id: "originator-\(index)", icon: "person.crop.circle", text: index.isMultiple(of: 2) ? "Originator: codex" : "Originator: gemini-cli"),
                        ]
                    )
                }
            ),
            onTapSectionAction: { _ in },
            onTapRowAction: { _, _ in },
            onRevealInFinder: { _ in }
        )
    }

    private func makeHost<V: View>(_ root: V, size: CGSize = Self.regularSnapshotSize) -> NSHostingView<V> {
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        return host
    }
}
