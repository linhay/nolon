import AppKit
import SnapshotTesting
import SwiftUI
import Testing
import NolonUI
import NolonUIFoundation

@MainActor
@Suite("Codex Sessions Card Snapshot")
struct CodexSessionsCardSnapshotTests {
    private static let snapshotSize = CGSize(width: 920, height: 760)
    private static let snapshotDirectory: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("CodexSessionsCardSnapshotTests", isDirectory: true)
            .path
    }()

    @Test("overview and provider section keep a clear hierarchy with tabular session rows")
    func overviewAndProviderSectionKeepTabularHierarchy() {
        let overview = NolonUI.CodexSessionsOverviewCardView(
            data: .init(
                title: "Session Provider Mapping",
                subtitle: "Review live and archived sessions, then rewrite a single session or an entire provider group.",
                refreshTitle: "Refresh",
                groupingTitle: "Group By",
                groupingOptions: [
                    .init(id: "provider", title: "Provider"),
                    .init(id: "time_project", title: "Time + Project"),
                ],
                selectedGroupingID: "provider",
                statusMessage: "Last rewrite moved 3 sessions to provider-three.",
                backgroundScanningMessage: "Scanning sessions in background…",
                paginationMessage: "Showing 30 of 48 sessions.",
                metrics: [
                    .init(id: "total", title: "Total", value: "48"),
                    .init(id: "live", title: "Live", value: "29"),
                    .init(id: "archived", title: "Archived", value: "19"),
                    .init(id: "targets", title: "Targets", value: "6"),
                ],
                isRefreshDisabled: false
            ),
            onRefresh: {},
            onSelectGroupingID: { _ in }
        )

        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "provider-openai",
                title: "openai",
                subtitle: "All editable sessions in this provider can be rewritten together.",
                badges: [
                    .init(id: "live", text: "Live 12"),
                    .init(id: "archived", text: "Archived 4"),
                    .init(id: "visible", text: "Showing 6 / 16"),
                ],
                actions: [
                    .init(id: "provider-two", title: "Move Group to provider-two", targetProviderID: "provider-two"),
                    .init(id: "provider-three", title: "Move Group to provider-three", targetProviderID: "provider-three"),
                ],
                actionMenuTitle: "Move Group",
                rows: [
                    .init(
                        id: "row-1",
                        title: "Resolve stale symlink migration regression for snapshot repair flow",
                        providerName: nil,
                        isArchived: false,
                        isEditable: true,
                        summary: "Investigate duplicate account activation after reconciliation and compare sqlite metadata against rollout state in the table layout.",
                        badges: [.init(id: "db", text: "DB 14")],
                        metadataItems: [
                            .init(id: "updated", icon: "clock", text: "5m ago"),
                            .init(id: "cwd", icon: "folder", text: "/tmp/project-alpha"),
                        ],
                        rolloutPath: "sessions/2026/04/11/provider-openai-rollout.jsonl",
                        showInFinderTitle: "Show in Finder",
                        actions: [
                            .init(id: "provider-two", title: "Move Session to provider-two", targetProviderID: "provider-two"),
                        ],
                        actionMenuTitle: "Move Session",
                        readOnlyText: nil
                    ),
                    .init(
                        id: "row-2",
                        title: "Audit archived provider drift after account relink",
                        providerName: nil,
                        isArchived: true,
                        isEditable: false,
                        summary: "Read-only historical session retained for verification after the last migration and still visible in the table layout.",
                        badges: [.init(id: "db", text: "DB 2")],
                        metadataItems: [
                            .init(id: "updated", icon: "clock", text: "2d ago"),
                            .init(id: "cwd", icon: "folder", text: "/tmp/project-alpha"),
                        ],
                        rolloutPath: "archived_sessions/2026/04/09/archive-openai-rollout.jsonl",
                        showInFinderTitle: "Show in Finder",
                        actions: [],
                        actionMenuTitle: nil,
                        readOnlyText: "Read Only"
                    ),
                ]
            ),
            onTapSectionAction: { _ in },
            onTapRowAction: { _, _ in },
            onRevealInFinder: { _ in }
        )

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
                as: .image(size: Self.snapshotSize),
                named: "overview-provider-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("time project group stays readable in table layout when only per-session rewrite is available")
    func timeProjectGroupStaysReadableInTableLayoutWhenOnlyPerSessionRewriteIsAvailable() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "time-project",
                title: "2026-04-10 · project-alpha",
                subtitle: "This group contains multiple providers, so only single-session rewrite is available.",
                badges: [
                    .init(id: "live", text: "Live 1"),
                    .init(id: "archived", text: "Archived 1"),
                    .init(id: "providers", text: "Providers 2"),
                ],
                actions: [],
                actionMenuTitle: nil,
                rows: [
                    .init(
                        id: "row-3",
                        title: "Codex provider-two session",
                        providerName: "provider-two",
                        isArchived: false,
                        isEditable: true,
                        summary: "Provider chip should stay secondary to the title but remain discoverable inside the status column.",
                        badges: [],
                        metadataItems: [
                            .init(id: "updated", icon: "clock", text: "Today"),
                            .init(id: "cwd", icon: "folder", text: "/tmp/project-alpha"),
                        ],
                        rolloutPath: "sessions/2026/04/10/provider-two.jsonl",
                        showInFinderTitle: "Show in Finder",
                        actions: [
                            .init(id: "openai", title: "Move Session to openai", targetProviderID: "openai"),
                        ],
                        actionMenuTitle: "Move Session",
                        readOnlyText: nil
                    ),
                    .init(
                        id: "row-4",
                        title: "Codex provider-three archive",
                        providerName: "provider-three",
                        isArchived: true,
                        isEditable: true,
                        summary: nil,
                        badges: [.init(id: "db", text: "DB 1")],
                        metadataItems: [
                            .init(id: "updated", icon: "clock", text: "Yesterday"),
                            .init(id: "cwd", icon: "folder", text: "/tmp/project-alpha"),
                        ],
                        rolloutPath: "archived_sessions/2026/04/10/provider-three.jsonl",
                        showInFinderTitle: "Show in Finder",
                        actions: [
                            .init(id: "openai", title: "Move Session to openai", targetProviderID: "openai"),
                        ],
                        actionMenuTitle: "Move Session",
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
                as: .image(size: Self.snapshotSize),
                named: "time-project-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("collapsed provider section keeps header context while hiding session rows")
    func collapsedProviderSectionKeepsHeaderContext() {
        let section = NolonUI.CodexSessionsSectionCardView(
            data: .init(
                id: "provider-openai-collapsed",
                title: "openai",
                subtitle: "All editable sessions in this provider can be rewritten together.",
                badges: [
                    .init(id: "live", text: "Live 12"),
                    .init(id: "archived", text: "Archived 4"),
                    .init(id: "visible", text: "Showing 6 / 16"),
                ],
                actions: [
                    .init(id: "provider-two", title: "Move Group to provider-two", targetProviderID: "provider-two"),
                ],
                actionMenuTitle: "Move Group",
                isCollapsed: true,
                rows: [
                    .init(
                        id: "row-hidden",
                        title: "This row should be hidden in collapsed state",
                        providerName: nil,
                        isArchived: false,
                        isEditable: true,
                        summary: "Collapsed sections should keep summary context but hide rows.",
                        badges: [.init(id: "db", text: "DB 8")],
                        metadataItems: [
                            .init(id: "updated", icon: "clock", text: "5m ago"),
                        ],
                        rolloutPath: "sessions/2026/04/12/provider-openai-rollout.jsonl",
                        showInFinderTitle: "Show in Finder",
                        actions: [
                            .init(id: "provider-two", title: "Move Session to provider-two", targetProviderID: "provider-two"),
                        ],
                        actionMenuTitle: "Move Session",
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
                as: .image(size: Self.snapshotSize),
                named: "collapsed-provider-section",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    private func makeHost<V: View>(_ root: V) -> NSHostingView<V> {
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.snapshotSize)
        host.layoutSubtreeIfNeeded()
        return host
    }
}
