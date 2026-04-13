import Foundation
import NolonUIFoundation

enum CodexSessionsSectionDataBuilder {
    static func buildSectionData(
        _ section: CodexSessionsTabViewModel.SessionSection,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        targetProviders: (String) -> [String]
    ) -> CodexSessionsSectionData {
        let actions = section.rewriteSourceProviderID.map { sourceProviderID in
            targetProviders(sourceProviderID).map { targetProviderID in
                CodexSessionsActionItemData(
                    id: "section-\(section.id)-\(targetProviderID)",
                    title: String(
                        format: NSLocalizedString(
                            "codex.sessions.action.move_group_to",
                            value: "Move Group to %@",
                            comment: "Move provider group to target provider"
                        ),
                        targetProviderID
                    ),
                    targetProviderID: targetProviderID
                )
            }
        } ?? []

        return CodexSessionsSectionData(
            id: section.id,
            title: section.title,
            subtitle: makeSectionSubtitle(section, groupingMode: groupingMode),
            badges: makeSectionBadges(section),
            actions: actions,
            actionMenuTitle: actions.isEmpty
                ? nil
                : NSLocalizedString(
                    "codex.sessions.action.move_group",
                    value: "Move Group",
                    comment: "Move provider group"
                ),
            isCollapsed: section.isCollapsed,
            rows: section.sessions.map { session in
                makeRowData(
                    session,
                    groupingMode: groupingMode,
                    targetProviders: targetProviders
                )
            }
        )
    }

    private static func makeSectionBadges(
        _ section: CodexSessionsTabViewModel.SessionSection
    ) -> [CodexSessionsBadgeData] {
        var badges = [
            CodexSessionsBadgeData(
                id: "live",
                text: String(
                    format: NSLocalizedString(
                        "codex.sessions.section.live_count",
                        value: "Live %d",
                        comment: "Live count in a provider section"
                    ),
                    section.liveCount
                )
            ),
            CodexSessionsBadgeData(
                id: "archived",
                text: String(
                    format: NSLocalizedString(
                        "codex.sessions.section.archived_count",
                        value: "Archived %d",
                        comment: "Archived count in a provider section"
                    ),
                    section.archivedCount
                )
            ),
        ]

        if section.providerCount > 1 {
            badges.append(
                CodexSessionsBadgeData(
                    id: "providers",
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.section.provider_count",
                            value: "Providers %d",
                            comment: "Provider count in a session section"
                        ),
                        section.providerCount
                    )
                )
            )
        }

        if section.hasHiddenSessions {
            badges.append(
                CodexSessionsBadgeData(
                    id: "visible",
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.section.visible_count",
                            value: "Showing %d / %d",
                            comment: "Visible session count in a provider section"
                        ),
                        section.visibleSessionCount,
                        section.totalSessionCount
                    )
                )
            )
        }

        return badges
    }

    private static func makeRowData(
        _ session: CodexSessionsTabViewModel.SessionRow,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        targetProviders: (String) -> [String]
    ) -> CodexSessionsRowData {
        var badges = [
            CodexSessionsBadgeData(
                id: "archive",
                text: session.archived
                    ? NSLocalizedString("codex.sessions.badge.archived", value: "Archived", comment: "Archived badge")
                    : NSLocalizedString("codex.sessions.badge.live", value: "Live", comment: "Live badge")
            )
        ]
        if session.stateRowCount > 0 {
            badges.append(
                CodexSessionsBadgeData(
                    id: "db",
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.badge.db_rows",
                            value: "DB %d",
                            comment: "Database row count badge"
                        ),
                        session.stateRowCount
                    )
                )
            )
        }

        var metadataItems: [CodexSessionsMetadataItemData] = []
        if let updatedText = relativeDateText(session.updatedAt) {
            metadataItems.append(
                .init(
                    id: "updated",
                    icon: "clock",
                    text: updatedText
                )
            )
        }
        if let cwd = session.cwd, !cwd.isEmpty {
            metadataItems.append(
                .init(
                    id: "cwd",
                    icon: "folder",
                    text: cwd,
                    style: .code
                )
            )
        }

        let actions = targetProviders(session.modelProvider).map { targetProviderID in
            CodexSessionsActionItemData(
                id: "row-\(session.id)-\(targetProviderID)",
                title: String(
                    format: NSLocalizedString(
                        "codex.sessions.action.move_session_to",
                        value: "Move Session to %@",
                        comment: "Move single session to target provider"
                    ),
                    targetProviderID
                ),
                targetProviderID: targetProviderID
            )
        }

        return CodexSessionsRowData(
            id: session.id,
            title: session.title,
            providerName: groupingMode == .timeProject ? session.modelProvider : nil,
            isArchived: session.archived,
            isEditable: session.editable,
            summary: session.summary,
            badges: badges,
            metadataItems: metadataItems,
            rolloutPath: session.rolloutPath,
            showInFinderTitle: NSLocalizedString(
                "action.show_in_finder",
                value: "Show in Finder",
                comment: "Show in Finder"
            ),
            actions: session.editable ? actions : [],
            actionMenuTitle: session.editable
                ? NSLocalizedString(
                    "codex.sessions.action.move_session",
                    value: "Move Session",
                    comment: "Move single session"
                )
                : nil,
            readOnlyText: session.editable
                ? nil
                : NSLocalizedString(
                    "codex.sessions.read_only",
                    value: "Read Only",
                    comment: "Read only session label"
                )
        )
    }

    private static func makeSectionSubtitle(
        _ section: CodexSessionsTabViewModel.SessionSection,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode
    ) -> String? {
        if section.editableThreadIDs.isEmpty {
            return NSLocalizedString(
                "codex.sessions.section.subtitle.read_only",
                value: "This section only contains read-only sessions.",
                comment: "Read-only section subtitle"
            )
        }

        if section.providerCount > 1 {
            return NSLocalizedString(
                "codex.sessions.section.subtitle.multi_provider",
                value: "This group contains multiple providers, so only single-session rewrite is available.",
                comment: "Multi-provider section subtitle"
            )
        }

        if groupingMode == .provider {
            return NSLocalizedString(
                "codex.sessions.section.subtitle.provider_group",
                value: "All editable sessions in this provider can be rewritten together.",
                comment: "Provider-group section subtitle"
            )
        }

        return NSLocalizedString(
            "codex.sessions.section.subtitle.time_project",
            value: "All editable sessions in this day/project group can be rewritten together.",
            comment: "Time/project section subtitle"
        )
    }

    private static func relativeDateText(_ date: Date?) -> String? {
        guard let date else { return nil }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
