import SwiftUI
import NolonUI

struct CodexConfigEditorSheet: View {
    @Binding var draft: ProviderUsageEngine.CodexConfigEditorDraft?
    let modelProviderOptions: [String]
    let errorMessage: String?
    let onCancel: () -> Void
    let onValidateConnection: () -> Void
    let onSave: () -> Void

    private var currentDraft: ProviderUsageEngine.CodexConfigEditorDraft? {
        draft
    }

    private var editorMode: ProviderUsageEngine.CodexConfigEditorMode? {
        currentDraft?.mode
    }

    private var title: String {
        guard let editorMode else {
            return NSLocalizedString("codex.accounts.config.title", value: "Codex Config", comment: "Codex config title")
        }
        return ProviderUsageEngine.codexConfigEditorTitle(for: editorMode)
    }

    private var subtitle: String? {
        guard let editorMode else { return nil }
        return ProviderUsageEngine.codexConfigEditorSubtitle(for: editorMode)
    }

    private var primaryActionTitle: String {
        guard let editorMode else {
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
        return ProviderUsageEngine.codexConfigEditorPrimaryActionTitle(for: editorMode)
    }

    private var closeButtonHelp: String {
        NSLocalizedString("generic.close", value: "Close", comment: "Close")
    }

    private var headerTrailingPadding: CGFloat {
        SkillDetailScaffoldMetrics.closeButtonPadding + FloatingCloseButtonMetrics.buttonFrameSize + 12
    }

    private var canSaveDraft: Bool {
        guard let draft = currentDraft else { return false }
        return !draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canValidateConnection: Bool {
        canSaveDraft
    }

    private func binding(_ keyPath: WritableKeyPath<ProviderUsageEngine.CodexConfigEditorDraft, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { draft?[keyPath: keyPath] = $0 }
        )
    }

    var body: some View {
        Group {
            if currentDraft != nil {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.title3.weight(.semibold))

                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let errorMessage, !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.trailing, headerTrailingPadding)

                        Form {
                            TextField(
                                NSLocalizedString("codex.accounts.config.model_provider", value: "Model Provider", comment: "Codex relay model provider"),
                                text: binding(\.modelProvider)
                            )

                            TextField(
                                NSLocalizedString("codex.accounts.config.api_key", value: "API Key", comment: "Codex API key"),
                                text: binding(\.apiKey)
                            )

                            TextField(
                                NSLocalizedString("codex.accounts.config.base_url", value: "Base URL", comment: "Codex relay base URL"),
                                text: binding(\.baseURL)
                            )

                            if !modelProviderOptions.isEmpty {
                                Menu {
                                    ForEach(modelProviderOptions, id: \.self) { option in
                                        Button(option) {
                                            draft?.modelProvider = option
                                        }
                                    }
                                } label: {
                                    Label(
                                        NSLocalizedString(
                                            "codex.accounts.config.model_provider.suggested",
                                            value: "Suggested from current config",
                                            comment: "Model provider suggested options"
                                        ),
                                        systemImage: "list.bullet"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .formStyle(.grouped)

                        HStack {
                            Spacer(minLength: 0)

                            Button(NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")) {
                                onValidateConnection()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canValidateConnection)

                            Button(primaryActionTitle) {
                                onSave()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canSaveDraft)
                        }
                    }
                    .padding(20)
                    .frame(minWidth: 520, minHeight: 320)

                    FloatingCloseButton(
                        help: closeButtonHelp,
                        enableCancelShortcut: true,
                        action: onCancel
                    )
                    .padding(SkillDetailScaffoldMetrics.closeButtonPadding)
                    .accessibilityIdentifier("codex-config-editor-close")
                }
            }
        }
    }
}
