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
