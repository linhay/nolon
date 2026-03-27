import SwiftUI
import ProviderCatalog
import NolonUI

struct ProviderCodexBinaryView: View {
    let provider: Provider
    @Bindable var viewModel: ProviderDetailGridViewModel

    @State private var draftModel: String = Self.defaultModelKey

    private static let defaultModelKey = "__nolon_model_default__"

    private var selectedKey: String {
        viewModel.selectedCodexModel ?? Self.defaultModelKey
    }

    private var draftModelBindingValue: String {
        draftModel == Self.defaultModelKey ? "" : draftModel
    }

    private var hasChanges: Bool {
        draftModel != selectedKey
    }

    var body: some View {
        NolonUI.CodexBinaryModelCardView(
            title: NSLocalizedString("provider.binary.codex.title", value: "Codex Binary", comment: "Codex binary title"),
            description: NSLocalizedString(
                "provider.binary.codex.desc",
                value: "Choose the default model used by this Codex provider.",
                comment: "Codex binary model picker description"
            ),
            modelLabel: NSLocalizedString("provider.binary.codex.model", value: "Model", comment: "Codex model picker label"),
            defaultOptionTitle: NSLocalizedString("provider.binary.codex.model.default", value: "Follow CLI default", comment: "Default model option"),
            modelOptions: viewModel.codexModelOptions,
            draftModel: Binding(
                get: { draftModelBindingValue },
                set: { draftModel = $0.isEmpty ? Self.defaultModelKey : $0 }
            ),
            isSaving: viewModel.isSavingCodexModel,
            canSave: hasChanges,
            saveTitle: NSLocalizedString("action.save", value: "Save", comment: "Save action"),
            statusMessage: viewModel.codexModelStatusMessage,
            emptyHint: viewModel.codexModelOptions.isEmpty
                ? NSLocalizedString(
                    "provider.binary.codex.model.empty",
                    value: "No model list found in models_cache.json. Run Codex CLI once to refresh cache.",
                    comment: "No cached model list"
                )
                : nil
        ) {
            Task {
                let value = draftModel == Self.defaultModelKey ? nil : draftModel
                await viewModel.saveSelectedCodexModel(value)
            }
        }
        .onAppear {
            draftModel = selectedKey
        }
        .onChange(of: viewModel.selectedCodexModel) { _, _ in
            draftModel = selectedKey
        }
        .accessibilityIdentifier("provider.codex.binary.model")
    }
}
