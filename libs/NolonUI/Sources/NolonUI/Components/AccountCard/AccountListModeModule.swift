import SwiftUI
import NolonUIFoundation

struct AccountListModeUsageWindow: Identifiable {
    let id = UUID()
    let title: String
    let progress: CGFloat
    let percentText: String

    init(title: String, progress: CGFloat, percentText: String) {
        self.title = title
        self.progress = progress
        self.percentText = percentText
    }
}

struct AccountListModeItem: Identifiable {
    let id = UUID()
    let presentation: AccountCardPresentation
    let header: AccountSummaryCardHeaderModel
    let usageWindows: [AccountListModeUsageWindow]
    let isLoadingPlaceholder: Bool

    init(
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        usageWindows: [AccountListModeUsageWindow],
        isLoadingPlaceholder: Bool = false
    ) {
        self.presentation = presentation
        self.header = header
        self.usageWindows = usageWindows
        self.isLoadingPlaceholder = isLoadingPlaceholder
    }

    init(
        presentation: AccountCardPresentation,
        header: AccountSummaryCardHeaderModel,
        progress: CGFloat,
        percentText: String,
        isLoadingPlaceholder: Bool = false
    ) {
        self.init(
            presentation: presentation,
            header: header,
            usageWindows: [.init(title: "Session", progress: progress, percentText: percentText)],
            isLoadingPlaceholder: isLoadingPlaceholder
        )
    }
}

struct AccountListModeSection: Identifiable {
    let id = UUID()
    let title: String?
    let items: [AccountListModeItem]

    init(title: String? = nil, items: [AccountListModeItem]) {
        self.title = title
        self.items = items
    }
}

struct AccountListModeModule: View {
    @State private var viewModel = AccountListModeModuleViewModel()
    let title: String
    let sections: [AccountListModeSection]

    init(
        title: String = "Account List Mode",
        items: [AccountListModeItem]
    ) {
        self.title = title
        self.sections = [.init(items: items)]
    }

    init(
        title: String = "Account List Mode",
        sections: [AccountListModeSection]
    ) {
        self.title = title
        self.sections = sections
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            VStack(alignment: .leading, spacing: 0) {
                tableHeader

                ForEach(Array(sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    if let title = section.title, !title.isEmpty {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .padding(.top, sectionIndex == 0 ? 0 : PreviewLayoutTokens.Spacing.row)
                            .padding(.bottom, 4)
                    }

                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        tableRow(item)
                            .redacted(reason: item.isLoadingPlaceholder ? .placeholder : [])

                        if index < section.items.count - 1 {
                            Divider()
                                .overlay(DesignSystem.Colors.Component.border.opacity(0.25))
                        }
                    }
                }
            }
            .padding(.horizontal, PreviewLayoutTokens.Spacing.group)
            .padding(.vertical, PreviewLayoutTokens.Spacing.row)
            .background(DesignSystem.Colors.Background.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                    .stroke(DesignSystem.Colors.Component.border.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tableHeader: some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            Text("Account")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Plan")
                .frame(width: 90, alignment: .leading)
            Text("Usage")
                .frame(width: 220, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        .padding(.vertical, PreviewLayoutTokens.Spacing.row)
    }

    private func tableRow(_ item: AccountListModeItem) -> some View {
        HStack(spacing: PreviewLayoutTokens.Spacing.group) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.header.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(1)
                    if let secondary = accountSecondaryText(for: item) {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(planText(for: item))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)

            usageWindowsColumn(item.usageWindows)
                .frame(width: 220, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private func usageWindowsColumn(_ windows: [AccountListModeUsageWindow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(windows) { window in
                HStack(spacing: 6) {
                    Text(window.title)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .frame(width: 46, alignment: .leading)
                    AccountInlineQuotaProgress(progress: window.progress, percentText: window.percentText)
                }
            }
        }
    }

    private func accountSecondaryText(for item: AccountListModeItem) -> String? {
        let eyebrow = item.header.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = item.header.meta?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let eyebrow, !eyebrow.isEmpty, let meta, !meta.isEmpty {
            return "\(eyebrow) • \(meta)"
        }
        if let eyebrow, !eyebrow.isEmpty {
            return eyebrow
        }
        if let meta, !meta.isEmpty {
            return meta
        }
        return nil
    }

    private func planText(for item: AccountListModeItem) -> String {
        let raw = item.header.subtitle ?? "-"
        let normalized = raw.split(separator: "•").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalized?.isEmpty == false) ? normalized! : "-"
    }

    private func statusColor(for item: AccountListModeItem) -> Color {
        if let badge = item.header.badge {
            switch badge.tone {
            case .active:
                return DesignSystem.Colors.primary
            case .warning:
                return DesignSystem.Colors.Status.warning
            case .neutral:
                return DesignSystem.Colors.Text.secondary
            }
        }
        switch item.presentation.selectionStyle {
        case .active:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.Status.warning
        case .selected:
            return DesignSystem.Colors.primary
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        }
    }
}
