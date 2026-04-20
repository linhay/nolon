import Foundation
import CodexProvider
import NolonUIFoundation

enum CodexSessionsShareContentBuilder {
    static func makeSessionShareData(
        from data: CodexSessionsDetailPanelData
    ) -> CodexSessionsShareData? {
        let title = normalizedValue(data.rowData.title) ?? data.threadIDText
        guard let normalizedTitle = normalizedValue(title) else { return nil }

        var lines: [String] = [
            "\(NSLocalizedString("codex.sessions.share.session_heading", value: "Session", comment: "Session share heading")): \(normalizedTitle)",
        ]

        appendLine(
            NSLocalizedString(
                "codex.sessions.detail.thread_id",
                value: "Thread ID",
                comment: "Thread identifier"
            ),
            value: data.threadIDCopyValue ?? normalizedValue(data.threadIDText),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.table.provider",
                value: "Provider",
                comment: "Session table column header"
            ),
            value: normalizedValue(data.providerText),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.group",
                value: "Group",
                comment: "Session share group label"
            ),
            value: normalizedValue(data.groupTitle),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.detail.copy_project",
                value: "Project",
                comment: "Project path"
            ),
            value: normalizedValue(data.projectPath),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.started",
                value: "Started",
                comment: "Session share started time label"
            ),
            value: normalizedValue(data.startedAtText),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.last_activity",
                value: "Last Activity",
                comment: "Session share last activity label"
            ),
            value: normalizedValue(data.lastActivityText),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.table.usage",
                value: "Usage",
                comment: "Session table column header"
            ),
            value: sessionUsageText(data.usage),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.status",
                value: "Status",
                comment: "Session share status label"
            ),
            value: data.statusTexts.isEmpty ? nil : data.statusTexts.joined(separator: " · "),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.summary",
                value: "Summary",
                comment: "Session share summary label"
            ),
            value: normalizedValue(data.summary),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.command",
                value: "Command",
                comment: "Session share command label"
            ),
            value: normalizedValue(data.resumeCommand),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.rollout",
                value: "Rollout",
                comment: "Session share rollout label"
            ),
            value: normalizedValue(data.rolloutPath),
            to: &lines
        )

        return .init(title: normalizedTitle, item: lines.joined(separator: "\n"))
    }

    static func makeSectionShareData(
        section: CodexSessionsTabViewModel.SessionSection,
        groupingMode: CodexSessionsTabViewModel.SessionGroupingMode,
        usageState: (String) -> CodexSessionsTabViewModel.SessionUsageState
    ) -> CodexSessionsShareData? {
        guard let sectionTitle = normalizedValue(section.title) else { return nil }

        let headingKey: String
        let headingValue: String
        switch groupingMode {
        case .project:
            headingKey = "codex.sessions.share.project_group_heading"
            headingValue = "Project Group"
        case .provider:
            headingKey = "codex.sessions.share.provider_group_heading"
            headingValue = "Provider Group"
        }

        var lines: [String] = [
            "\(NSLocalizedString(headingKey, value: headingValue, comment: "Section share heading")): \(sectionTitle)",
        ]

        appendLine(
            NSLocalizedString(
                "codex.sessions.detail.copy_project",
                value: "Project",
                comment: "Project path"
            ),
            value: normalizedValue(section.titleSecondaryText),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.table.usage",
                value: "Usage",
                comment: "Session table column header"
            ),
            value: sectionUsageText(section: section, usageState: usageState),
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.share.sessions",
                value: "Sessions",
                comment: "Session share session count label"
            ),
            value: "\(section.totalSessionCount)",
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.badge.live",
                value: "Live",
                comment: "Live badge"
            ),
            value: "\(section.liveCount)",
            to: &lines
        )
        appendLine(
            NSLocalizedString(
                "codex.sessions.badge.archived",
                value: "Archived",
                comment: "Archived badge"
            ),
            value: "\(section.archivedCount)",
            to: &lines
        )
        if section.providerCount > 1 {
            appendLine(
                NSLocalizedString(
                    "codex.sessions.share.providers",
                    value: "Providers",
                    comment: "Session share provider count label"
                ),
                value: "\(section.providerCount)",
                to: &lines
            )
        }

        if !section.sessions.isEmpty {
            lines.append("")
            for session in section.sessions {
                lines.append(sessionLine(for: session))
            }
        }

        return .init(title: sectionTitle, item: lines.joined(separator: "\n"))
    }

    private static func sessionUsageText(_ usage: CodexSessionsDetailUsageData?) -> String? {
        guard let usage else { return nil }
        return normalizedValue(usage.totalText)
    }

    private static func sectionUsageText(
        section: CodexSessionsTabViewModel.SessionSection,
        usageState: (String) -> CodexSessionsTabViewModel.SessionUsageState
    ) -> String? {
        let usageStates = section.usageSessionIDs.map(usageState)
        guard !usageStates.isEmpty else { return nil }

        var totalInputTokens = 0
        var totalOutputTokens = 0
        var hasLoadedUsage = false
        var hasPlaceholderUsage = false
        var hasFailedUsage = false

        for state in usageStates {
            switch state {
            case .placeholder:
                hasPlaceholderUsage = true
            case .failed:
                hasFailedUsage = true
            case .loaded(let usage):
                hasLoadedUsage = true
                totalInputTokens += usage.inputTokens
                totalOutputTokens += usage.outputTokens
            }
        }

        if hasLoadedUsage {
            return TokenCountFormatters.compact(totalInputTokens + totalOutputTokens)
        }
        if hasPlaceholderUsage {
            return NSLocalizedString(
                "codex.sessions.usage.loading",
                value: "Loading…",
                comment: "Usage loading placeholder"
            )
        }
        if hasFailedUsage {
            return NSLocalizedString(
                "codex.sessions.usage.unavailable",
                value: "Unavailable",
                comment: "Usage unavailable label"
            )
        }
        return nil
    }

    private static func sessionLine(
        for session: CodexSessionsTabViewModel.SessionRow
    ) -> String {
        var parts: [String] = [session.title]
        parts.append(session.displayID)
        parts.append(CodexSessionsSectionDataBuilder.providerPresentation(for: session.modelProvider).inlineText)

        if let timestamp = session.updatedAt.map(timestampFormatter.string(from:)) {
            parts.append(timestamp)
        }
        if session.archived {
            parts.append(
                NSLocalizedString(
                    "codex.sessions.badge.archived",
                    value: "Archived",
                    comment: "Archived badge"
                )
            )
        }
        if !session.editable {
            parts.append(
                NSLocalizedString(
                    "codex.sessions.read_only",
                    value: "Read Only",
                    comment: "Read only session label"
                )
            )
        }

        return "- " + parts.joined(separator: " · ")
    }

    private static func appendLine(
        _ label: String,
        value: String?,
        to lines: inout [String]
    ) {
        guard let normalizedValue = normalizedValue(value) else { return }
        lines.append("\(label): \(normalizedValue)")
    }

    private static func normalizedValue(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
