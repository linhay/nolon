import SwiftUI
import ProviderUsage
import NolonUI

struct ClaudeAccountEditorSheet: View {
    typealias Draft = ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft

    @Binding var draft: Draft?
    @State private var jsonEditorBridge = WebCodeEditorBridge()
    @State private var jsonEditorErrorMessage: String?
    @State private var lastRenderedPreviewJSON = ""
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    private var currentDraft: Draft? {
        draft
    }

    private var emptyPreviewJSON: String {
        "{\n  \"env\" : {}\n}"
    }

    private var title: String {
        switch currentDraft?.mode {
        case .create:
            return NSLocalizedString(
                "claude.accounts.editor.create",
                value: "New Claude Account",
                comment: "Create Claude account"
            )
        case .edit:
            return NSLocalizedString(
                "claude.accounts.editor.edit",
                value: "Edit Claude Account",
                comment: "Edit Claude account"
            )
        case nil:
            return NSLocalizedString(
                "claude.accounts.editor.title",
                value: "Claude Account",
                comment: "Claude account editor title"
            )
        }
    }

    private var subtitle: String? {
        switch currentDraft?.mode {
        case .create:
            return NSLocalizedString(
                "claude.accounts.editor.create.subtitle",
                value: "Create a managed Claude account with a credential, base URL, and Cloud Code model mapping.",
                comment: "Claude account create subtitle"
            )
        case .edit:
            return NSLocalizedString(
                "claude.accounts.editor.edit.subtitle",
                value: "Update the stored credential, relay endpoint, and Cloud Code model mapping for this account.",
                comment: "Claude account edit subtitle"
            )
        case nil:
            return nil
        }
    }

    private var primaryActionTitle: String {
        switch currentDraft?.mode {
        case .create:
            return NSLocalizedString("generic.create", value: "Create", comment: "Create")
        case .edit:
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        case nil:
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
    }

    private var closeButtonHelp: String {
        NSLocalizedString("generic.close", value: "Close", comment: "Close")
    }

    private var headerTrailingPadding: CGFloat {
        SkillDetailScaffoldMetrics.closeButtonPadding + FloatingCloseButtonMetrics.buttonFrameSize + 12
    }

    private var canSaveDraft: Bool {
        currentDraft?.hasRequiredFields == true
    }

    private var credentialTypeBinding: Binding<ClaudeCredentialType> {
        Binding(
            get: { currentDraft?.credentialType ?? .authToken },
            set: { newValue in
                guard var draft = currentDraft else { return }
                draft.credentialType = newValue
                self.draft = draft
            }
        )
    }

    var body: some View {
        Group {
            if currentDraft != nil {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                header

                                if let errorMessage, !errorMessage.isEmpty {
                                    errorBanner(errorMessage)
                                }

                                basicsSection
                                connectionSection
                                modelSection
                                previewSection
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                        }

                        Divider()

                        footer
                    }
                    .frame(minWidth: 760, minHeight: 660)
                    .background(DesignSystem.Colors.Background.canvas)

                    FloatingCloseButton(
                        help: closeButtonHelp,
                        enableCancelShortcut: true,
                        action: onCancel
                    )
                    .padding(SkillDetailScaffoldMetrics.closeButtonPadding)
                    .accessibilityIdentifier("claude-account-editor-close")
                }
            }
        }
        .onAppear {
            syncJSONEditorFromDraft(currentDraft)
        }
        .onChange(of: currentDraft) { _, newValue in
            syncJSONEditorFromDraft(newValue)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.trailing, headerTrailingPadding)
    }

    private var basicsSection: some View {
        ClaudeAccountEditorSectionCard(
            title: NSLocalizedString(
                "claude.accounts.editor.section.basics",
                value: "Basics",
                comment: "Claude account editor basics section"
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorField(
                    title: NSLocalizedString(
                        "claude.accounts.editor.name",
                        value: "Name",
                        comment: "Claude account name"
                    ),
                    hint: NSLocalizedString(
                        "claude.accounts.editor.hint.name_optional",
                        value: "Optional. Leave blank to derive a readable name from the base URL.",
                        comment: "Claude account name optional hint"
                    )
                ) {
                    TextField("", text: stringBinding(\.name))
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                editorField(
                    title: NSLocalizedString(
                        "claude.accounts.editor.credential_type",
                        value: "Credential Type",
                        comment: "Claude credential type"
                    )
                ) {
                    Picker("", selection: credentialTypeBinding) {
                        Text(
                            NSLocalizedString(
                                "claude.accounts.editor.credential_type.auth_token",
                                value: "Auth Token",
                                comment: "Claude auth token credential type"
                            )
                        )
                        .tag(ClaudeCredentialType.authToken)

                        Text(
                            NSLocalizedString(
                                "claude.accounts.editor.credential_type.api_key",
                                value: "API Key",
                                comment: "Claude API key credential type"
                            )
                        )
                        .tag(ClaudeCredentialType.apiKey)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var connectionSection: some View {
        ClaudeAccountEditorSectionCard(
            title: NSLocalizedString(
                "claude.accounts.editor.section.connection",
                value: "Connection",
                comment: "Claude account editor connection section"
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorField(
                    title: NSLocalizedString(
                        "claude.accounts.editor.credential",
                        value: "Credential",
                        comment: "Claude credential value"
                    ),
                    hint: NSLocalizedString(
                        "claude.accounts.editor.hint.credential",
                        value: "Required. The value is stored in the managed account and written into Claude settings when this account becomes active.",
                        comment: "Claude credential hint"
                    )
                ) {
                    SecureField("", text: stringBinding(\.credentialValue))
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                editorField(
                    title: NSLocalizedString(
                        "claude.accounts.editor.base_url",
                        value: "Base URL",
                        comment: "Claude base URL"
                    ),
                    hint: NSLocalizedString(
                        "claude.accounts.editor.hint.base_url",
                        value: "Required. Use the upstream Claude endpoint or your custom relay base URL.",
                        comment: "Claude base URL hint"
                    )
                ) {
                    TextField("", text: stringBinding(\.baseURL))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var modelSection: some View {
        ClaudeAccountEditorSectionCard(
            title: NSLocalizedString(
                "claude.accounts.editor.section.models",
                value: "Model Mapping",
                comment: "Claude account editor models section"
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorField(
                    title: NSLocalizedString(
                        "claude.accounts.editor.model",
                        value: "Model",
                        comment: "Claude model field"
                    )
                ) {
                    TextField("", text: stringBinding(\.anthropicModel))
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                editorField(
                    title: NSLocalizedString(
                        "claude.accounts.editor.reasoning_model",
                        value: "Reasoning Model",
                        comment: "Claude reasoning model field"
                    ),
                    hint: NSLocalizedString(
                        "claude.accounts.editor.hint.reasoning_optional",
                        value: "Optional. Leave blank to keep reasoning traffic on the primary model.",
                        comment: "Claude reasoning model optional hint"
                    )
                ) {
                    TextField("", text: stringBinding(\.anthropicReasoningModel))
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                Text(
                    NSLocalizedString(
                        "claude.accounts.editor.hint.models",
                        value: "Optional. Only non-empty mapping fields will be written to Claude settings, so blank values stay aligned with the official runtime behavior.",
                        comment: "Claude model mapping hint"
                    )
                )
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    compactModelField(
                        title: NSLocalizedString(
                            "claude.accounts.editor.default_haiku_model",
                            value: "Default Haiku Model",
                            comment: "Claude default haiku model field"
                        ),
                        text: stringBinding(\.anthropicDefaultHaikuModel)
                    )

                    compactModelField(
                        title: NSLocalizedString(
                            "claude.accounts.editor.default_sonnet_model",
                            value: "Default Sonnet Model",
                            comment: "Claude default sonnet model field"
                        ),
                        text: stringBinding(\.anthropicDefaultSonnetModel)
                    )

                    compactModelField(
                        title: NSLocalizedString(
                            "claude.accounts.editor.default_opus_model",
                            value: "Default Opus Model",
                            comment: "Claude default opus model field"
                        ),
                        text: stringBinding(\.anthropicDefaultOpusModel)
                    )
                }
            }
        }
    }

    private var previewSection: some View {
        ClaudeAccountEditorSectionCard(
            title: NSLocalizedString(
                "claude.accounts.editor.section.preview",
                value: "Configuration JSON",
                comment: "Claude account editor preview section"
            ),
            trailing: {
                Button(
                    NSLocalizedString(
                        "claude.accounts.editor.action.format_json",
                        value: "Format JSON",
                        comment: "Claude account editor format json action"
                    )
                ) {
                    Task {
                        await formatJSONEditorText()
                    }
                }
                .buttonStyle(.borderless)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    NSLocalizedString(
                        "claude.accounts.editor.hint.preview",
                        value: "Edit this `env` fragment directly. Valid JSON updates the form, and form edits rewrite this editor. Empty model fields are omitted when formatted or saved.",
                        comment: "Claude preview hint"
                    )
                )
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

                jsonEditorBlock(
                    currentDraft.map { ClaudeAccountEditorPreviewBuilder.settingsPreviewJSON(from: $0) }
                    ?? emptyPreviewJSON
                )

                if let jsonEditorErrorMessage, !jsonEditorErrorMessage.isEmpty {
                    errorBanner(jsonEditorErrorMessage)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(
                NSLocalizedString(
                    "claude.accounts.editor.footer.required",
                    value: "Credential and base URL are required before saving.",
                    comment: "Claude editor footer required hint"
                )
            )
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Spacer(minLength: 0)

            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")) {
                onCancel()
            }
            .buttonStyle(.bordered)

            Button(primaryActionTitle) {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveDraft)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(DesignSystem.Colors.Background.elevated)
    }

    private func jsonEditorBlock(_ value: String) -> some View {
        WebCodeEditorView(
            bridge: jsonEditorBridge,
            initialText: value,
            highlight: nil,
            onDirtyChanged: { _ in },
            onTextChanged: handleJSONEditorTextChanged
        )
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 320, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.28), lineWidth: 1)
        )
    }

    private func handleJSONEditorTextChanged(_ text: String) {
        guard let currentDraft else {
            jsonEditorErrorMessage = nil
            return
        }

        do {
            let updated = try ClaudeAccountEditorPreviewBuilder.applyingSettingsPreviewJSON(text, to: currentDraft)
            jsonEditorErrorMessage = nil
            if updated != currentDraft {
                draft = updated
            }
        } catch {
            jsonEditorErrorMessage = error.localizedDescription
        }
    }

    private func syncJSONEditorFromDraft(_ draft: Draft?) {
        let rendered = draft.map { ClaudeAccountEditorPreviewBuilder.settingsPreviewJSON(from: $0) } ?? emptyPreviewJSON
        guard rendered != lastRenderedPreviewJSON else { return }
        lastRenderedPreviewJSON = rendered
        jsonEditorBridge.setText(rendered)
    }

    private func formatJSONEditorText() async {
        guard let currentDraft else { return }

        do {
            let text = try await jsonEditorBridge.requestText()
            let updated = try ClaudeAccountEditorPreviewBuilder.applyingSettingsPreviewJSON(text, to: currentDraft)
            let rendered = ClaudeAccountEditorPreviewBuilder.settingsPreviewJSON(from: updated)
            jsonEditorErrorMessage = nil
            lastRenderedPreviewJSON = rendered
            jsonEditorBridge.setText(rendered)
            if updated != currentDraft {
                draft = updated
            }
        } catch {
            jsonEditorErrorMessage = error.localizedDescription
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.error)

            Text(message)
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.Status.error)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .dsCard(
            background: DesignSystem.Colors.Status.error.opacity(0.08),
            borderColor: DesignSystem.Colors.Status.error.opacity(0.28),
            shadow: DesignSystem.CardShadow.subtle
        )
    }

    private func editorField<FieldContent: View>(
        title: String,
        hint: String? = nil,
        @ViewBuilder field: () -> FieldContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            field()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactModelField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stringBinding(_ keyPath: WritableKeyPath<Draft, String>) -> Binding<String> {
        Binding(
            get: { currentDraft?[keyPath: keyPath] ?? "" },
            set: { value in
                guard var draft = currentDraft else { return }
                draft[keyPath: keyPath] = value
                self.draft = draft
            }
        )
    }
}

private struct ClaudeAccountEditorSectionCard<Content: View, Trailing: View>: View {
    let title: String
    let trailing: Trailing
    let content: Content

    init(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.headline)

                Spacer(minLength: 0)

                trailing
            }

            content
        }
        .padding(18)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFillSubtle,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.28),
            shadow: DesignSystem.CardShadow.subtle
        )
    }
}
