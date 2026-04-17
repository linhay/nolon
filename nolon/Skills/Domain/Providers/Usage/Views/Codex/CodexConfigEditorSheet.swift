import SwiftUI
import NolonUI

struct CodexConfigEditorSheet: View {
    @Binding var draft: ProviderUsageEngine.CodexConfigEditorDraft?
    @State private var authJSONEditorBridge = WebCodeEditorBridge()
    @State private var authJSONEditorErrorMessage: String?
    @State private var lastRenderedAuthPreviewJSON = ""
    let modelProviderOptions: [String]
    let isSaving: Bool
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
        canSaveDraft && !isSaving
    }

    private var emptyAuthPreviewJSON: String {
        """
        {
          "auth_mode" : "apikey",
          "OPENAI_API_KEY" : ""
        }
        """
    }

    private var emptyManagedConfigPreview: String {
        """
        # No managed config.toml changes.
        """
    }

    private func stringBinding(_ keyPath: WritableKeyPath<ProviderUsageEngine.CodexConfigEditorDraft, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { value in
                draft = Self.updatedDraft(draft) { draft in
                    draft[keyPath: keyPath] = value
                }
            }
        )
    }

    static func updatedDraft(
        _ draft: ProviderUsageEngine.CodexConfigEditorDraft?,
        mutate: (inout ProviderUsageEngine.CodexConfigEditorDraft) -> Void
    ) -> ProviderUsageEngine.CodexConfigEditorDraft? {
        guard var draft else { return nil }
        mutate(&draft)
        return draft
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
                                previewSection
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                        }
                        .disabled(isSaving)

                        Divider()

                        footer
                    }
                    .frame(minWidth: 860, minHeight: 720)
                    .background(DesignSystem.Colors.Background.canvas)

                    FloatingCloseButton(
                        help: closeButtonHelp,
                        enableCancelShortcut: true,
                        action: onCancel
                    )
                    .disabled(isSaving)
                    .padding(SkillDetailScaffoldMetrics.closeButtonPadding)
                    .accessibilityIdentifier("codex-config-editor-close")
                }
            }
        }
        .onAppear {
            syncAuthJSONEditorFromDraft(currentDraft)
        }
        .onChange(of: currentDraft) { _, newValue in
            syncAuthJSONEditorFromDraft(newValue)
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
        CodexConfigEditorSectionCard(
            title: NSLocalizedString(
                "codex.accounts.config.section.basics",
                value: "Basics",
                comment: "Codex config editor basics section"
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorField(
                    title: NSLocalizedString(
                        "codex.accounts.config.name",
                        value: "Name",
                        comment: "Codex config editor name field"
                    ),
                    hint: NSLocalizedString(
                        "codex.accounts.config.name.hint",
                        value: "Optional. Leave blank to derive a stable display name from the host.",
                        comment: "Codex config editor name hint"
                    )
                ) {
                    TextField("", text: stringBinding(\.name))
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                editorField(
                    title: NSLocalizedString(
                        "codex.accounts.config.api_key",
                        value: "API Key",
                        comment: "Codex API key"
                    ),
                    hint: NSLocalizedString(
                        "codex.accounts.config.api_key.hint",
                        value: "Required. This value is written into the managed auth.json when the account is saved.",
                        comment: "Codex config editor api key hint"
                    )
                ) {
                    TextField("", text: stringBinding(\.apiKey))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var connectionSection: some View {
        CodexConfigEditorSectionCard(
            title: NSLocalizedString(
                "codex.accounts.config.section.connection",
                value: "Relay",
                comment: "Codex config editor relay section"
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                editorField(
                    title: NSLocalizedString(
                        "codex.accounts.config.model_provider",
                        value: "Model Provider",
                        comment: "Codex relay model provider"
                    ),
                    hint: NSLocalizedString(
                        "codex.accounts.config.model_provider.hint",
                        value: "Optional for official API key mode. Required once a relay base URL is configured.",
                        comment: "Codex config editor model provider hint"
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("", text: stringBinding(\.modelProvider))
                            .textFieldStyle(.roundedBorder)

                        if !modelProviderOptions.isEmpty {
                            Menu {
                                ForEach(modelProviderOptions, id: \.self) { option in
                                    Button(option) {
                                        draft = Self.updatedDraft(draft) { draft in
                                            draft.modelProvider = option
                                        }
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
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Divider()

                editorField(
                    title: NSLocalizedString(
                        "codex.accounts.config.base_url",
                        value: "Base URL",
                        comment: "Codex relay base URL"
                    ),
                    hint: NSLocalizedString(
                        "codex.accounts.config.base_url.hint",
                        value: "Optional. Leave blank to keep this account in official API key mode. Once set, Nolon will also generate the managed config.toml preview below.",
                        comment: "Codex config editor base url hint"
                    )
                ) {
                    TextField("", text: stringBinding(\.baseURL))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var previewSection: some View {
        CodexConfigEditorSectionCard(
            title: NSLocalizedString(
                "codex.accounts.config.section.preview",
                value: "Generated Files",
                comment: "Codex config editor preview section"
            ),
            trailing: {
                Button(
                    NSLocalizedString(
                        "codex.accounts.config.action.format_json",
                        value: "Format JSON",
                        comment: "Codex config editor format json action"
                    )
                ) {
                    Task {
                        await formatAuthJSONEditorText()
                    }
                }
                .buttonStyle(.borderless)
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        NSLocalizedString(
                            "codex.accounts.config.preview.auth_title",
                            value: "auth.json",
                            comment: "Codex auth preview title"
                        )
                    )
                    .font(.headline)

                    Text(
                        NSLocalizedString(
                            "codex.accounts.config.preview.auth_hint",
                            value: "Edit the managed auth fragment directly. Valid JSON updates the form, and form edits rewrite this preview.",
                            comment: "Codex auth preview hint"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    authJSONEditorBlock(
                        currentDraft.map { CodexConfigEditorPreviewBuilder.authPreviewJSON(from: $0) }
                        ?? emptyAuthPreviewJSON
                    )

                    if let authJSONEditorErrorMessage, !authJSONEditorErrorMessage.isEmpty {
                        errorBanner(authJSONEditorErrorMessage)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        NSLocalizedString(
                            "codex.accounts.config.preview.config_title",
                            value: "config.toml",
                            comment: "Codex config preview title"
                        )
                    )
                    .font(.headline)

                    Text(
                        NSLocalizedString(
                            "codex.accounts.config.preview.config_hint",
                            value: "This preview shows the managed config.toml fragment Nolon will apply when the relay account becomes active.",
                            comment: "Codex config preview hint"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    managedConfigPreviewBlock(
                        currentDraft.map { CodexConfigEditorPreviewBuilder.managedConfigPreviewTOML(from: $0) }
                        ?? emptyManagedConfigPreview
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(
                NSLocalizedString(
                    "codex.accounts.config.footer.required",
                    value: "API Key is required before saving. Base URL is optional unless you are configuring a relay account.",
                    comment: "Codex config editor footer required hint"
                )
            )
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Spacer(minLength: 0)

            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")) {
                onCancel()
            }
            .buttonStyle(.bordered)
            .disabled(isSaving)
            .accessibilityIdentifier("codex-config-editor-cancel")

            Button(NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")) {
                onValidateConnection()
            }
            .buttonStyle(.bordered)
            .disabled(!canValidateConnection)
            .accessibilityIdentifier("codex-config-editor-validate")

            Button {
                onSave()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(primaryActionTitle)
                    }
                }
                .frame(minWidth: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveDraft || isSaving)
            .accessibilityIdentifier("codex-config-editor-save")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(DesignSystem.Colors.Background.elevated)
    }

    private func authJSONEditorBlock(_ value: String) -> some View {
        WebCodeEditorView(
            bridge: authJSONEditorBridge,
            initialText: value,
            highlight: WebCodeEditorHighlight(format: .json, key: "codex-managed-auth-preview"),
            onDirtyChanged: { _ in },
            onTextChanged: handleAuthJSONTextChanged
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

    private func managedConfigPreviewBlock(_ value: String) -> some View {
        ScrollView {
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.28), lineWidth: 1)
        )
    }

    private func handleAuthJSONTextChanged(_ text: String) {
        guard let currentDraft else {
            authJSONEditorErrorMessage = nil
            return
        }

        do {
            let updated = try CodexConfigEditorPreviewBuilder.applyingAuthPreviewJSON(text, to: currentDraft)
            authJSONEditorErrorMessage = nil
            if updated != currentDraft {
                draft = updated
            }
        } catch {
            authJSONEditorErrorMessage = error.localizedDescription
        }
    }

    private func syncAuthJSONEditorFromDraft(_ draft: ProviderUsageEngine.CodexConfigEditorDraft?) {
        let rendered = draft.map { CodexConfigEditorPreviewBuilder.authPreviewJSON(from: $0) } ?? emptyAuthPreviewJSON
        guard rendered != lastRenderedAuthPreviewJSON else { return }
        lastRenderedAuthPreviewJSON = rendered
        authJSONEditorBridge.setText(rendered)
    }

    private func formatAuthJSONEditorText() async {
        guard let currentDraft else { return }

        do {
            let text = try await authJSONEditorBridge.requestText()
            let updated = try CodexConfigEditorPreviewBuilder.applyingAuthPreviewJSON(text, to: currentDraft)
            let rendered = CodexConfigEditorPreviewBuilder.authPreviewJSON(from: updated)
            authJSONEditorErrorMessage = nil
            lastRenderedAuthPreviewJSON = rendered
            authJSONEditorBridge.setText(rendered)
            if updated != currentDraft {
                draft = updated
            }
        } catch {
            authJSONEditorErrorMessage = error.localizedDescription
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
    }
}

private struct CodexConfigEditorSectionCard<Content: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.headline)

                Spacer(minLength: 0)

                trailing
            }

            content
        }
        .padding(20)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18),
            shadow: DesignSystem.CardShadow.subtle
        )
    }
}
