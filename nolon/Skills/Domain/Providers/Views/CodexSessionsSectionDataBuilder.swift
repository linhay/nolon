import Foundation
import NolonUIFoundation

enum CodexSessionsSectionDataBuilder {
    struct ProviderPresentation: Equatable {
        let primaryText: String
        let secondaryText: String?

        nonisolated var inlineText: String {
            guard let secondaryText, !secondaryText.isEmpty else { return primaryText }
            return "\(primaryText) (\(secondaryText))"
        }
    }

    nonisolated static func buildSectionData(
        _ section: CodexSessionsTabViewModel.SessionSection,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        targetProviders: (String) -> [String]
    ) -> CodexSessionsSectionData {
        let presentationKind = sectionPresentationKind(for: section)
        let sectionProviderPresentation = groupingMode == .provider
            ? section.rewriteSourceProviderID.map(providerPresentation(for:))
            : nil
        let actions: [CodexSessionsActionItemData]
        if let sourceProviderID = section.rewriteSourceProviderID {
            actions = targetProviders(sourceProviderID).map { targetProviderID in
                let targetPresentation = providerPresentation(for: targetProviderID)
                return CodexSessionsActionItemData(
                    id: "section-\(section.id)-\(targetProviderID)",
                    title: String(
                        format: NSLocalizedString(
                            "codex.sessions.action.move_group_to",
                            value: "Move Group to %@",
                            comment: "Move provider group to target provider"
                        ),
                        targetPresentation.inlineText
                    ),
                    targetProviderID: targetProviderID,
                    primaryText: targetPresentation.primaryText,
                    secondaryText: targetPresentation.secondaryText
                )
            }
        } else {
            actions = []
        }

        return CodexSessionsSectionData(
            id: section.id,
            title: sectionProviderPresentation?.primaryText ?? section.title,
            titleSecondaryText: sectionProviderPresentation?.secondaryText,
            subtitle: makeSectionSubtitle(section, groupingMode: groupingMode, presentationKind: presentationKind),
            presentationKind: presentationKind,
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

    nonisolated private static func makeSectionBadges(
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

    nonisolated private static func makeRowData(
        _ session: CodexSessionsTabViewModel.SessionRow,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        targetProviders: (String) -> [String]
    ) -> CodexSessionsRowData {
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
            let targetPresentation = providerPresentation(for: targetProviderID)
            return CodexSessionsActionItemData(
                id: "row-\(session.id)-\(targetProviderID)",
                title: String(
                    format: NSLocalizedString(
                        "codex.sessions.action.move_session_to",
                        value: "Move Session to %@",
                        comment: "Move single session to target provider"
                    ),
                    targetPresentation.inlineText
                ),
                targetProviderID: targetProviderID,
                primaryText: targetPresentation.primaryText,
                secondaryText: targetPresentation.secondaryText
            )
        }

        return CodexSessionsRowData(
            id: session.id,
            title: session.title,
            providerName: groupingMode == .timeProject ? providerPresentation(for: session.modelProvider).inlineText : nil,
            isArchived: session.archived,
            isEditable: session.editable,
            summary: session.summary,
            badges: [],
            metadataItems: metadataItems,
            rolloutPath: session.rolloutPath,
            showInFinderTitle: NSLocalizedString(
                "action.show_in_finder",
                value: "Show in Finder",
                comment: "Show in Finder"
            ),
            copyPathTitle: NSLocalizedString(
                "action.copy_path",
                value: "Copy Path",
                comment: "Copy a file path"
            ),
            stateRowCount: session.stateRowCount,
            actions: session.editable ? actions : [],
            actionMenuTitle: session.editable && actions.count > 1
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

    nonisolated private static func makeSectionSubtitle(
        _ section: CodexSessionsTabViewModel.SessionSection,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        presentationKind: CodexSessionsSectionPresentationKind
    ) -> String? {
        switch presentationKind {
        case .readOnly:
            return NSLocalizedString(
                "codex.sessions.section.subtitle.read_only",
                value: "This section only contains read-only sessions.",
                comment: "Read-only section subtitle"
            )
        case .singleSessionOnly:
            return NSLocalizedString(
                "codex.sessions.section.subtitle.multi_provider",
                value: "This group contains multiple providers, so only single-session rewrite is available.",
                comment: "Multi-provider section subtitle"
            )
        case .rewritableGroup:
            _ = groupingMode
            return nil
        }
    }

    nonisolated static func providerPresentation(for providerID: String) -> ProviderPresentation {
        let normalizedID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedID = normalizedID.lowercased()
        switch lowercasedID {
        case "openai":
            return .init(primaryText: "OpenAI", secondaryText: normalizedID)
        case "anthropic":
            return .init(primaryText: "Anthropic", secondaryText: normalizedID)
        case "gemini":
            return .init(primaryText: "Gemini", secondaryText: normalizedID)
        case "claude":
            return .init(primaryText: "Claude", secondaryText: normalizedID)
        case "azure":
            return .init(primaryText: "Azure OpenAI", secondaryText: normalizedID)
        default:
            return .init(primaryText: normalizedID, secondaryText: nil)
        }
    }

    nonisolated static func sectionPresentationKind(
        for section: CodexSessionsTabViewModel.SessionSection
    ) -> CodexSessionsSectionPresentationKind {
        if !section.hasEditableSessions {
            return .readOnly
        }
        if section.providerCount > 1 {
            return .singleSessionOnly
        }
        return .rewritableGroup
    }

    nonisolated private static func relativeDateText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
