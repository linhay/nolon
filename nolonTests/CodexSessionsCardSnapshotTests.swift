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

    @Test("overview card keeps grouping picker on one line at compact widths")
    func overviewCardKeepsGroupingPickerOnOneLineAtCompactWidths() {
        let overview = makeOverviewCard(displayMode: .compact)

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                overview
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 660, height: 260)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 660, height: 260)),
                named: "overview-grouping-picker-single-line",
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

    @Test("sessions search field aligns with overview card trailing edge")
    func sessionsSearchFieldAlignsWithOverviewCardTrailingEdge() {
        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                makeOverviewCard(displayMode: .compact)
                SearchField(
                    config: .init(
                        placeholder: "Search",
                        text: .constant("thread-refactor")
                    )
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 980, height: 300)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 300)),
                named: "sessions-search-aligned-with-overview",
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

    @Test("single session section drops group chrome and reads like a single row")
    func singleSessionSectionDropsGroupChrome() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "project-solo",
                title: "project-solo",
                usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
                titleSecondaryText: "/tmp/project-solo",
                subtitle: nil,
                presentationKind: .rewritableGroup,
                badges: [
                    .init(id: "live", text: "Live 1"),
                ],
                actions: [],
                actionMenuTitle: nil,
                isExpanded: false,
                expansionTitle: nil,
                rows: [
                    .init(
                        id: "solo-row",
                        title: "Refactor session detail layout",
                        nameMetadataItems: [],
                        idText: "thread-solo",
                        timeText: "2026-04-20 00:40",
                        providerText: "OpenAI (openai)",
                        usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
                        isArchived: false,
                        isEditable: true,
                        summary: "A single-item project should read like one row instead of a full section group.",
                        rolloutPath: "sessions/2026/04/20/solo.jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 2,
                        actions: [],
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
            size: CGSize(width: 980, height: 240)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 240)),
                named: "single-session-section-no-group-chrome",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("single session row keeps status and usage in a flat subtitle rail")
    func singleSessionRowKeepsStatusAndUsageInSubtitleRail() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "single-session-row",
                title: "project-alpha",
                usage: .value(primaryText: "7.8K", secondaryText: "in 5.5K · out 2.3K"),
                shareData: nil,
                titleSecondaryText: "/tmp/project-alpha",
                subtitle: nil,
                presentationKind: .singleSessionOnly,
                badges: [],
                actions: [],
                actionMenuTitle: nil,
                isExpanded: false,
                expansionTitle: nil,
                rows: [
                    .init(
                        id: "row-status-inline",
                        title: "Polish inline detail spacing and reduce row chrome in the session browser",
                        nameMetadataItems: [],
                        idText: "thread-status-inline",
                        timeText: "2026-04-20 13:40",
                        providerText: "OpenAI (openai)",
                        usage: .value(primaryText: "7.8K", secondaryText: "in 5.5K · out 2.3K"),
                        isArchived: false,
                        isEditable: false,
                        summary: "Status, read-only state, provider, usage and time should all live in one subtitle rail.",
                        rolloutPath: "sessions/2026/04/20/inline-status.jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 4,
                        actions: [],
                        readOnlyText: "Read Only",
                        menuMetadataItems: []
                    )
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
            size: CGSize(width: 980, height: 260)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 260)),
                named: "single-session-subtitle-rail",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("single session row keeps a text only subtitle rail while title expands freely")
    func singleSessionRowKeepsTextOnlySubtitleRailWhileTitleExpandsFreely() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "project-long-title",
                title: "project-long-title",
                usage: .value(primaryText: "12.0K", secondaryText: "in 9.0K · out 3.0K"),
                titleSecondaryText: "/tmp/project-long-title",
                subtitle: nil,
                presentationKind: .rewritableGroup,
                badges: [
                    .init(id: "live", text: "Live 1"),
                ],
                actions: [],
                actionMenuTitle: nil,
                isExpanded: false,
                expansionTitle: nil,
                rows: [
                    .init(
                        id: "long-title-row",
                        title: "Refactor the Codex sessions browsing experience so token usage moves into the subtitle rail and the primary title can fully expand without getting clipped by inline controls",
                        nameMetadataItems: [],
                        idText: "thread-long-title",
                        timeText: "2026-04-20 02:40",
                        providerText: "OpenAI (openai)",
                        usage: .value(primaryText: "12.0K", secondaryText: "in 9.0K · out 3.0K"),
                        isArchived: false,
                        isEditable: true,
                        summary: "The row should emphasize the title first, then keep metadata and usage together in a text-only subtitle rail.",
                        rolloutPath: "sessions/2026/04/20/long-title.jsonl",
                        showInFinderTitle: "Show in Finder",
                        copyPathTitle: "Copy Path",
                        stateRowCount: 3,
                        actions: [],
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
            size: CGSize(width: 820, height: 280)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 820, height: 280)),
                named: "single-session-long-title-subtitle-rail",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("detail panel keeps the action area anchored at the bottom")
    func detailPanelSurfacesCopyCommandAndPathActions() {
        let detail = CodexSessionsDetailPanelView(
            data: makeDetailData(),
            onCopyThreadID: {},
            onCopyCommand: {},
            onRevealInFinder: {},
            onCopyProjectPath: {}
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

    @Test("detail panel keeps timeline loading state separate from updated timestamp")
    func detailPanelKeepsTimelineLoadingStateSeparateFromUpdatedTimestamp() {
        let detail = CodexSessionsDetailPanelView(
            data: makeDetailData(
                startedAtText: "Loading…",
                lastActivityText: "Loading…"
            ),
            onCopyThreadID: {},
            onCopyCommand: {},
            onRevealInFinder: {},
            onCopyProjectPath: {}
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
                named: "detail-panel-loading-timeline",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("detail panel keeps failed timeline and missing thread compact")
    func detailPanelKeepsFailedTimelineAndMissingThreadCompact() {
        let detail = CodexSessionsDetailPanelView(
            data: makeDetailData(
                threadIDText: "Unavailable",
                threadIDCopyValue: nil,
                startedAtText: "Unknown",
                lastActivityText: "Unknown",
                usage: .init(
                    totalText: "Unavailable",
                    inputText: nil,
                    outputText: nil,
                    cachedText: nil,
                    isPlaceholder: true
                )
            ),
            onCopyThreadID: nil,
            onCopyCommand: {},
            onRevealInFinder: {},
            onCopyProjectPath: {}
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
                named: "detail-panel-failed-timeline",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("detail panel keeps fused metadata rail under the summary header")
    func detailPanelKeepsFusedMetadataRailUnderSummaryHeader() {
        let detail = CodexSessionsDetailPanelView(
            data: makeDetailData(),
            onCopyThreadID: {},
            onCopyCommand: {},
            onRevealInFinder: {},
            onCopyProjectPath: {}
        )

        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                detail
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas),
            size: CGSize(width: 980, height: 320)
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: CGSize(width: 980, height: 320)),
                named: "detail-panel-metadata-rail",
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
            onToggleRowExpansion: { _ in },
            expandedRowID: "row-1",
            expandedRowContent: { _ in
                CodexSessionsDetailPanelView(
                    data: makeDetailData(),
                    onCopyThreadID: {},
                    onCopyCommand: {},
                    onRevealInFinder: {},
                    onCopyProjectPath: {}
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

    @Test("sessions page disables text selection for static labels")
    func sessionsPageDisablesTextSelectionForStaticLabels() {
        let host = makeHost(
            VStack(alignment: .leading, spacing: 18) {
                makeOverviewCard(displayMode: .compact)
                makeSectionData(
                    isExpanded: true,
                    usage: .value(primaryText: "3.0K", secondaryText: "in 2.4K · out 600"),
                    sectionUsage: .value(primaryText: "6.4K", secondaryText: "in 4.8K · out 1.6K"),
                    selectedRowID: "row-1"
                )
                CodexSessionsDetailPanelView(
                    data: makeDetailData(),
                    onCopyThreadID: {},
                    onCopyCommand: {},
                    onRevealInFinder: {},
                    onCopyProjectPath: {}
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NolonUI.DesignSystem.Colors.Background.canvas)
            .textSelection(.disabled),
            size: CGSize(width: 980, height: 900)
        )

        let textFields = allTextFields(in: host)
        #expect(textFields.contains { $0.isEditable == false })
        let selectableStaticFields = textFields.filter { field in
            field.isEditable == false && field.isSelectable
        }

        #expect(selectableStaticFields.isEmpty)
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
                sortingTitle: "Sort By",
                sortingOptions: [
                    .init(id: "recent", title: "Recent Activity"),
                    .init(id: "usage", title: "Usage"),
                ],
                selectedSortingID: "recent",
                statusMessage: "Moved 3 sessions to Anthropic (anthropic).",
                backgroundScanningMessage: displayMode == .diagnostic ? "Scanning sessions in background…" : nil,
                paginationMessage: nil,
                metrics: displayMode == .compact
                    ? [
                        .init(id: "sessions", title: "Total", value: "18", detailText: "Usage 18.6K"),
                        .init(id: "groups", title: "Groups", value: "4", detailText: "Usage 18.6K"),
                    ]
                    : [
                        .init(id: "sessions", title: "Total", value: "18", detailText: "Usage 18.6K"),
                        .init(id: "groups", title: "Groups", value: "4", detailText: "Usage 18.6K"),
                        .init(id: "rewritable", title: "Rewritable", value: "3", detailText: "Usage 15.0K"),
                    ],
                isRefreshDisabled: false
            ),
            onRefresh: {},
            onSelectGroupingID: { _ in },
            onSelectSortingID: { _ in }
        )
    }

    private func makeDetailData(
        threadIDText: String = "thread-refactor",
        threadIDCopyValue: String? = "thread-refactor",
        startedAtText: String = "2026-04-15 19:58",
        lastActivityText: String = "2026-04-15 20:30",
        usage: CodexSessionsDetailUsageData? = .init(
            totalText: "3.0K",
            inputText: "2.4K",
            outputText: "600",
            cachedText: "400",
            isPlaceholder: false
        )
    ) -> CodexSessionsDetailPanelData {
        let rowData = CodexSessionsRowData(
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
        let provisionalData = CodexSessionsDetailPanelData(
            threadIDText: threadIDText,
            threadIDCopyValue: threadIDCopyValue,
            providerText: "OpenAI (openai)",
            startedAtText: startedAtText,
            lastActivityText: lastActivityText,
            projectPath: "/tmp/project-alpha",
            groupTitle: "project-alpha",
            summary: "Move dense row metadata into an inline panel so browsing stays stable in large session lists.",
            usage: usage,
            rolloutPath: "sessions/2026/04/15/refactor.jsonl",
            stateRowCount: 8,
            metadataItems: [
                .init(id: "forked", icon: "arrow.triangle.branch", text: "Forked from parent-thread", style: .code),
                .init(id: "source", icon: "paperplane", text: "Source: cli"),
                .init(id: "originator", icon: "person.crop.circle", text: "Originator: codex"),
            ],
            statusTexts: ["Live"],
            resumeCommand: "codex resume --last thread-refactor",
            shareData: nil,
            rowData: rowData
        )
        return .init(
            threadIDText: provisionalData.threadIDText,
            threadIDCopyValue: provisionalData.threadIDCopyValue,
            providerText: provisionalData.providerText,
            startedAtText: provisionalData.startedAtText,
            lastActivityText: provisionalData.lastActivityText,
            projectPath: provisionalData.projectPath,
            groupTitle: provisionalData.groupTitle,
            summary: provisionalData.summary,
            usage: provisionalData.usage,
            rolloutPath: provisionalData.rolloutPath,
            stateRowCount: provisionalData.stateRowCount,
            metadataItems: provisionalData.metadataItems,
            statusTexts: provisionalData.statusTexts,
            resumeCommand: provisionalData.resumeCommand,
            shareData: CodexSessionsShareContentBuilder.makeSessionShareData(from: provisionalData),
            rowData: provisionalData.rowData
        )
    }

    private func makeHost<V: View>(_ root: V, size: CGSize) -> NSHostingView<V> {
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        return host
    }

    private func allTextFields(in root: NSView) -> [NSTextField] {
        var results: [NSTextField] = []
        if let textField = root as? NSTextField {
            results.append(textField)
        }
        for child in root.subviews {
            results.append(contentsOf: allTextFields(in: child))
        }
        return results
    }
}
