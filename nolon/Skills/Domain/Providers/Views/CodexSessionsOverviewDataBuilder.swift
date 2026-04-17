import Foundation
import NolonUIFoundation

enum CodexSessionsOverviewDataBuilder {
    struct Context: Equatable {
        let groupingMode: CodexSessionsTabViewModel.SessionGroupingMode
        let sortMode: CodexSessionsTabViewModel.SessionSortMode
        let totalSessionCount: Int
        let groupCount: Int
        let rewritableGroupCount: Int
        let needsAttentionGroupCount: Int
        let statusMessage: String?
        let isLoading: Bool
        let hasVisibleSections: Bool
        let isPreparingRewrite: Bool
        let isApplyingRewrite: Bool
    }

    nonisolated static func build(_ context: Context) -> CodexSessionsOverviewData {
        let displayMode = displayMode(for: context)
        return CodexSessionsOverviewData(
            displayMode: displayMode,
            title: NSLocalizedString(
                "codex.sessions.header.title",
                value: "Project Sessions",
                comment: "Codex sessions header title"
            ),
            subtitle: subtitle(for: context.groupingMode, displayMode: displayMode),
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
            selectedGroupingID: context.groupingMode.rawValue,
            sortingTitle: NSLocalizedString(
                "codex.sessions.sorting.title",
                value: "Sort By",
                comment: "Codex sessions sorting title"
            ),
            sortingOptions: [
                .init(
                    id: CodexSessionsTabViewModel.SessionSortMode.recent.rawValue,
                    title: NSLocalizedString(
                        "codex.sessions.sorting.recent",
                        value: "Recent Activity",
                        comment: "Codex sessions recent sorting title"
                    )
                ),
                .init(
                    id: CodexSessionsTabViewModel.SessionSortMode.usage.rawValue,
                    title: NSLocalizedString(
                        "codex.sessions.sorting.usage",
                        value: "Usage",
                        comment: "Codex sessions usage sorting title"
                    )
                ),
            ],
            selectedSortingID: context.sortMode.rawValue,
            statusMessage: context.statusMessage,
            backgroundScanningMessage: context.isLoading && context.hasVisibleSections
                ? NSLocalizedString(
                    "codex.sessions.status.scanning",
                    value: "Scanning sessions in background…",
                    comment: "Codex sessions background scanning status"
                )
                : nil,
            paginationMessage: nil,
            metrics: metrics(for: context, displayMode: displayMode),
            isRefreshDisabled: context.isLoading || context.isPreparingRewrite || context.isApplyingRewrite
        )
    }

    nonisolated private static func displayMode(for context: Context) -> CodexSessionsOverviewDisplayMode {
        if (context.isLoading && context.hasVisibleSections) || context.isPreparingRewrite || context.isApplyingRewrite {
            return .diagnostic
        }
        return .compact
    }

    nonisolated private static func subtitle(
        for groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        displayMode: CodexSessionsOverviewDisplayMode
    ) -> String {
        switch (groupingMode, displayMode) {
        case (.project, .compact):
            return NSLocalizedString(
                "codex.sessions.header.subtitle.project.compact",
                value: "Browse sessions by project.",
                comment: "Compact codex sessions header subtitle"
            )
        case (.provider, .compact):
            return NSLocalizedString(
                "codex.sessions.header.subtitle.provider.compact",
                value: "Audit sessions by provider.",
                comment: "Compact codex sessions provider subtitle"
            )
        case (.project, .diagnostic):
            return NSLocalizedString(
                "codex.sessions.header.subtitle.project",
                value: "Browse sessions by project first. Rewrite and diagnostics stay available from group and row menus.",
                comment: "Codex sessions header subtitle"
            )
        case (.provider, .diagnostic):
            return NSLocalizedString(
                "codex.sessions.header.subtitle.provider",
                value: "Switch to provider grouping when you need a migration-oriented audit across projects.",
                comment: "Codex sessions header subtitle for provider grouping"
            )
        }
    }

    nonisolated private static func metrics(
        for context: Context,
        displayMode: CodexSessionsOverviewDisplayMode
    ) -> [CodexSessionsMetricData] {
        var metrics: [CodexSessionsMetricData] = [
            .init(
                id: "sessions",
                title: NSLocalizedString("codex.sessions.metric.total", value: "Total", comment: "Total sessions"),
                value: "\(context.totalSessionCount)"
            ),
            .init(
                id: "groups",
                title: NSLocalizedString("codex.sessions.metric.groups", value: "Groups", comment: "Group count"),
                value: "\(context.groupCount)"
            ),
        ]

        if displayMode == .diagnostic {
            metrics.append(
                .init(
                    id: "rewritable",
                    title: NSLocalizedString(
                        "codex.sessions.metric.rewritable",
                        value: "Rewritable",
                        comment: "Rewritable group count"
                    ),
                    value: "\(context.rewritableGroupCount)"
                )
            )
        }

        metrics.append(
            .init(
                id: "attention",
                title: NSLocalizedString(
                    "codex.sessions.metric.needs_attention",
                    value: "Needs Attention",
                    comment: "Needs attention group count"
                ),
                value: "\(context.needsAttentionGroupCount)"
            )
        )

        return metrics
    }
}
