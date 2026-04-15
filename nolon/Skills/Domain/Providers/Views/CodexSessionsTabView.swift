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
        LazyVStack(alignment: .leading, spacing: 16) {
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

            sessionsContent
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
                        title: "project-alpha",
                        titleSecondaryText: "/tmp/project-alpha",
                        subtitle: nil,
                        badges: [
                            .init(id: "live", text: "Live 0"),
                            .init(id: "archived", text: "Archived 0"),
                        ],
                        actions: [],
                        actionMenuTitle: nil,
                        isExpanded: false,
                        expansionTitle: "Expand 3 More",
                        rows: (0..<3).map { rowIndex in
                            .init(
                                id: "skeleton-row-\(sectionIndex)-\(rowIndex)",
                                title: "Session Title Placeholder",
                                idText: "thread-\(rowIndex)",
                                timeText: "2026-04-14 10:00",
                                providerText: "OpenAI (openai)",
                                usage: .placeholder(text: "Loading…"),
                                isArchived: false,
                                isEditable: true,
                                summary: "Loading session preview from Codex rollout logs.",
                                rolloutPath: "sessions/2026/04/11/example.jsonl",
                                showInFinderTitle: nil,
                                copyPathTitle: "Copy Path",
                                stateRowCount: 0,
                                actions: [],
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

    @ViewBuilder
    private var sessionsContent: some View {
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
                            targetProviders: { viewModel.targetProviders(for: $0) },
                            usageState: { viewModel.usageState(for: $0) }
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
                            viewModel.toggleSectionExpansion(sectionID)
                        }
                    )
                }
            }
        }
    }

    private var overviewData: CodexSessionsOverviewData {
        CodexSessionsOverviewData(
            title: NSLocalizedString(
                "codex.sessions.header.title",
                value: "Project Sessions",
                comment: "Codex sessions header title"
            ),
            subtitle: viewModel.groupingMode == .project
                ? NSLocalizedString(
                    "codex.sessions.header.subtitle.project",
                    value: "Browse sessions by project first. Rewrite and diagnostics stay available from group and row menus.",
                    comment: "Codex sessions header subtitle"
                )
                : NSLocalizedString(
                    "codex.sessions.header.subtitle.provider",
                    value: "Switch to provider grouping when you need a migration-oriented audit across projects.",
                    comment: "Codex sessions header subtitle for provider grouping"
                ),
            refreshTitle: NSLocalizedString("Refresh", value: "Refresh", comment: "Refresh"),
            groupingTitle: NSLocalizedString(
                "codex.sessions.grouping.title",
                value: "Group By",
                comment: "Codex sessions grouping title"
            ),
            groupingOptions: [
                .init(
                    id: CodexSessionsTabViewModel.SessionGroupingMode.project.rawValue,
                    title: NSLocalizedString(
                        "codex.sessions.grouping.project",
                        value: "Project",
                        comment: "Codex sessions project grouping title"
                    )
                ),
                .init(
                    id: CodexSessionsTabViewModel.SessionGroupingMode.provider.rawValue,
                    title: NSLocalizedString(
                        "codex.sessions.grouping.provider",
                        value: "Provider",
                        comment: "Codex sessions provider grouping title"
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
            paginationMessage: nil,
            metrics: [
                .init(
                    id: "sessions",
                    title: NSLocalizedString("codex.sessions.metric.total", value: "Total", comment: "Total sessions"),
                    value: "\(viewModel.totalSessionCount)"
                ),
                .init(
                    id: "groups",
                    title: NSLocalizedString("codex.sessions.metric.groups", value: "Groups", comment: "Group count"),
                    value: "\(viewModel.groupCount)"
                ),
                .init(
                    id: "rewritable",
                    title: NSLocalizedString("codex.sessions.metric.rewritable", value: "Rewritable", comment: "Rewritable group count"),
                    value: "\(viewModel.rewritableGroupCount)"
                ),
                .init(
                    id: "attention",
                    title: NSLocalizedString("codex.sessions.metric.needs_attention", value: "Needs Attention", comment: "Needs attention group count"),
                    value: "\(viewModel.needsAttentionGroupCount)"
                ),
            ],
            isRefreshDisabled: viewModel.isLoading || viewModel.isPreparingRewrite || viewModel.isApplyingRewrite
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
