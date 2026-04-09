import AppKit
import MarkdownUI
import NolonUIFoundation
import SwiftUI

// MARK: - CodexAdvancedCommonViews

public struct CodexAdvancedSectionHeaderView: View {
    let title: String

    public struct Config {
        public var title: String

        public init(title: String) {
            self.title = title
        }
    }

    public init(config: Config) {
        self.title = config.title
    }

    public init(title: String) {
        self.init(config: Config(title: title))
    }

    public var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }
}

public struct CodexAdvancedStatTileView: View {
    let data: CodexAdvancedStatTileData

    public struct Config {
        public var data: CodexAdvancedStatTileData

        public init(data: CodexAdvancedStatTileData) {
            self.data = data
        }
    }

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: CodexAdvancedStatTileData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text(data.value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.22), lineWidth: 1)
        )
    }
}

public struct CodexAdvancedPathInfoRowView: View {
    let data: CodexAdvancedPathInfoRowData

    public struct Config {
        public var data: CodexAdvancedPathInfoRowData

        public init(data: CodexAdvancedPathInfoRowData) {
            self.data = data
        }
    }

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: CodexAdvancedPathInfoRowData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.iconName)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(data.text)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.22),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.14)
        )
    }
}

public struct CodexAdvancedTrailingActionRowView: View {
    let title: String
    let onTap: () -> Void

    public struct Config {
        public var title: String
        public var onTap: () -> Void

        public init(
            title: String,
            onTap: @escaping () -> Void
        ) {
            self.title = title
            self.onTap = onTap
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.onTap = config.onTap
    }

    public init(title: String, onTap: @escaping () -> Void) {
        self.init(config: Config(title: title, onTap: onTap))
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(title) {
                onTap()
            }
            .dsSecondaryButton()
        }
    }
}

// MARK: - CodexAdvancedEditorFooterView

public struct CodexAdvancedEditorFooterView: View {
    let closeTitle: String
    let saveTitle: String
    let isSaveDisabled: Bool
    let onClose: () -> Void
    let onSave: () -> Void

    public struct Config {
        public var closeTitle: String
        public var saveTitle: String
        public var isSaveDisabled: Bool
        public var onClose: () -> Void
        public var onSave: () -> Void

        public init(
            closeTitle: String,
            saveTitle: String,
            isSaveDisabled: Bool,
            onClose: @escaping () -> Void,
            onSave: @escaping () -> Void
        ) {
            self.closeTitle = closeTitle
            self.saveTitle = saveTitle
            self.isSaveDisabled = isSaveDisabled
            self.onClose = onClose
            self.onSave = onSave
        }
    }

    public init(config: Config) {
        self.closeTitle = config.closeTitle
        self.saveTitle = config.saveTitle
        self.isSaveDisabled = config.isSaveDisabled
        self.onClose = config.onClose
        self.onSave = config.onSave
    }

    public init(
        closeTitle: String,
        saveTitle: String,
        isSaveDisabled: Bool,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                closeTitle: closeTitle,
                saveTitle: saveTitle,
                isSaveDisabled: isSaveDisabled,
                onClose: onClose,
                onSave: onSave
            )
        )
    }

    public var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            Button(closeTitle) {
                onClose()
            }
            .dsSecondaryButton()

            Button(saveTitle) {
                onSave()
            }
            .dsPrimaryButton()
            .disabled(isSaveDisabled)
        }
    }
}

// MARK: - CodexAdvancedFeatureFlagsSectionView

public struct CodexAdvancedFeatureFlagsSectionView: View {
    let searchPlaceholder: String
    @Binding var searchText: String
    let rows: [CodexAdvancedFeatureRowData]
    let onToggle: (String, Bool) -> Void

    public struct Config {
        public var searchPlaceholder: String
        public var rows: [CodexAdvancedFeatureRowData]
        public var onToggle: (String, Bool) -> Void

        public init(
            searchPlaceholder: String = NSLocalizedString(
                "codex.features.search.placeholder",
                value: "Search features...",
                comment: "Feature search placeholder"
            ),
            rows: [CodexAdvancedFeatureRowData],
            onToggle: @escaping (String, Bool) -> Void
        ) {
            self.searchPlaceholder = searchPlaceholder
            self.rows = rows
            self.onToggle = onToggle
        }
    }

    public init(
        searchText: Binding<String>,
        config: Config
    ) {
        self.searchPlaceholder = config.searchPlaceholder
        self._searchText = searchText
        self.rows = config.rows
        self.onToggle = config.onToggle
    }

    public init(
        searchPlaceholder: String = NSLocalizedString(
            "codex.features.search.placeholder",
            value: "Search features...",
            comment: "Feature search placeholder"
        ),
        searchText: Binding<String>,
        rows: [CodexAdvancedFeatureRowData],
        onToggle: @escaping (String, Bool) -> Void
    ) {
        self.init(
            searchText: searchText,
            config: Config(
                searchPlaceholder: searchPlaceholder,
                rows: rows,
                onToggle: onToggle
            )
        )
    }

    public var body: some View {
        CodexAdvancedSectionCardView {
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)

            ForEach(rows) { row in
                CodexAdvancedFeatureRowView(
                    data: row,
                    onToggle: { newValue in
                        onToggle(row.id, newValue)
                    }
                )
            }
        }
    }
}

// MARK: - CodexAdvancedFeatureRowView

public struct CodexAdvancedFeatureRowView: View {
    private struct ChipStyle {
        let foreground: Color
        let background: Color
        let border: Color
    }

    let data: CodexAdvancedFeatureRowData
    let onToggle: (Bool) -> Void

    public struct Config {
        public var data: CodexAdvancedFeatureRowData
        public var onToggle: (Bool) -> Void

        public init(
            data: CodexAdvancedFeatureRowData,
            onToggle: @escaping (Bool) -> Void
        ) {
            self.data = data
            self.onToggle = onToggle
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onToggle = config.onToggle
    }

    public init(
        data: CodexAdvancedFeatureRowData,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.init(config: Config(data: data, onToggle: onToggle))
    }

    public var body: some View {
        let maturityStyle = chipStyle(for: data.maturityTone)
        let sourceStyle = chipStyle(for: data.sourceTone)

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                highlightedText(data.keyText, query: data.queryText)
                    .font(.callout.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                highlightedText(data.descriptionText, query: data.queryText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                HStack(spacing: 6) {
                    highlightedText(data.maturityText, query: data.queryText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(maturityStyle.foreground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(maturityStyle.background, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(maturityStyle.border, lineWidth: 1)
                        )

                    highlightedText(data.sourceText, query: data.queryText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(sourceStyle.foreground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceStyle.background, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(sourceStyle.border, lineWidth: 1)
                        )
                }
            }

            Spacer(minLength: 0)

            Toggle(
                "",
                isOn: Binding(
                    get: { data.isEnabled },
                    set: { onToggle($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.25),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
        )
    }

    private func highlightedText(_ raw: String, query: String) -> Text {
        var text = AttributedString(raw)
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return Text(text) }

        let lowerRaw = raw.lowercased()
        let lowerKeyword = keyword.lowercased()
        var searchStart = lowerRaw.startIndex
        while let range = lowerRaw.range(of: lowerKeyword, range: searchStart..<lowerRaw.endIndex) {
            let lowerBound = lowerRaw.distance(from: lowerRaw.startIndex, to: range.lowerBound)
            let upperBound = lowerRaw.distance(from: lowerRaw.startIndex, to: range.upperBound)
            let start = text.index(text.startIndex, offsetByCharacters: lowerBound)
            let end = text.index(text.startIndex, offsetByCharacters: upperBound)
            text[start..<end].backgroundColor = .yellow.opacity(0.35)
            searchStart = range.upperBound
        }
        return Text(text)
    }

    private func chipStyle(for tone: CodexFeatureChipTone) -> ChipStyle {
        switch tone {
        case .success:
            return .init(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.14),
                border: DesignSystem.Colors.Status.success.opacity(0.45)
            )
        case .info:
            return .init(
                foreground: DesignSystem.Colors.Status.info,
                background: DesignSystem.Colors.Status.info.opacity(0.14),
                border: DesignSystem.Colors.Status.info.opacity(0.45)
            )
        case .warning:
            return .init(
                foreground: DesignSystem.Colors.Status.warning,
                background: DesignSystem.Colors.Status.warning.opacity(0.14),
                border: DesignSystem.Colors.Status.warning.opacity(0.45)
            )
        case .error:
            return .init(
                foreground: DesignSystem.Colors.Status.error,
                background: DesignSystem.Colors.Status.error.opacity(0.14),
                border: DesignSystem.Colors.Status.error.opacity(0.45)
            )
        case .secondary:
            return .init(
                foreground: DesignSystem.Colors.Text.secondary,
                background: DesignSystem.Colors.Component.controlFillSubtle.opacity(0.25),
                border: DesignSystem.Colors.Component.border.opacity(0.35)
            )
        }
    }
}

// MARK: - CodexAdvancedFormRows

public struct CodexAdvancedAlignedConfigRow<Control: View>: View {
    let label: String
    let description: String?
    let control: () -> Control

    public struct Config {
        public var label: String
        public var description: String?

        public init(
            label: String,
            description: String? = nil
        ) {
            self.label = label
            self.description = description
        }
    }

    public init(
        config: Config,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.label = config.label
        self.description = config.description
        self.control = control
    }

    public init(
        label: String,
        description: String? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.init(
            config: Config(label: label, description: description),
            control: control
        )
    }

    public var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            control()
                .frame(minWidth: 200, maxWidth: 420, alignment: .trailing)
        }
    }
}

// MARK: - CodexAdvancedInfoViews

public enum CodexAdvancedHintTone {
    case secondary
    case warning
}

public struct CodexAdvancedSectionHeaderRowView: View {
    let title: String
    let isLoading: Bool

    public struct Config {
        public var title: String
        public var isLoading: Bool

        public init(title: String, isLoading: Bool) {
            self.title = title
            self.isLoading = isLoading
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.isLoading = config.isLoading
    }

    public init(title: String, isLoading: Bool) {
        self.init(config: Config(title: title, isLoading: isLoading))
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer(minLength: 0)

            if isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }
}

public struct CodexAdvancedHintTextView: View {
    let text: String
    let tone: CodexAdvancedHintTone

    public struct Config {
        public var text: String
        public var tone: CodexAdvancedHintTone

        public init(
            text: String,
            tone: CodexAdvancedHintTone = .secondary
        ) {
            self.text = text
            self.tone = tone
        }
    }

    public init(config: Config) {
        self.text = config.text
        self.tone = config.tone
    }

    public init(text: String, tone: CodexAdvancedHintTone = .secondary) {
        self.init(config: Config(text: text, tone: tone))
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foregroundStyle)
    }

    private var foregroundStyle: Color {
        switch tone {
        case .secondary:
            return DesignSystem.Colors.Text.secondary
        case .warning:
            return DesignSystem.Colors.Status.warning
        }
    }
}

// MARK: - CodexAdvancedInputRows

public struct CodexAdvancedTextFieldRowView: View {
    let label: String
    let description: String?
    let placeholder: String
    @Binding var text: String
    let onTextChanged: (() -> Void)?

    public struct Config {
        public var label: String
        public var description: String?
        public var placeholder: String
        public var onTextChanged: (() -> Void)?

        public init(
            label: String,
            description: String? = nil,
            placeholder: String,
            onTextChanged: (() -> Void)? = nil
        ) {
            self.label = label
            self.description = description
            self.placeholder = placeholder
            self.onTextChanged = onTextChanged
        }
    }

    public init(
        text: Binding<String>,
        config: Config
    ) {
        self.label = config.label
        self.description = config.description
        self.placeholder = config.placeholder
        self._text = text
        self.onTextChanged = config.onTextChanged
    }

    public init(
        label: String,
        description: String? = nil,
        placeholder: String,
        text: Binding<String>,
        onTextChanged: (() -> Void)? = nil
    ) {
        self.init(
            text: text,
            config: Config(
                label: label,
                description: description,
                placeholder: placeholder,
                onTextChanged: onTextChanged
            )
        )
    }

    public var body: some View {
        CodexAdvancedAlignedConfigRow(label: label, description: description) {
            TextField(placeholder, text: $text)
                .onChange(of: text) { _, _ in
                    onTextChanged?()
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }
}

public struct CodexAdvancedNumericFieldRowView: View {
    let label: String
    let description: String?
    @Binding var text: String
    let onTextChanged: (() -> Void)?

    public struct Config {
        public var label: String
        public var description: String?
        public var onTextChanged: (() -> Void)?

        public init(
            label: String,
            description: String? = nil,
            onTextChanged: (() -> Void)? = nil
        ) {
            self.label = label
            self.description = description
            self.onTextChanged = onTextChanged
        }
    }

    public init(
        text: Binding<String>,
        config: Config
    ) {
        self.label = config.label
        self.description = config.description
        self._text = text
        self.onTextChanged = config.onTextChanged
    }

    public init(
        label: String,
        description: String? = nil,
        text: Binding<String>,
        onTextChanged: (() -> Void)? = nil
    ) {
        self.init(
            text: text,
            config: Config(
                label: label,
                description: description,
                onTextChanged: onTextChanged
            )
        )
    }

    public var body: some View {
        CodexAdvancedAlignedConfigRow(label: label, description: description) {
            TextField("", text: $text)
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue {
                        text = filtered
                        return
                    }
                    onTextChanged?()
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }
}


// MARK: - CodexAdvancedMetaRowsView

public struct CodexAdvancedMetaRowsView: View {
    let rows: [CodexAdvancedMetaRowData]

    public struct Config {
        public var rows: [CodexAdvancedMetaRowData]

        public init(rows: [CodexAdvancedMetaRowData]) {
            self.rows = rows
        }
    }

    public init(config: Config) {
        self.rows = config.rows
    }

    public init(rows: [CodexAdvancedMetaRowData]) {
        self.init(config: Config(rows: rows))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                Text(row.text)
                    .font(row.isMonospaced ? .caption.monospaced() : .caption)
                    .dsSecondaryText(font: .caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

// MARK: - CodexAdvancedModelsCacheSectionView

public struct CodexAdvancedModelsCacheSectionView: View {
    let title: String
    let isApplyingModel: Bool

    let reasoningLabel: String
    let reasoningOptions: [CodexAdvancedPickerOption]
    @Binding var reasoningSelection: String
    let isReasoningDisabled: Bool
    let isApplyingReasoning: Bool
    let showsReasoningUnsupportedHint: Bool
    let reasoningUnsupportedHintText: String

    let isModelsEmpty: Bool
    let modelsEmptyHintText: String
    let hasHiddenActiveModel: Bool
    let hiddenActiveModelHintText: String
    let modelLabel: String
    let modelOptions: [CodexAdvancedPickerOption]
    @Binding var modelSelection: String
    let isModelDisabled: Bool

    public struct Config {
        public var title: String
        public var isApplyingModel: Bool
        public var reasoningLabel: String
        public var reasoningOptions: [CodexAdvancedPickerOption]
        public var isReasoningDisabled: Bool
        public var isApplyingReasoning: Bool
        public var showsReasoningUnsupportedHint: Bool
        public var reasoningUnsupportedHintText: String
        public var isModelsEmpty: Bool
        public var modelsEmptyHintText: String
        public var hasHiddenActiveModel: Bool
        public var hiddenActiveModelHintText: String
        public var modelLabel: String
        public var modelOptions: [CodexAdvancedPickerOption]
        public var isModelDisabled: Bool

        public init(
            title: String,
            isApplyingModel: Bool,
            reasoningLabel: String,
            reasoningOptions: [CodexAdvancedPickerOption],
            isReasoningDisabled: Bool,
            isApplyingReasoning: Bool,
            showsReasoningUnsupportedHint: Bool,
            reasoningUnsupportedHintText: String,
            isModelsEmpty: Bool,
            modelsEmptyHintText: String,
            hasHiddenActiveModel: Bool,
            hiddenActiveModelHintText: String,
            modelLabel: String,
            modelOptions: [CodexAdvancedPickerOption],
            isModelDisabled: Bool
        ) {
            self.title = title
            self.isApplyingModel = isApplyingModel
            self.reasoningLabel = reasoningLabel
            self.reasoningOptions = reasoningOptions
            self.isReasoningDisabled = isReasoningDisabled
            self.isApplyingReasoning = isApplyingReasoning
            self.showsReasoningUnsupportedHint = showsReasoningUnsupportedHint
            self.reasoningUnsupportedHintText = reasoningUnsupportedHintText
            self.isModelsEmpty = isModelsEmpty
            self.modelsEmptyHintText = modelsEmptyHintText
            self.hasHiddenActiveModel = hasHiddenActiveModel
            self.hiddenActiveModelHintText = hiddenActiveModelHintText
            self.modelLabel = modelLabel
            self.modelOptions = modelOptions
            self.isModelDisabled = isModelDisabled
        }
    }

    public init(
        reasoningSelection: Binding<String>,
        modelSelection: Binding<String>,
        config: Config
    ) {
        self.title = config.title
        self.isApplyingModel = config.isApplyingModel
        self.reasoningLabel = config.reasoningLabel
        self.reasoningOptions = config.reasoningOptions
        self._reasoningSelection = reasoningSelection
        self.isReasoningDisabled = config.isReasoningDisabled
        self.isApplyingReasoning = config.isApplyingReasoning
        self.showsReasoningUnsupportedHint = config.showsReasoningUnsupportedHint
        self.reasoningUnsupportedHintText = config.reasoningUnsupportedHintText
        self.isModelsEmpty = config.isModelsEmpty
        self.modelsEmptyHintText = config.modelsEmptyHintText
        self.hasHiddenActiveModel = config.hasHiddenActiveModel
        self.hiddenActiveModelHintText = config.hiddenActiveModelHintText
        self.modelLabel = config.modelLabel
        self.modelOptions = config.modelOptions
        self._modelSelection = modelSelection
        self.isModelDisabled = config.isModelDisabled
    }

    public init(
        title: String,
        isApplyingModel: Bool,
        reasoningLabel: String,
        reasoningOptions: [CodexAdvancedPickerOption],
        reasoningSelection: Binding<String>,
        isReasoningDisabled: Bool,
        isApplyingReasoning: Bool,
        showsReasoningUnsupportedHint: Bool,
        reasoningUnsupportedHintText: String,
        isModelsEmpty: Bool,
        modelsEmptyHintText: String,
        hasHiddenActiveModel: Bool,
        hiddenActiveModelHintText: String,
        modelLabel: String,
        modelOptions: [CodexAdvancedPickerOption],
        modelSelection: Binding<String>,
        isModelDisabled: Bool
    ) {
        self.init(
            reasoningSelection: reasoningSelection,
            modelSelection: modelSelection,
            config: Config(
                title: title,
                isApplyingModel: isApplyingModel,
                reasoningLabel: reasoningLabel,
                reasoningOptions: reasoningOptions,
                isReasoningDisabled: isReasoningDisabled,
                isApplyingReasoning: isApplyingReasoning,
                showsReasoningUnsupportedHint: showsReasoningUnsupportedHint,
                reasoningUnsupportedHintText: reasoningUnsupportedHintText,
                isModelsEmpty: isModelsEmpty,
                modelsEmptyHintText: modelsEmptyHintText,
                hasHiddenActiveModel: hasHiddenActiveModel,
                hiddenActiveModelHintText: hiddenActiveModelHintText,
                modelLabel: modelLabel,
                modelOptions: modelOptions,
                isModelDisabled: isModelDisabled
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CodexAdvancedSectionHeaderRowView(
                title: title,
                isLoading: isApplyingModel
            )

            VStack(alignment: .leading, spacing: 8) {
                CodexAdvancedPickerRowView(
                    label: reasoningLabel,
                    options: reasoningOptions,
                    selection: $reasoningSelection,
                    isDisabled: isReasoningDisabled,
                    showsProgress: isApplyingReasoning
                )

                if showsReasoningUnsupportedHint {
                    CodexAdvancedHintTextView(text: reasoningUnsupportedHintText)
                }
            }

            if isModelsEmpty {
                CodexAdvancedHintTextView(text: modelsEmptyHintText)
            } else {
                if hasHiddenActiveModel {
                    CodexAdvancedHintTextView(
                        text: hiddenActiveModelHintText,
                        tone: .warning
                    )
                }

                CodexAdvancedPickerRowView(
                    label: modelLabel,
                    options: modelOptions,
                    selection: $modelSelection,
                    isDisabled: isModelDisabled
                )
            }
        }
    }
}


// MARK: - CodexAdvancedMultiAgentViews

public struct CodexAdvancedMultiAgentToggleRowView: View {
    let data: CodexAdvancedMultiAgentToggleRowData
    let onToggle: (Bool) -> Void

    public struct Config {
        public var data: CodexAdvancedMultiAgentToggleRowData
        public var onToggle: (Bool) -> Void

        public init(
            data: CodexAdvancedMultiAgentToggleRowData,
            onToggle: @escaping (Bool) -> Void
        ) {
            self.data = data
            self.onToggle = onToggle
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onToggle = config.onToggle
    }

    public init(
        data: CodexAdvancedMultiAgentToggleRowData,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.init(config: Config(data: data, onToggle: onToggle))
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text(data.labelText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

            Spacer(minLength: 0)

            Toggle(
                "",
                isOn: Binding(
                    get: { data.isEnabled },
                    set: { onToggle($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}

public struct CodexAdvancedMultiAgentStatusRowView: View {
    let data: CodexAdvancedMultiAgentStatusRowData

    public struct Config {
        public var data: CodexAdvancedMultiAgentStatusRowData

        public init(data: CodexAdvancedMultiAgentStatusRowData) {
            self.data = data
        }
    }

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: CodexAdvancedMultiAgentStatusRowData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(data.isEnabled ? DesignSystem.Colors.Status.success : DesignSystem.Colors.Text.secondary)

            Text(data.messageText)
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }
}

// MARK: - CodexAdvancedPickerRowView

public struct CodexAdvancedPickerRowView: View {
    let label: String
    let description: String?
    let options: [CodexAdvancedPickerOption]
    @Binding var selection: String
    let isDisabled: Bool
    let showsProgress: Bool
    let onSelectionChanged: (() -> Void)?

    public struct Config {
        public var label: String
        public var description: String?
        public var options: [CodexAdvancedPickerOption]
        public var isDisabled: Bool
        public var showsProgress: Bool
        public var onSelectionChanged: (() -> Void)?

        public init(
            label: String,
            description: String? = nil,
            options: [CodexAdvancedPickerOption],
            isDisabled: Bool = false,
            showsProgress: Bool = false,
            onSelectionChanged: (() -> Void)? = nil
        ) {
            self.label = label
            self.description = description
            self.options = options
            self.isDisabled = isDisabled
            self.showsProgress = showsProgress
            self.onSelectionChanged = onSelectionChanged
        }
    }

    public init(
        selection: Binding<String>,
        config: Config
    ) {
        self.label = config.label
        self.description = config.description
        self.options = config.options
        self._selection = selection
        self.isDisabled = config.isDisabled
        self.showsProgress = config.showsProgress
        self.onSelectionChanged = config.onSelectionChanged
    }

    public init(
        label: String,
        description: String? = nil,
        options: [CodexAdvancedPickerOption],
        selection: Binding<String>,
        isDisabled: Bool = false,
        showsProgress: Bool = false,
        onSelectionChanged: (() -> Void)? = nil
    ) {
        self.init(
            selection: selection,
            config: Config(
                label: label,
                description: description,
                options: options,
                isDisabled: isDisabled,
                showsProgress: showsProgress,
                onSelectionChanged: onSelectionChanged
            )
        )
    }

    public var body: some View {
        CodexAdvancedAlignedConfigRow(label: label, description: description) {
            HStack(spacing: 8) {
                Picker("", selection: $selection) {
                    ForEach(options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .onChange(of: selection) { _, _ in
                    onSelectionChanged?()
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isDisabled)
                .frame(maxWidth: .infinity, alignment: .trailing)

                if showsProgress {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }
}

// MARK: - CodexAdvancedRoleAddMenuContentView

public struct CodexAdvancedRoleAddMenuContentView: View {
    let addEmptyTitle: String
    let builtinItems: [CodexAdvancedRoleAddBuiltinItem]
    let onAddEmpty: () -> Void
    let onSelectBuiltin: (String) -> Void

    public struct Config {
        public var addEmptyTitle: String
        public var builtinItems: [CodexAdvancedRoleAddBuiltinItem]
        public var onAddEmpty: () -> Void
        public var onSelectBuiltin: (String) -> Void

        public init(
            addEmptyTitle: String,
            builtinItems: [CodexAdvancedRoleAddBuiltinItem],
            onAddEmpty: @escaping () -> Void,
            onSelectBuiltin: @escaping (String) -> Void
        ) {
            self.addEmptyTitle = addEmptyTitle
            self.builtinItems = builtinItems
            self.onAddEmpty = onAddEmpty
            self.onSelectBuiltin = onSelectBuiltin
        }
    }

    public init(config: Config) {
        self.addEmptyTitle = config.addEmptyTitle
        self.builtinItems = config.builtinItems
        self.onAddEmpty = config.onAddEmpty
        self.onSelectBuiltin = config.onSelectBuiltin
    }

    public init(
        addEmptyTitle: String,
        builtinItems: [CodexAdvancedRoleAddBuiltinItem],
        onAddEmpty: @escaping () -> Void,
        onSelectBuiltin: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                addEmptyTitle: addEmptyTitle,
                builtinItems: builtinItems,
                onAddEmpty: onAddEmpty,
                onSelectBuiltin: onSelectBuiltin
            )
        )
    }

    public var body: some View {
        Button(addEmptyTitle) {
            onAddEmpty()
        }

        if !builtinItems.isEmpty {
            Divider()
            ForEach(builtinItems) { item in
                Button(item.title) {
                    onSelectBuiltin(item.id)
                }
            }
        }
    }
}

// MARK: - CodexAdvancedRoleEditorRows

public struct CodexAdvancedRoleEditorRow<Control: View>: View {
    let label: String
    let labelWidth: CGFloat
    let spacing: CGFloat
    let control: () -> Control

    public struct Config {
        public var label: String
        public var labelWidth: CGFloat
        public var spacing: CGFloat

        public init(
            label: String,
            labelWidth: CGFloat = 180,
            spacing: CGFloat = 10
        ) {
            self.label = label
            self.labelWidth = labelWidth
            self.spacing = spacing
        }
    }

    public init(
        config: Config,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.label = config.label
        self.labelWidth = config.labelWidth
        self.spacing = config.spacing
        self.control = control
    }

    public init(
        label: String,
        labelWidth: CGFloat = 180,
        spacing: CGFloat = 10,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.init(
            config: Config(label: label, labelWidth: labelWidth, spacing: spacing),
            control: control
        )
    }

    public var body: some View {
        HStack(spacing: spacing) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: labelWidth, alignment: .leading)

            Spacer(minLength: 12)

            control()
        }
    }
}

public struct CodexAdvancedRoleTextFieldRowView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let textFieldWidth: CGFloat

    public struct Config {
        public var label: String
        public var placeholder: String
        public var textFieldWidth: CGFloat

        public init(
            label: String,
            placeholder: String,
            textFieldWidth: CGFloat = 360
        ) {
            self.label = label
            self.placeholder = placeholder
            self.textFieldWidth = textFieldWidth
        }
    }

    public init(
        text: Binding<String>,
        config: Config
    ) {
        self.label = config.label
        self.placeholder = config.placeholder
        self._text = text
        self.textFieldWidth = config.textFieldWidth
    }

    public init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        textFieldWidth: CGFloat = 360
    ) {
        self.init(
            text: text,
            config: Config(
                label: label,
                placeholder: placeholder,
                textFieldWidth: textFieldWidth
            )
        )
    }

    public var body: some View {
        CodexAdvancedRoleEditorRow(label: label) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: textFieldWidth, alignment: .trailing)
        }
    }
}

public struct CodexAdvancedRolePickerRowView: View {
    let label: String
    let options: [CodexAdvancedPickerOption]
    @Binding var selection: String
    let pickerWidth: CGFloat
    let onSelectionChanged: (() -> Void)?

    public struct Config {
        public var label: String
        public var options: [CodexAdvancedPickerOption]
        public var pickerWidth: CGFloat
        public var onSelectionChanged: (() -> Void)?

        public init(
            label: String,
            options: [CodexAdvancedPickerOption],
            pickerWidth: CGFloat = 260,
            onSelectionChanged: (() -> Void)? = nil
        ) {
            self.label = label
            self.options = options
            self.pickerWidth = pickerWidth
            self.onSelectionChanged = onSelectionChanged
        }
    }

    public init(
        selection: Binding<String>,
        config: Config
    ) {
        self.label = config.label
        self.options = config.options
        self._selection = selection
        self.pickerWidth = config.pickerWidth
        self.onSelectionChanged = config.onSelectionChanged
    }

    public init(
        label: String,
        options: [CodexAdvancedPickerOption],
        selection: Binding<String>,
        pickerWidth: CGFloat = 260,
        onSelectionChanged: (() -> Void)? = nil
    ) {
        self.init(
            selection: selection,
            config: Config(
                label: label,
                options: options,
                pickerWidth: pickerWidth,
                onSelectionChanged: onSelectionChanged
            )
        )
    }

    public var body: some View {
        CodexAdvancedRoleEditorRow(label: label) {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .onChange(of: selection) { _, _ in
                onSelectionChanged?()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: pickerWidth, alignment: .trailing)
        }
    }
}

// MARK: - CodexAdvancedRoleListView

public struct CodexAdvancedRoleListView: View {
    let emptyText: String
    let roles: [CodexAdvancedRoleRowData]
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void

    public struct Config {
        public var emptyText: String
        public var roles: [CodexAdvancedRoleRowData]
        public var onEdit: (String) -> Void
        public var onDelete: (String) -> Void

        public init(
            emptyText: String,
            roles: [CodexAdvancedRoleRowData],
            onEdit: @escaping (String) -> Void,
            onDelete: @escaping (String) -> Void
        ) {
            self.emptyText = emptyText
            self.roles = roles
            self.onEdit = onEdit
            self.onDelete = onDelete
        }
    }

    public init(config: Config) {
        self.emptyText = config.emptyText
        self.roles = config.roles
        self.onEdit = config.onEdit
        self.onDelete = config.onDelete
    }

    public init(
        emptyText: String,
        roles: [CodexAdvancedRoleRowData],
        onEdit: @escaping (String) -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                emptyText: emptyText,
                roles: roles,
                onEdit: onEdit,
                onDelete: onDelete
            )
        )
    }

    public var body: some View {
        if roles.isEmpty {
            CodexAdvancedRoleEmptyStateCardView(text: emptyText)
        } else {
            ForEach(roles) { role in
                CodexAdvancedRoleRowView(
                    data: role,
                    onEdit: { onEdit(role.id) },
                    onDelete: { onDelete(role.id) }
                )
            }
        }
    }
}

// MARK: - CodexAdvancedRoleSectionFooterView

public struct CodexAdvancedRoleSectionFooterView<MenuContent: View>: View {
    let addTitle: String
    let addSystemImage: String
    let saveTitle: String
    let isSaveDisabled: Bool
    let menuContent: () -> MenuContent
    let onSave: () -> Void

    public struct Config {
        public var addTitle: String
        public var addSystemImage: String
        public var saveTitle: String
        public var isSaveDisabled: Bool
        public var onSave: () -> Void

        public init(
            addTitle: String,
            addSystemImage: String = "plus",
            saveTitle: String,
            isSaveDisabled: Bool,
            onSave: @escaping () -> Void
        ) {
            self.addTitle = addTitle
            self.addSystemImage = addSystemImage
            self.saveTitle = saveTitle
            self.isSaveDisabled = isSaveDisabled
            self.onSave = onSave
        }
    }

    public init(
        config: Config,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.addTitle = config.addTitle
        self.addSystemImage = config.addSystemImage
        self.saveTitle = config.saveTitle
        self.isSaveDisabled = config.isSaveDisabled
        self.menuContent = menuContent
        self.onSave = config.onSave
    }

    public init(
        addTitle: String,
        addSystemImage: String = "plus",
        saveTitle: String,
        isSaveDisabled: Bool,
        @ViewBuilder menuContent: @escaping () -> MenuContent,
        onSave: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                addTitle: addTitle,
                addSystemImage: addSystemImage,
                saveTitle: saveTitle,
                isSaveDisabled: isSaveDisabled,
                onSave: onSave
            ),
            menuContent: menuContent
        )
    }

    public var body: some View {
        HStack {
            Menu {
                menuContent()
            } label: {
                Label(addTitle, systemImage: addSystemImage)
            }
            .dsSecondaryButton()

            Spacer(minLength: 0)

            Button(saveTitle) {
                onSave()
            }
            .dsPrimaryButton()
            .disabled(isSaveDisabled)
        }
    }
}

// MARK: - CodexAdvancedRoleViews

public struct CodexAdvancedRoleEmptyStateCardView: View {
    let text: String

    public struct Config {
        public var text: String

        public init(text: String) {
            self.text = text
        }
    }

    public init(config: Config) {
        self.text = config.text
    }

    public init(text: String) {
        self.init(config: Config(text: text))
    }

    public var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(
                background: DesignSystem.Colors.Background.surface.opacity(0.26),
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
            )
    }
}

public struct CodexAdvancedRoleRowView: View {
    let data: CodexAdvancedRoleRowData
    let onEdit: () -> Void
    let onDelete: () -> Void

    public struct Config {
        public var data: CodexAdvancedRoleRowData
        public var onEdit: () -> Void
        public var onDelete: () -> Void

        public init(
            data: CodexAdvancedRoleRowData,
            onEdit: @escaping () -> Void,
            onDelete: @escaping () -> Void
        ) {
            self.data = data
            self.onEdit = onEdit
            self.onDelete = onDelete
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onEdit = config.onEdit
        self.onDelete = config.onDelete
    }

    public init(
        data: CodexAdvancedRoleRowData,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.init(config: Config(data: data, onEdit: onEdit, onDelete: onDelete))
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(data.title)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Text(data.modelText)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

            Spacer(minLength: 0)

            Button(data.editTitle) {
                onEdit()
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.26),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
        )
    }
}
