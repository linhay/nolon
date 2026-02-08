import SwiftUI
import ProviderCatalog

struct ProviderCodexBinaryView: View {
    let provider: Provider
    @Bindable var viewModel: ProviderDetailGridViewModel

    @State private var draftModel: String = Self.defaultModelKey

    private static let defaultModelKey = "__nolon_model_default__"

    private var selectedKey: String {
        viewModel.selectedCodexModel ?? Self.defaultModelKey
    }

    private var hasChanges: Bool {
        draftModel != selectedKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("provider.binary.codex.title", value: "Codex Binary", comment: "Codex binary title"))
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Text(
                NSLocalizedString(
                    "provider.binary.codex.desc",
                    value: "Choose the default model used by this Codex provider.",
                    comment: "Codex binary model picker description"
                )
            )
            .font(.callout)
            .dsSecondaryText(font: .callout)

            Picker(
                NSLocalizedString("provider.binary.codex.model", value: "Model", comment: "Codex model picker label"),
                selection: $draftModel
            ) {
                Text(NSLocalizedString("provider.binary.codex.model.default", value: "Follow CLI default", comment: "Default model option"))
                    .tag(Self.defaultModelKey)
                ForEach(viewModel.codexModelOptions, id: \.self) { slug in
                    Text(slug).tag(slug)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                Button(NSLocalizedString("action.save", value: "Save", comment: "Save action")) {
                    Task {
                        let value = draftModel == Self.defaultModelKey ? nil : draftModel
                        await viewModel.saveSelectedCodexModel(value)
                    }
                }
                .dsPrimaryButton()
                .disabled(!hasChanges || viewModel.isSavingCodexModel)

                if viewModel.isSavingCodexModel {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if let status = viewModel.codexModelStatusMessage, !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            if viewModel.codexModelOptions.isEmpty {
                Text(
                    NSLocalizedString(
                        "provider.binary.codex.model.empty",
                        value: "No model list found in models_cache.json. Run Codex CLI once to refresh cache.",
                        comment: "No cached model list"
                    )
                )
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
        .onAppear {
            draftModel = selectedKey
        }
        .onChange(of: viewModel.selectedCodexModel) { _, _ in
            draftModel = selectedKey
        }
        .accessibilityIdentifier("provider.codex.binary.model")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
