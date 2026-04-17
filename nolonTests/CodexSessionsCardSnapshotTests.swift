import AppKit
import SnapshotTesting
import SwiftUI
import Testing
import NolonUI
import NolonUIFoundation
@testable import nolon

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

    @Test("overview card keeps compact controls under status pressure")
    func overviewCardKeepsCompactControlsUnderStatusPressure() {
        let overview = makeOverviewCard(displayMode: .diagnostic)

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                overview
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 620, height: 420)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 620, height: 420)),
                named: "overview-compact-controls",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("project first overview keeps section rows in a compact session list")
    func projectFirstOverviewKeepsCompactSessionList() {
        let overview = makeOverviewCard(displayMode: .compact)

        let section = makeSectionData(isExpanded: false, usage: .placeholder(text: "Loading…"))

        let host = makeHost(
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    section
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NolonUI.DesignSystem.Colors.Background.canvas)
            },
            size: Self.regularSnapshotSize
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.regularSnapshotSize),
                named: "project-first-overview-list",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("expanded project section keeps flat session rows while usage is resolved")
    func expandedProjectSectionKeepsFlatRowsWhileUsageIsResolved() {
        let section = makeSectionData(
            isExpanded: true,
            usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
            sectionUsage: .value(primaryText: "6.4K", secondaryText: "in 4.8K · out 1.6K")
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: Self.regularSnapshotSize
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

    @Test("medium width keeps sessions rows readable with selected state")
    func mediumWidthKeepsSessionsRowsReadable() {
        let section = makeSectionData(
            isExpanded: true,
            usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
            sectionUsage: .value(primaryText: "6.4K", secondaryText: "in 4.8K · out 1.6K"),
            selectedRowID: "row-1"
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
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

    @Test("narrow width keeps cc switch style two line rows")
    func narrowWidthKeepsTwoLineRows() {
        let overview = makeOverviewCard(displayMode: .compact)

        let section = makeSectionData(
            isExpanded: true,
            usage: .placeholder(text: "Loading…")
        )

        let host = makeHost(
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    section
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NolonUI.DesignSystem.Colors.Background.canvas)
            },
            size: Self.narrowSnapshotSize
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.narrowSnapshotSize),
                named: "narrow-width-project-list",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("narrow width loaded usage keeps total visible without secondary detail")
    func narrowWidthLoadedUsageKeepsOnlyTotalVisible() {
        let overview = makeOverviewCard(displayMode: .compact)

        let section = makeSectionData(
            isExpanded: true,
            usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
            sectionUsage: .value(primaryText: "6.4K", secondaryText: "in 4.8K · out 1.6K")
        )

        let host = makeHost(
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    section
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NolonUI.DesignSystem.Colors.Background.canvas)
            },
            size: Self.narrowSnapshotSize
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.narrowSnapshotSize),
                named: "narrow-width-project-list-loaded-usage",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("section header shows aggregated usage above the group title")
    func sectionHeaderShowsAggregatedUsageAboveGroupTitle() {
        let section = makeSectionData(
            isExpanded: false,
            usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
            sectionUsage: .value(primaryText: "6.4K", secondaryText: "in 4.8K · out 1.6K")
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 980, height: 260)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 260)),
                named: "section-header-group-usage",
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
                usage: .failed(text: "Unavailable"),
                titleSecondaryText: "/Users/linhey/.nolon/providers/openai/sessions/2026/04/15",
                subtitle: "Read-only provider bundle. Sessions can be inspected, but migration stays disabled here.",
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
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: Self.regularSnapshotSize
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

    @Test("detail panel surfaces quick resume command and path actions")
    func detailPanelSurfacesQuickResumeCommandAndPathActions() {
        let detail = CodexSessionsDetailPanelView(
            data: makeDetailData(),
            onResume: {},
            onCopyCommand: {},
            onRevealInFinder: {},
            onCopyProjectPath: {},
            onCopyRolloutPath: {}
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                detail
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 980, height: 360)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 360)),
                named: "detail-panel-quick-command",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("selected row expands inline detail below the tapped session")
    func selectedRowExpandsInlineDetailBelowTappedSession() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "project-alpha",
                title: "project-alpha",
                usage: .value(primaryText: "12.0K", secondaryText: "in 9.0K · out 3.0K"),
                titleSecondaryText: "/tmp/project-alpha",
                subtitle: "Inline detail should stay attached to the selected row instead of dropping to the page footer.",
                presentationKind: .rewritableGroup,
                badges: [
                    .init(id: "live", text: "Live 5"),
                    .init(id: "archived", text: "Archived 1"),
                ],
                actions: [],
                actionMenuTitle: nil,
                isExpanded: true,
                expansionTitle: "Collapse",
                rows: (0..<4).map { index in
                    .init(
                        id: "row-\(index)",
                        title: index == 1 ? "Refactor session list layout" : "Session \(index)",
                        nameMetadataItems: [],
                        idText: "thread-\(index)",
                        timeText: "2026-04-15 2\(index):30",
                        providerText: "OpenAI (openai)",
                        usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
                        isArchived: index == 3,
                        isEditable: true,
                        summary: "Inline detail should sit under the selected session row.",
                        rolloutPath: "sessions/2026/04/15/\(index).jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 8,
                        actions: [],
                        readOnlyText: nil
                    )
                }
            ),
            onTapSectionAction: { _ in },
            onTapRowAction: { _, _ in },
            onRevealInFinder: { _ in },
            onToggleCollapse: { _ in },
            selectedRowID: "row-1",
            onSelectRow: { _ in },
            expandedRowID: "row-1",
            expandedRowContent: { _ in
                CodexSessionsDetailPanelView(
                    data: makeDetailData(),
                    onResume: {},
                    onCopyCommand: {},
                    onRevealInFinder: {},
                    onCopyProjectPath: {},
                    onCopyRolloutPath: {}
                )
            }
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                section
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 980, height: 720)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 720)),
                named: "inline-detail-selected-row",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("compact overview keeps browsing density low by default")
    func compactOverviewKeepsBrowsingDensityLowByDefault() {
        let overview = makeOverviewCard(displayMode: .compact)

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                overview
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 620, height: 320)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 620, height: 320)),
                named: "overview-compact-default-density",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    private func makeSectionData(
        isExpanded: Bool,
        usage: CodexSessionsUsageDisplayData,
        sectionUsage: CodexSessionsUsageDisplayData? = nil,
        selectedRowID: String? = nil
    ) -> some View {
        NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "project-alpha",
                title: "project-alpha",
                usage: sectionUsage ?? usage,
                titleSecondaryText: "/tmp/workspaces/project-alpha/very/deep/path/that/should/stay/on/one/line",
                subtitle: "Project rewrite group. Move stays available from the menu without consuming a full banner row.",
                presentationKind: .rewritableGroup,
                badges: [
                    .init(id: "live", text: "Live 5"),
                    .init(id: "archived", text: "Archived 1"),
                    .init(id: "readonly", text: "ReadOnly 1"),
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
                        nameMetadataItems: [],
                        idText: "thread-\(index)",
                        idSecondaryText: index == 0 ? "Forked from parent-thre…" : nil,
                        timeText: "2026-04-14 1\(index):00",
                        providerText: index % 2 == 0 ? "OpenAI (openai)" : "Anthropic (anthropic)",
                        usage: usage,
                        isArchived: index == 5,
                        isEditable: index != 4,
                        summary: "Fixed columns keep project browsing stable while background usage fills in.",
                        rolloutPath: "sessions/\(index).jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 4,
                        actions: [
                            .init(id: "anthropic", title: "Move Session to Anthropic (anthropic)", targetProviderID: "anthropic", primaryText: "Anthropic", secondaryText: "anthropic"),
                        ],
                        readOnlyText: index == 4 ? "Read Only" : nil,
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
            onRevealInFinder: { _ in },
            selectedRowID: selectedRowID,
            onSelectRow: { _ in }
        )
    }

    private func makeOverviewCard(
        displayMode: CodexSessionsOverviewDisplayMode = .diagnostic
    ) -> NolonUI.CodexSessionsOverviewCardView {
        NolonUI.CodexSessionsOverviewCardView(
            data: .init(
                displayMode: displayMode,
                title: "Project Sessions",
                subtitle: displayMode == .compact
                    ? "Browse sessions by project."
                    : "Browse sessions by project first. Rewrite and diagnostics stay available from group and row menus.",
                refreshTitle: "Refresh",
                groupingTitle: "Group By",
                groupingOptions: [
                    .init(id: "project", title: "Project"),
                    .init(id: "provider", title: "Provider"),
                ],
                selectedGroupingID: "project",
                statusMessage: "Moved 3 sessions to Anthropic (anthropic).",
                backgroundScanningMessage: displayMode == .diagnostic ? "Scanning sessions in background…" : nil,
                paginationMessage: nil,
                metrics: displayMode == .compact
                    ? [
                        .init(id: "sessions", title: "Total", value: "18"),
                        .init(id: "groups", title: "Groups", value: "4"),
                        .init(id: "attention", title: "Needs Attention", value: "1"),
                    ]
                    : [
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
    }

    private func makeDetailData() -> CodexSessionsDetailPanelData {
        .init(
            title: "Refactor session list layout",
            providerText: "OpenAI (openai)",
            timeText: "2026-04-15 20:30",
            projectPath: "/tmp/project-alpha",
            groupTitle: "project-alpha",
            groupSecondaryText: "/tmp/project-alpha",
            summary: "Move dense row metadata into an inline panel so browsing stays stable in large session lists.",
            usageText: "3.0K · in 2.4K · out 600",
            rolloutPath: "sessions/2026/04/15/refactor.jsonl",
            stateRowCount: 8,
            metadataItems: [
                .init(id: "forked", icon: "arrow.triangle.branch", text: "Forked from parent-thread", style: .code),
                .init(id: "source", icon: "paperplane", text: "Source: cli"),
                .init(id: "originator", icon: "person.crop.circle", text: "Originator: codex"),
            ],
            statusTexts: ["Live"],
            resumeCommand: "cd /tmp/project-alpha && codex resume --last thread-refactor",
            rowData: .init(
                id: "row-detail",
                title: "Refactor session list layout",
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
                stateRowCount: 8,
                actions: [],
                readOnlyText: nil
            )
        )
    }

    private func makeHost<V: View>(_ root: V, size: CGSize) -> NSHostingView<V> {
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        return host
    }
}
