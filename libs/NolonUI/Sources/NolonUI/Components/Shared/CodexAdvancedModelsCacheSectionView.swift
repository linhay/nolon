import SwiftUI
import NolonUIFoundation

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
        self.title = title
        self.isApplyingModel = isApplyingModel
        self.reasoningLabel = reasoningLabel
        self.reasoningOptions = reasoningOptions
        self._reasoningSelection = reasoningSelection
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
        self._modelSelection = modelSelection
        self.isModelDisabled = isModelDisabled
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

