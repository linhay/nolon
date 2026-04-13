import AppKit
import SwiftUI
import ProviderCatalog
import NolonUI
import NolonUIFoundation
import NolonResourceKit
import STFilePath

struct CodexSessionsTabView: View {
    let provider: Provider

    @State private var viewModel: CodexSessionsTabViewModel

    init(provider: Provider, viewModel: CodexSessionsTabViewModel? = nil) {
        self.provider = provider
        self._viewModel = State(initialValue: viewModel ?? CodexSessionsTabViewModel(provider: provider))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NolonUI.CodexSessionsOverviewCardView(
                data: overviewData,
                onRefresh: {
                    Task { await viewModel.refresh() }
                },
                onSelectGroupingID: { groupingID in
                    guard let groupingMode = CodexSessionsTabViewModel.SessionGroupingMode(rawValue: groupingID) else {
                        return
                    }
                    viewModel.setGroupingMode(groupingMode)
                }
            )

            if viewModel.showsInitialSkeleton && viewModel.sections.isEmpty {
                skeletonContent
            } else if viewModel.isLoading && viewModel.sections.isEmpty {
                skeletonContent
            } else if viewModel.sections.isEmpty {
                ContentUnavailableView {
                    Label(
                        NSLocalizedString(
                            "codex.sessions.empty.title",
                            value: "No Sessions Found",
                            comment: "Empty sessions title"
                        ),
                        systemImage: "bubble.left.and.bubble.right"
                    )
                } description: {
                    Text(
                        NSLocalizedString(
                            "codex.sessions.empty.message",
                            value: "No live or archived Codex sessions were found in this provider home.",
                            comment: "Empty sessions description"
                        )
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.sections) { section in
                        NolonUI.CodexSessionsSectionCardView(
                            data: CodexSessionsSectionDataBuilder.buildSectionData(
                                section,
                                groupingMode: viewModel.groupingMode,
                                targetProviders: { viewModel.targetProviders(for: $0) }
                            ),
                            onTapSectionAction: { targetProviderID in
                                Task {
                                    await viewModel.requestRewrite(for: section, targetProviderID: targetProviderID)
                                }
                            },
                            onTapRowAction: { row, targetProviderID in
                                guard let session = section.sessions.first(where: { $0.id == row.id }) else { return }
                                Task {
                                    await viewModel.requestRewrite(for: session, targetProviderID: targetProviderID)
                                }
                            },
                            onRevealInFinder: { row in
                                revealInFinder(for: row)
                            },
                            onToggleCollapse: { sectionID in
                                viewModel.toggleSectionCollapse(sectionID)
                            }
                        )
                    }

                    if viewModel.canLoadMore {
                        NolonUI.CodexSessionsLoadMoreButton(
                            data: loadMoreData,
                            onTap: {
                                viewModel.loadNextPage()
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: provider.id) {
            await viewModel.load()
        }
        .confirmationAlert(
            data: viewModel.confirmationAlertData,
            isPresented: Binding(
                get: { viewModel.pendingRewrite != nil },
                set: { if !$0 { viewModel.cancelPendingRewrite() } }
            ),
            onConfirm: {
                Task { await viewModel.confirmPendingRewrite() }
            },
            onCancel: {
                viewModel.cancelPendingRewrite()
            }
        )
        .messageAlert(
            title: NSLocalizedString(
                "codex.sessions.error.title",
                value: "Sessions Error",
                comment: "Codex sessions error title"
            ),
            message: $viewModel.alertMessage
        )
    }

    private var skeletonContent: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(0..<3, id: \.self) { sectionIndex in
                NolonUI.CodexSessionsSectionCardView(
                    data: .init(
                        id: "skeleton-section-\(sectionIndex)",
                        title: "openai",
                        subtitle: "All editable sessions in this provider can be rewritten together.",
                        badges: [
                            .init(id: "live", text: "Live 0"),
                            .init(id: "archived", text: "Archived 0"),
                        ],
                        actions: [],
                        actionMenuTitle: nil,
                        rows: (0..<3).map { rowIndex in
                            .init(
                                id: "skeleton-row-\(sectionIndex)-\(rowIndex)",
                                title: "Session Title Placeholder",
                                providerName: nil,
                                isArchived: false,
                                isEditable: true,
                                summary: "Loading session preview from Codex rollout logs.",
                                badges: [.init(id: "db", text: "DB 0")],
                                metadataItems: [
                                    .init(id: "time", icon: "clock", text: "Just now"),
                                    .init(id: "cwd", icon: "folder", text: "/tmp/project"),
                                ],
                                rolloutPath: "sessions/2026/04/11/example.jsonl",
                                showInFinderTitle: nil,
                                actions: [],
                                actionMenuTitle: nil,
                                readOnlyText: nil
                            )
                        }
                    ),
                    onTapSectionAction: { _ in },
                    onTapRowAction: { _, _ in },
                    onRevealInFinder: { _ in },
                    onToggleCollapse: { _ in }
                )
                .redacted(reason: .placeholder)
            }
        }
    }

    private var overviewData: CodexSessionsOverviewData {
        CodexSessionsOverviewData(
            title: NSLocalizedString(
                "codex.sessions.header.title",
                value: "Session Provider Mapping",
                comment: "Codex sessions header title"
            ),
            subtitle: viewModel.groupingMode == .provider
                ? NSLocalizedString(
                    "codex.sessions.header.subtitle",
                    value: "Review live and archived sessions by model_provider, then rewrite a single session or an entire provider group.",
                    comment: "Codex sessions header subtitle"
                )
                : NSLocalizedString(
                    "codex.sessions.header.subtitle.time_project",
                    value: "Review sessions grouped by day and project. Single-session rewrite is always available; group rewrite is available when a section maps to one provider.",
                    comment: "Codex sessions header subtitle for time and project grouping"
                ),
            refreshTitle: NSLocalizedString("Refresh", value: "Refresh", comment: "Refresh"),
            groupingTitle: NSLocalizedString(
                "codex.sessions.grouping.title",
                value: "Group By",
                comment: "Codex sessions grouping title"
            ),
            groupingOptions: [
                .init(
                    id: CodexSessionsTabViewModel.SessionGroupingMode.provider.rawValue,
                    title: NSLocalizedString(
                        "codex.sessions.grouping.provider",
                        value: "Provider",
                        comment: "Codex sessions provider grouping title"
                    )
                ),
                .init(
                    id: CodexSessionsTabViewModel.SessionGroupingMode.timeProject.rawValue,
                    title: NSLocalizedString(
                        "codex.sessions.grouping.time_project",
                        value: "Time + Project",
                        comment: "Codex sessions time and project grouping title"
                    )
                ),
            ],
            selectedGroupingID: viewModel.groupingMode.rawValue,
            statusMessage: viewModel.statusMessage,
            backgroundScanningMessage: viewModel.isLoading && !viewModel.sections.isEmpty
                ? NSLocalizedString(
                    "codex.sessions.status.scanning",
                    value: "Scanning sessions in background…",
                    comment: "Codex sessions background scanning status"
                )
                : nil,
            paginationMessage: viewModel.visibleSessionCount > 0 && viewModel.canLoadMore
                ? String(
                    format: NSLocalizedString(
                        "codex.sessions.pagination.showing",
                        value: "Showing %d of %d sessions.",
                        comment: "Current visible session count"
                    ),
                    viewModel.visibleSessionCount,
                    viewModel.totalSessionCount
                )
                : nil,
            metrics: [
                .init(
                    id: "total",
                    title: NSLocalizedString("codex.sessions.metric.total", value: "Total", comment: "Total sessions"),
                    value: "\(viewModel.totalSessionCount)"
                ),
                .init(
                    id: "live",
                    title: NSLocalizedString("codex.sessions.metric.live", value: "Live", comment: "Live sessions"),
                    value: "\(viewModel.totalLiveCount)"
                ),
                .init(
                    id: "archived",
                    title: NSLocalizedString("codex.sessions.metric.archived", value: "Archived", comment: "Archived sessions"),
                    value: "\(viewModel.totalArchivedCount)"
                ),
                .init(
                    id: "targets",
                    title: NSLocalizedString("codex.sessions.metric.providers", value: "Targets", comment: "Target provider count"),
                    value: "\(viewModel.availableTargetProviderIDs.count)"
                ),
            ],
            isRefreshDisabled: viewModel.isLoading || viewModel.isPreparingRewrite || viewModel.isApplyingRewrite
        )
    }

    private var loadMoreData: CodexSessionsLoadMoreData {
        CodexSessionsLoadMoreData(
            title: String(
                format: NSLocalizedString(
                    "codex.sessions.pagination.load_more",
                    value: "Load More (%d remaining)",
                    comment: "Load more sessions button"
                ),
                viewModel.remainingSessionCount
            ),
            isDisabled: viewModel.isLoading || viewModel.isPreparingRewrite || viewModel.isApplyingRewrite
        )
    }

    private func revealInFinder(for row: CodexSessionsRowData) {
        let targetURL: URL
        if row.rolloutPath.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: row.rolloutPath)
        } else {
            targetURL = provider.codexHomeFolder.file(row.rolloutPath).url
        }
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }
}
