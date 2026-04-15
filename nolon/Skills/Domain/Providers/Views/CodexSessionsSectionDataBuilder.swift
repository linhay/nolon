import Foundation
import CodexProvider
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
        targetProviders: (String) -> [String],
        usageState: (String) -> CodexSessionsTabViewModel.SessionUsageState
    ) -> CodexSessionsSectionData {
        let presentationKind = sectionPresentationKind(for: section)
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
            title: section.title,
            titleSecondaryText: section.titleSecondaryText,
            subtitle: makeSectionSubtitle(section, groupingMode: groupingMode, presentationKind: presentationKind),
            presentationKind: presentationKind,
            badges: makeSectionBadges(section),
            actions: actions,
            actionMenuTitle: actions.isEmpty
                ? nil
                : NSLocalizedString(
                    groupingMode == .project
                        ? "codex.sessions.action.move_project"
                        : "codex.sessions.action.move_group",
                    value: groupingMode == .project ? "Move Project Sessions" : "Move Group",
                    comment: "Move project or provider group"
                ),
            isExpanded: section.isExpanded,
            expansionTitle: expansionTitle(for: section),
            rows: section.sessions.map { session in
                makeRowData(
                    session,
                    groupingMode: groupingMode,
                    targetProviders: targetProviders,
                    usageState: usageState(session.id)
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
        targetProviders: (String) -> [String],
        usageState: CodexSessionsTabViewModel.SessionUsageState
    ) -> CodexSessionsRowData {
        let sourceProviderPresentation = providerPresentation(for: session.modelProvider)
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
            nameMetadataItems: makeNameMetadataItems(for: session),
            idText: session.displayID,
            idSecondaryText: forkedFromText(for: session),
            timeText: timeText(for: session.updatedAt),
            providerText: sourceProviderPresentation.inlineText,
            usage: usageDisplayData(from: usageState),
            isArchived: session.archived,
            isEditable: session.editable,
            summary: session.summary,
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
            readOnlyText: session.editable
                ? nil
                : NSLocalizedString(
                    "codex.sessions.read_only",
                    value: "Read Only",
                    comment: "Read only session label"
                ),
            menuMetadataItems: makeMenuMetadataItems(for: session)
        )
    }

    nonisolated private static func makeNameMetadataItems(
        for session: CodexSessionsTabViewModel.SessionRow
    ) -> [CodexSessionsMetadataItemData] {
        var items: [CodexSessionsMetadataItemData] = []

        if let sourceValue = compactMetadataValue(session.source, maxLength: 24) {
            items.append(
                .init(
                    id: "source",
                    icon: "paperplane",
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.metadata.source",
                            value: "Source: %@",
                            comment: "Codex sessions source metadata"
                        ),
                        sourceValue
                    )
                )
            )
        }

        if let originatorValue = compactMetadataValue(session.originator, maxLength: 24) {
            items.append(
                .init(
                    id: "originator",
                    icon: "person.crop.circle",
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.metadata.originator",
                            value: "Originator: %@",
                            comment: "Codex sessions originator metadata"
                        ),
                        originatorValue
                    )
                )
            )
        }

        return items
    }

    nonisolated private static func makeMenuMetadataItems(
        for session: CodexSessionsTabViewModel.SessionRow
    ) -> [CodexSessionsMetadataItemData] {
        var items: [CodexSessionsMetadataItemData] = []

        if let forkedFromID = trimmedMetadataValue(session.forkedFromID) {
            items.append(
                .init(
                    id: "forked-from",
                    icon: "arrow.triangle.branch",
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.metadata.forked_from",
                            value: "Forked from %@",
                            comment: "Codex sessions forked from metadata"
                        ),
                        forkedFromID
                    ),
                    style: .code
                )
            )
        }

        items.append(contentsOf: makeNameMetadataItems(for: session))
        return items
    }

    nonisolated private static func forkedFromText(
        for session: CodexSessionsTabViewModel.SessionRow
    ) -> String? {
        guard let forkedFromID = compactMetadataValue(session.forkedFromID, maxLength: 12) else {
            return nil
        }
        return String(
            format: NSLocalizedString(
                "codex.sessions.metadata.forked_from",
                value: "Forked from %@",
                comment: "Codex sessions forked from metadata"
            ),
            forkedFromID
        )
    }

    nonisolated private static func compactMetadataValue(_ raw: String?, maxLength: Int) -> String? {
        guard let value = trimmedMetadataValue(raw) else { return nil }
        guard value.count > maxLength else { return value }
        return String(value.prefix(max(1, maxLength - 1))) + "…"
    }

    nonisolated private static func trimmedMetadataValue(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
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
            return groupingMode == .project
                ? NSLocalizedString(
                    "codex.sessions.section.subtitle.multi_provider.project",
                    value: "This project contains multiple providers, so rewrite remains row-scoped.",
                    comment: "Project section subtitle when multiple providers exist"
                )
                : NSLocalizedString(
                    "codex.sessions.section.subtitle.multi_provider",
                    value: "This group contains multiple providers, so only single-session rewrite is available.",
                    comment: "Multi-provider section subtitle"
                )
        case .rewritableGroup:
            return nil
        }
    }

    nonisolated private static func expansionTitle(
        for section: CodexSessionsTabViewModel.SessionSection
    ) -> String? {
        guard section.totalSessionCount > CodexSessionsTabViewModel.defaultVisibleSessionCountPerSection else {
            return nil
        }
        if section.isExpanded {
            return NSLocalizedString(
                "codex.sessions.section.collapse_rows",
                value: "Collapse",
                comment: "Collapse project rows"
            )
        }
        return String(
            format: NSLocalizedString(
                "codex.sessions.section.expand_rows",
                value: "Expand %d More",
                comment: "Expand project rows"
            ),
            section.remainingSessionCount
        )
    }

    nonisolated private static func usageDisplayData(
        from usageState: CodexSessionsTabViewModel.SessionUsageState
    ) -> CodexSessionsUsageDisplayData {
        switch usageState {
        case .placeholder:
            return .placeholder(
                text: NSLocalizedString(
                    "codex.sessions.usage.loading",
                    value: "Loading…",
                    comment: "Usage loading placeholder"
                )
            )
        case .loaded(let usage):
            let detail = "in \(TokenCountFormatters.compact(usage.inputTokens)) · out \(TokenCountFormatters.compact(usage.outputTokens))"
            return .value(
                primaryText: TokenCountFormatters.compact(usage.inputTokens + usage.outputTokens),
                secondaryText: detail
            )
        case .failed:
            return .failed(
                text: NSLocalizedString(
                    "codex.sessions.usage.unavailable",
                    value: "Unavailable",
                    comment: "Usage unavailable label"
                )
            )
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

    nonisolated private static func timeText(for date: Date?) -> String {
        guard let date else {
            return NSLocalizedString(
                "codex.sessions.time.unknown",
                value: "Unknown",
                comment: "Unknown session time"
            )
        }
        return timestampFormatter.string(from: date)
    }

    nonisolated private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
