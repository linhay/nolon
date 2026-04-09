import AppKit
import MarkdownUI
import NolonUIFoundation
import SwiftUI

// MARK: - CodexAdvancedRuntimeOverviewView

public struct CodexAdvancedRuntimeOverviewView: View {
    let stats: [CodexAdvancedStatTileData]
    let metaRows: [CodexAdvancedMetaRowData]

    public struct Config {
        public var stats: [CodexAdvancedStatTileData]
        public var metaRows: [CodexAdvancedMetaRowData]

        public init(
            stats: [CodexAdvancedStatTileData],
            metaRows: [CodexAdvancedMetaRowData]
        ) {
            self.stats = stats
            self.metaRows = metaRows
        }
    }

    public init(config: Config) {
        self.stats = config.stats
        self.metaRows = config.metaRows
    }

    public init(
        stats: [CodexAdvancedStatTileData],
        metaRows: [CodexAdvancedMetaRowData]
    ) {
        self.init(config: Config(stats: stats, metaRows: metaRows))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdaptiveCardGrid(
                columns: [
                    GridItem(.flexible(minimum: 160), spacing: 10),
                    GridItem(.flexible(minimum: 160), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    CodexAdvancedStatTileView(data: stat)
                }
            }

            if !metaRows.isEmpty {
                CodexAdvancedMetaRowsView(rows: metaRows)
            }
        }
    }
}

// MARK: - CodexAdvancedSectionCardView

public struct CodexAdvancedSectionCardView<Content: View>: View {
    public struct Config {
        public var content: () -> Content

        public init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
    }

    let content: () -> Content

    public init(config: Config) {
        self.content = config.content
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.init(config: Config(content: content))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }
}

// MARK: - CodexBinaryActionsBarView

public struct CodexBinaryActionsBarView: View {
    public let data: CodexBinaryActionBarData
    public let onPrimaryAction: () -> Void
    public let onCheckUpdates: () -> Void
    public let onImportLocal: () -> Void
    public let onOpenGitHub: () -> Void
    public let onToggleBeta: (Bool) -> Void

    public struct Config {
        public var data: CodexBinaryActionBarData
        public var onPrimaryAction: () -> Void
        public var onCheckUpdates: () -> Void
        public var onImportLocal: () -> Void
        public var onOpenGitHub: () -> Void
        public var onToggleBeta: (Bool) -> Void

        public init(
            data: CodexBinaryActionBarData,
            onPrimaryAction: @escaping () -> Void,
            onCheckUpdates: @escaping () -> Void,
            onImportLocal: @escaping () -> Void,
            onOpenGitHub: @escaping () -> Void,
            onToggleBeta: @escaping (Bool) -> Void
        ) {
            self.data = data
            self.onPrimaryAction = onPrimaryAction
            self.onCheckUpdates = onCheckUpdates
            self.onImportLocal = onImportLocal
            self.onOpenGitHub = onOpenGitHub
            self.onToggleBeta = onToggleBeta
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onPrimaryAction = config.onPrimaryAction
        self.onCheckUpdates = config.onCheckUpdates
        self.onImportLocal = config.onImportLocal
        self.onOpenGitHub = config.onOpenGitHub
        self.onToggleBeta = config.onToggleBeta
    }

    public init(
        data: CodexBinaryActionBarData,
        onPrimaryAction: @escaping () -> Void,
        onCheckUpdates: @escaping () -> Void,
        onImportLocal: @escaping () -> Void,
        onOpenGitHub: @escaping () -> Void,
        onToggleBeta: @escaping (Bool) -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onPrimaryAction: onPrimaryAction,
                onCheckUpdates: onCheckUpdates,
                onImportLocal: onImportLocal,
                onOpenGitHub: onOpenGitHub,
                onToggleBeta: onToggleBeta
            )
        )
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedActionRow
            compactActionRow
        }
    }

    private var expandedActionRow: some View {
        HStack(spacing: 10) {
            Button(data.primaryActionTitle, action: onPrimaryAction)
                .dsPrimaryButton()
                .disabled(data.isBusy)

            Button(data.importLocalTitle, action: onImportLocal)
                .dsSecondaryButton()
                .disabled(data.isBusy)

            Button(data.openGitHubTitle, action: onOpenGitHub)
                .dsSecondaryButton()
                .disabled(data.isBusy)

            Spacer(minLength: 0)

            Toggle(
                data.showBetaTitle,
                isOn: Binding(
                    get: { data.showBetaEnabled },
                    set: { value in
                        onToggleBeta(value)
                    }
                )
            )
            .toggleStyle(.switch)
        }
    }

    private var compactActionRow: some View {
        HStack(spacing: 10) {
            Button(data.primaryActionTitle, action: onPrimaryAction)
                .dsPrimaryButton()
                .disabled(data.isBusy)

            Menu {
                Button(data.checkUpdatesTitle, action: onCheckUpdates)
                Button(data.importLocalTitle, action: onImportLocal)
                Button(data.openGitHubTitle, action: onOpenGitHub)
            } label: {
                Label(data.moreActionsTitle, systemImage: "ellipsis.circle")
            }
            .dsSecondaryButton()
            .disabled(data.isBusy)

            Spacer(minLength: 0)

            Toggle(
                data.showBetaTitle,
                isOn: Binding(
                    get: { data.showBetaEnabled },
                    set: { value in
                        onToggleBeta(value)
                    }
                )
            )
            .toggleStyle(.switch)
        }
    }
}

// MARK: - CodexBinaryModelCardView

public struct CodexBinaryModelCardView: View {
    let title: String
    let description: String
    let modelLabel: String
    let defaultOptionTitle: String
    let modelOptions: [String]
    @Binding var draftModel: String
    let isSaving: Bool
    let canSave: Bool
    let saveTitle: String
    let statusMessage: String?
    let emptyHint: String?
    let onSave: () -> Void

    public struct Config {
        public var title: String
        public var description: String
        public var modelLabel: String
        public var defaultOptionTitle: String
        public var modelOptions: [String]
        public var isSaving: Bool
        public var canSave: Bool
        public var saveTitle: String
        public var statusMessage: String?
        public var emptyHint: String?
        public var onSave: () -> Void

        public init(
            title: String,
            description: String,
            modelLabel: String,
            defaultOptionTitle: String,
            modelOptions: [String],
            isSaving: Bool,
            canSave: Bool,
            saveTitle: String,
            statusMessage: String?,
            emptyHint: String?,
            onSave: @escaping () -> Void
        ) {
            self.title = title
            self.description = description
            self.modelLabel = modelLabel
            self.defaultOptionTitle = defaultOptionTitle
            self.modelOptions = modelOptions
            self.isSaving = isSaving
            self.canSave = canSave
            self.saveTitle = saveTitle
            self.statusMessage = statusMessage
            self.emptyHint = emptyHint
            self.onSave = onSave
        }
    }

    public init(
        draftModel: Binding<String>,
        config: Config
    ) {
        self.title = config.title
        self.description = config.description
        self.modelLabel = config.modelLabel
        self.defaultOptionTitle = config.defaultOptionTitle
        self.modelOptions = config.modelOptions
        self._draftModel = draftModel
        self.isSaving = config.isSaving
        self.canSave = config.canSave
        self.saveTitle = config.saveTitle
        self.statusMessage = config.statusMessage
        self.emptyHint = config.emptyHint
        self.onSave = config.onSave
    }

    public init(
        title: String,
        description: String,
        modelLabel: String,
        defaultOptionTitle: String,
        modelOptions: [String],
        draftModel: Binding<String>,
        isSaving: Bool,
        canSave: Bool,
        saveTitle: String,
        statusMessage: String?,
        emptyHint: String?,
        onSave: @escaping () -> Void
    ) {
        self.init(
            draftModel: draftModel,
            config: Config(
                title: title,
                description: description,
                modelLabel: modelLabel,
                defaultOptionTitle: defaultOptionTitle,
                modelOptions: modelOptions,
                isSaving: isSaving,
                canSave: canSave,
                saveTitle: saveTitle,
                statusMessage: statusMessage,
                emptyHint: emptyHint,
                onSave: onSave
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Text(description)
                .font(.callout)
                .dsSecondaryText(font: .callout)

            Picker(modelLabel, selection: $draftModel) {
                Text(defaultOptionTitle).tag("")
                ForEach(modelOptions, id: \.self) { slug in
                    Text(slug).tag(slug)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                Button(saveTitle, action: onSave)
                    .dsPrimaryButton()
                    .disabled(!canSave || isSaving)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            if let emptyHint, !emptyHint.isEmpty {
                Text(emptyHint)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - CodexBinaryStatusHeaderView

public struct CodexBinaryStatusHeaderView: View {
    public let data: CodexBinaryStatusHeaderData

    public struct Config {
        public var data: CodexBinaryStatusHeaderData

        public init(data: CodexBinaryStatusHeaderData) {
            self.data = data
        }
    }

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: CodexBinaryStatusHeaderData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(data.hasUpdateAvailable ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success)
                    .frame(width: 8, height: 8)
                Text(data.statusText)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Text(data.currentCLITitle)
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Text(data.currentCLIVersion)
                    .font(.callout.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
            }

            if data.isSyncingRemoteVersions || data.remoteVersionSyncFailed {
                HStack(spacing: 8) {
                    if data.isSyncingRemoteVersions {
                        ProgressView()
                            .controlSize(.small)
                        Text(data.syncingText)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    } else if data.remoteVersionSyncFailed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DesignSystem.Colors.Status.warning)
                        Text(data.failedText)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - CodexBinaryVersionTableView

public struct CodexBinaryVersionTableView: View {
    public let data: CodexBinaryVersionTableData
    public let onTapRow: (String) -> Void
    public let onTapAction: (String) -> Void

    public struct Config {
        public var data: CodexBinaryVersionTableData
        public var onTapRow: (String) -> Void
        public var onTapAction: (String) -> Void

        public init(
            data: CodexBinaryVersionTableData,
            onTapRow: @escaping (String) -> Void,
            onTapAction: @escaping (String) -> Void
        ) {
            self.data = data
            self.onTapRow = onTapRow
            self.onTapAction = onTapAction
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onTapRow = config.onTapRow
        self.onTapAction = config.onTapAction
    }

    public init(
        data: CodexBinaryVersionTableData,
        onTapRow: @escaping (String) -> Void,
        onTapAction: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onTapRow: onTapRow,
                onTapAction: onTapAction
            )
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(DesignSystem.Colors.Component.border.opacity(0.35))

            ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row)
                if index != data.rows.count - 1 {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.28))
                }
            }
        }
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.38),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.22)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(data.nameTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.versionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.sourceTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.stateTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(data.actionsTitle)
                .frame(width: 120, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DesignSystem.Colors.Text.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func rowView(_ row: CodexBinaryVersionRowData) -> some View {
        HStack(spacing: 10) {
            Text(row.nameText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            Text(row.versionText)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            Text(row.sourceText)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text(row.stateText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(toneColor(row.stateTone))

            actionView(for: row)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard row.isSelectable else { return }
            onTapRow(row.id)
        }
    }

    @ViewBuilder
    private func actionView(for row: CodexBinaryVersionRowData) -> some View {
        if row.isActionInProgress {
            VStack(alignment: .trailing, spacing: 4) {
                if let fraction = row.progressFraction, let progressText = row.progressText {
                    ProgressView(value: fraction)
                        .frame(width: 70, alignment: .trailing)
                    Text(progressText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                } else {
                    ProgressView()
                        .frame(width: 70, alignment: .trailing)
                    Text(row.inProgressFallbackText ?? "")
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
            }
        } else if let actionTitle = row.actionTitle {
            Button(actionTitle) {
                onTapAction(row.id)
            }
            .buttonStyle(.plain)
            .foregroundStyle(row.kind == .local ? DesignSystem.Colors.Status.error : DesignSystem.Colors.primary)
            .disabled(!row.actionEnabled)
        } else {
            EmptyView()
        }
    }

    private func toneColor(_ tone: CodexBinaryRowTone) -> Color {
        switch tone {
        case .primary:
            return DesignSystem.Colors.Text.primary
        case .secondary:
            return DesignSystem.Colors.Text.secondary
        case .success:
            return DesignSystem.Colors.Status.success
        case .warning:
            return DesignSystem.Colors.Status.warning
        case .error:
            return DesignSystem.Colors.Status.error
        }
    }
}

// MARK: - CodexBinaryVersionsSectionView

public struct CodexBinaryVersionsSectionView: View {
    let statusHeaderData: CodexBinaryStatusHeaderData
    let actionBarData: CodexBinaryActionBarData
    let versionTableData: CodexBinaryVersionTableData
    let releaseNotesData: CodexBinaryReleaseNotesData?
    let onPrimaryAction: () -> Void
    let onCheckUpdates: () -> Void
    let onImportLocal: () -> Void
    let onOpenGitHub: () -> Void
    let onToggleBeta: (Bool) -> Void
    let onTapRow: (String) -> Void
    let onTapAction: (String) -> Void

    public struct Config {
        public var statusHeaderData: CodexBinaryStatusHeaderData
        public var actionBarData: CodexBinaryActionBarData
        public var versionTableData: CodexBinaryVersionTableData
        public var releaseNotesData: CodexBinaryReleaseNotesData?
        public var onPrimaryAction: () -> Void
        public var onCheckUpdates: () -> Void
        public var onImportLocal: () -> Void
        public var onOpenGitHub: () -> Void
        public var onToggleBeta: (Bool) -> Void
        public var onTapRow: (String) -> Void
        public var onTapAction: (String) -> Void

        public init(
            statusHeaderData: CodexBinaryStatusHeaderData,
            actionBarData: CodexBinaryActionBarData,
            versionTableData: CodexBinaryVersionTableData,
            releaseNotesData: CodexBinaryReleaseNotesData?,
            onPrimaryAction: @escaping () -> Void,
            onCheckUpdates: @escaping () -> Void,
            onImportLocal: @escaping () -> Void,
            onOpenGitHub: @escaping () -> Void,
            onToggleBeta: @escaping (Bool) -> Void,
            onTapRow: @escaping (String) -> Void,
            onTapAction: @escaping (String) -> Void
        ) {
            self.statusHeaderData = statusHeaderData
            self.actionBarData = actionBarData
            self.versionTableData = versionTableData
            self.releaseNotesData = releaseNotesData
            self.onPrimaryAction = onPrimaryAction
            self.onCheckUpdates = onCheckUpdates
            self.onImportLocal = onImportLocal
            self.onOpenGitHub = onOpenGitHub
            self.onToggleBeta = onToggleBeta
            self.onTapRow = onTapRow
            self.onTapAction = onTapAction
        }
    }

    public init(config: Config) {
        self.statusHeaderData = config.statusHeaderData
        self.actionBarData = config.actionBarData
        self.versionTableData = config.versionTableData
        self.releaseNotesData = config.releaseNotesData
        self.onPrimaryAction = config.onPrimaryAction
        self.onCheckUpdates = config.onCheckUpdates
        self.onImportLocal = config.onImportLocal
        self.onOpenGitHub = config.onOpenGitHub
        self.onToggleBeta = config.onToggleBeta
        self.onTapRow = config.onTapRow
        self.onTapAction = config.onTapAction
    }

    public init(
        statusHeaderData: CodexBinaryStatusHeaderData,
        actionBarData: CodexBinaryActionBarData,
        versionTableData: CodexBinaryVersionTableData,
        releaseNotesData: CodexBinaryReleaseNotesData? = nil,
        onPrimaryAction: @escaping () -> Void,
        onCheckUpdates: @escaping () -> Void,
        onImportLocal: @escaping () -> Void,
        onOpenGitHub: @escaping () -> Void,
        onToggleBeta: @escaping (Bool) -> Void,
        onTapRow: @escaping (String) -> Void,
        onTapAction: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                statusHeaderData: statusHeaderData,
                actionBarData: actionBarData,
                versionTableData: versionTableData,
                releaseNotesData: releaseNotesData,
                onPrimaryAction: onPrimaryAction,
                onCheckUpdates: onCheckUpdates,
                onImportLocal: onImportLocal,
                onOpenGitHub: onOpenGitHub,
                onToggleBeta: onToggleBeta,
                onTapRow: onTapRow,
                onTapAction: onTapAction
            )
        )
    }

    public var body: some View {
        CodexAdvancedSectionCardView {
            CodexBinaryStatusHeaderView(data: statusHeaderData)

            CodexBinaryActionsBarView(
                data: actionBarData,
                onPrimaryAction: onPrimaryAction,
                onCheckUpdates: onCheckUpdates,
                onImportLocal: onImportLocal,
                onOpenGitHub: onOpenGitHub,
                onToggleBeta: onToggleBeta
            )

            CodexBinaryVersionTableView(
                data: versionTableData,
                onTapRow: onTapRow,
                onTapAction: onTapAction
            )

            if let releaseNotesData {
                CodexBinaryReleaseNotesView(data: releaseNotesData)
            }
        }
    }
}

public struct CodexBinaryReleaseNotesView: View {
    let data: CodexBinaryReleaseNotesData

    public init(data: CodexBinaryReleaseNotesData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Text(data.versionText)
                        .font(.callout.monospaced())
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    if let subtitleText = data.subtitleText, !subtitleText.isEmpty {
                        Text(subtitleText)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }

                Spacer(minLength: 0)

                if let actionTitle = data.actionTitle,
                   let actionURL = data.actionURL {
                    Button(actionTitle) {
                        NSWorkspace.shared.open(actionURL)
                    }
                    .dsSecondaryButton()
                }
            }

            if let notes = data.notesMarkdown,
               !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Markdown(notes)
                    .markdownTheme(.nolon)
                    .markdownSoftBreakMode(.lineBreak)
                    .textSelection(.enabled)
            } else {
                Text(data.emptyText)
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.38),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.22)
        )
    }
}

// MARK: - CodexRuntimeProcessRowView

public struct CodexRuntimeProcessRowView<ExpandedContent: View>: View {
    public let data: CodexRuntimeProcessRowData
    public let onStop: () -> Void
    public let onForce: () -> Void
    public let onToggleSelection: () -> Void
    public let expandedContent: () -> ExpandedContent

    public struct Config {
        public var data: CodexRuntimeProcessRowData
        public var onStop: () -> Void
        public var onForce: () -> Void
        public var onToggleSelection: () -> Void

        public init(
            data: CodexRuntimeProcessRowData,
            onStop: @escaping () -> Void,
            onForce: @escaping () -> Void,
            onToggleSelection: @escaping () -> Void
        ) {
            self.data = data
            self.onStop = onStop
            self.onForce = onForce
            self.onToggleSelection = onToggleSelection
        }
    }

    public init(
        config: Config,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.data = config.data
        self.onStop = config.onStop
        self.onForce = config.onForce
        self.onToggleSelection = config.onToggleSelection
        self.expandedContent = expandedContent
    }

    public init(
        data: CodexRuntimeProcessRowData,
        onStop: @escaping () -> Void,
        onForce: @escaping () -> Void,
        onToggleSelection: @escaping () -> Void,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.init(
            config: Config(
                data: data,
                onStop: onStop,
                onForce: onForce,
                onToggleSelection: onToggleSelection
            ),
            expandedContent: expandedContent
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(data.pidText)
                    .font(.subheadline.monospacedDigit())

                Text(data.elapsedText)
                    .font(.caption.monospacedDigit())
                    .dsSecondaryText(font: .caption)

                if let hint = data.providerHint, !hint.isEmpty {
                    Text(hint)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Background.elevated
                        )
                }

                Spacer()

                Button(data.stopTitle, action: onStop)
                    .disabled(data.isStopping)

                Button(data.forceTitle, action: onForce)
                    .disabled(data.isStopping)
            }

            Text(data.commandText)
                .font(.caption.monospaced())
                .lineLimit(2)
                .textSelection(.enabled)
                .dsSecondaryText(font: .caption)

            if let workingDirectory = data.workingDirectory, !workingDirectory.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                    Text(workingDirectory)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .dsSecondaryText(font: .caption)
                }
            }

            if data.isSelected {
                expandedContent()
            }
        }
        .padding(10)
        .dsCard(
            background: data.isSelected ? DesignSystem.Colors.primary.opacity(0.08) : DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: data.isSelected ? DesignSystem.Colors.primary.opacity(0.45) : DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleSelection)
    }
}

// MARK: - CodexRuntimeSectionShellViews

public struct CodexRuntimeActionsBarView: View {
    public let data: CodexRuntimeActionsBarData
    public let onRefresh: () -> Void

    public struct Config {
        public var data: CodexRuntimeActionsBarData
        public var onRefresh: () -> Void

        public init(
            data: CodexRuntimeActionsBarData,
            onRefresh: @escaping () -> Void
        ) {
            self.data = data
            self.onRefresh = onRefresh
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onRefresh = config.onRefresh
    }

    public init(data: CodexRuntimeActionsBarData, onRefresh: @escaping () -> Void) {
        self.init(config: Config(data: data, onRefresh: onRefresh))
    }

    public var body: some View {
        HStack(spacing: 10) {
            Button(action: onRefresh) {
                Label(data.refreshTitle, systemImage: data.refreshSystemImage)
            }
            .disabled(data.isBusy)

            if let summary = data.stopSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Spacer()
        }
    }
}

public struct CodexRuntimeProcessesSectionCard<Content: View>: View {
    public let data: CodexRuntimeProcessesSectionData
    public let isEmpty: Bool
    public let content: () -> Content

    public struct Config {
        public var data: CodexRuntimeProcessesSectionData
        public var isEmpty: Bool

        public init(
            data: CodexRuntimeProcessesSectionData,
            isEmpty: Bool
        ) {
            self.data = data
            self.isEmpty = isEmpty
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.data = config.data
        self.isEmpty = config.isEmpty
        self.content = content
    }

    public init(
        data: CodexRuntimeProcessesSectionData,
        isEmpty: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(data: data, isEmpty: isEmpty),
            content: content
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.title)
                .font(.headline)

            if isEmpty {
                Text(data.emptyText)
                    .dsSecondaryText(font: .callout)
            } else {
                content()
            }
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }
}

// MARK: - CodexRuntimeSectionViews

public struct CodexRuntimeDiagnosticsCardView: View {
    public let title: String
    public let rows: [CodexRuntimeDiagnosticRowData]

    public struct Config {
        public var title: String
        public var rows: [CodexRuntimeDiagnosticRowData]

        public init(
            title: String = NSLocalizedString(
                "codex.runtime.diagnostics.title",
                value: "Diagnostics",
                comment: "Runtime diagnostics title"
            ),
            rows: [CodexRuntimeDiagnosticRowData]
        ) {
            self.title = title
            self.rows = rows
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.rows = config.rows
    }

    public init(
        title: String = NSLocalizedString(
            "codex.runtime.diagnostics.title",
            value: "Diagnostics",
            comment: "Runtime diagnostics title"
        ),
        rows: [CodexRuntimeDiagnosticRowData]
    ) {
        self.init(config: Config(title: title, rows: rows))
    }

    public var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.label)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                            .frame(width: 90, alignment: .leading)
                        Text(row.value)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }
                }
            }
            .padding(8)
            .dsCard(
                background: DesignSystem.Colors.Background.elevated,
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border,
                borderWidth: 1
            )
        }
    }
}

public struct CodexRuntimeLogsCardView: View {
    public let data: CodexRuntimeLogsSectionData
    public let onRefresh: () -> Void
    public let onCopy: () -> Void
    public let onClear: () -> Void

    public struct Config {
        public var data: CodexRuntimeLogsSectionData
        public var onRefresh: () -> Void
        public var onCopy: () -> Void
        public var onClear: () -> Void

        public init(
            data: CodexRuntimeLogsSectionData,
            onRefresh: @escaping () -> Void,
            onCopy: @escaping () -> Void,
            onClear: @escaping () -> Void
        ) {
            self.data = data
            self.onRefresh = onRefresh
            self.onCopy = onCopy
            self.onClear = onClear
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onRefresh = config.onRefresh
        self.onCopy = config.onCopy
        self.onClear = config.onClear
    }

    public init(
        data: CodexRuntimeLogsSectionData,
        onRefresh: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onRefresh: onRefresh,
                onCopy: onCopy,
                onClear: onClear
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(data.title)
                    .font(.headline)
                Spacer()
                if let pidText = data.pidText {
                    Text(pidText)
                        .font(.caption.monospacedDigit())
                        .dsSecondaryText(font: .caption)
                }
            }

            HStack(spacing: 10) {
                Button(data.refreshTitle, action: onRefresh)
                    .disabled(data.isLoading)

                Button(data.copyTitle, action: onCopy)
                    .disabled(data.logsText.isEmpty)

                Button(data.clearTitle, action: onClear)
                    .disabled(data.logsText.isEmpty && data.errorMessage == nil)

                Spacer()

                if data.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = data.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.error)
            }

            ScrollView {
                Text(data.logsText.isEmpty ? data.emptyText : data.logsText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 140)
            .dsCard(
                background: DesignSystem.Colors.Background.elevated,
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border,
                borderWidth: 1
            )
        }
        .padding(.top, 2)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }
}

// MARK: - CodexRuntimeTabContentView

public struct CodexRuntimeTabContentView<Rows: View>: View {
    let actionsBarData: CodexRuntimeActionsBarData
    let onRefresh: () -> Void
    let processesSectionData: CodexRuntimeProcessesSectionData
    let isProcessesEmpty: Bool
    let rows: () -> Rows

    public struct Config {
        public var actionsBarData: CodexRuntimeActionsBarData
        public var onRefresh: () -> Void
        public var processesSectionData: CodexRuntimeProcessesSectionData
        public var isProcessesEmpty: Bool

        public init(
            actionsBarData: CodexRuntimeActionsBarData,
            onRefresh: @escaping () -> Void,
            processesSectionData: CodexRuntimeProcessesSectionData,
            isProcessesEmpty: Bool
        ) {
            self.actionsBarData = actionsBarData
            self.onRefresh = onRefresh
            self.processesSectionData = processesSectionData
            self.isProcessesEmpty = isProcessesEmpty
        }
    }

    public init(
        config: Config,
        @ViewBuilder rows: @escaping () -> Rows
    ) {
        self.actionsBarData = config.actionsBarData
        self.onRefresh = config.onRefresh
        self.processesSectionData = config.processesSectionData
        self.isProcessesEmpty = config.isProcessesEmpty
        self.rows = rows
    }

    public init(
        actionsBarData: CodexRuntimeActionsBarData,
        onRefresh: @escaping () -> Void,
        processesSectionData: CodexRuntimeProcessesSectionData,
        isProcessesEmpty: Bool,
        @ViewBuilder rows: @escaping () -> Rows
    ) {
        self.init(
            config: Config(
                actionsBarData: actionsBarData,
                onRefresh: onRefresh,
                processesSectionData: processesSectionData,
                isProcessesEmpty: isProcessesEmpty
            ),
            rows: rows
        )
    }

    public var body: some View {
        CodexRuntimeActionsBarView(
            data: actionsBarData,
            onRefresh: onRefresh
        )

        CodexRuntimeProcessesSectionCard(
            data: processesSectionData,
            isEmpty: isProcessesEmpty
        ) {
            if !isProcessesEmpty {
                rows()
            }
        }
    }
}
