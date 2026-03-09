import SwiftUI
import ProviderUsage

struct CodexConfigEditorSheet: View {
    @Binding var draft: ProviderUsageViewModel.CodexConfigEditorDraft?
    let errorMessage: String?
    let testSuccessMessage: String?
    let testErrorMessage: String?
    let isTestingUsageQuery: Bool
    let onCancel: () -> Void
    let onTest: () -> Void
    let onSave: () -> Void

    @State private var isRelayAdvancedExpanded = false
    @State private var isAPIKeyAdvancedExpanded = false
    @State private var isHTTPUsageExpanded = false
    @State private var isHTTPCredentialsExpanded = false
    @State private var isHTTPMappingExpanded = false

    private var currentDraft: ProviderUsageViewModel.CodexConfigEditorDraft? {
        draft
    }

    private var isRelayMode: Bool {
        guard let draft = currentDraft else { return false }
        switch draft.mode {
        case .newRelay:
            return true
        case .newAPIKey:
            return false
        case .edit:
            return draft.isRelay
        }
    }

    private var editorMode: ProviderUsageViewModel.CodexConfigEditorMode? {
        currentDraft?.mode
    }

    private var title: String {
        guard let editorMode else {
            return NSLocalizedString("codex.accounts.config.title", value: "Codex Config", comment: "Codex config title")
        }
        return ProviderUsageViewModel.codexConfigEditorTitle(for: editorMode)
    }

    private var subtitle: String? {
        guard let editorMode else { return nil }
        return ProviderUsageViewModel.codexConfigEditorSubtitle(for: editorMode)
    }

    private var primaryActionTitle: String {
        guard let editorMode else {
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
        return ProviderUsageViewModel.codexConfigEditorPrimaryActionTitle(for: editorMode)
    }

    private var canRunTest: Bool {
        guard let draft = currentDraft else { return false }
        if isTestingUsageQuery {
            return false
        }
        guard draft.httpUsageEnabled else {
            return false
        }
        return !draft.httpUsageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveDraft: Bool {
        guard let draft = currentDraft else { return false }
        return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func binding(_ keyPath: WritableKeyPath<ProviderUsageViewModel.CodexConfigEditorDraft, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { draft?[keyPath: keyPath] = $0 }
        )
    }

    private var httpUsageEnabledBinding: Binding<Bool> {
        Binding(
            get: { draft?.httpUsageEnabled ?? false },
            set: {
                draft?.httpUsageEnabled = $0
                if $0 {
                    isHTTPUsageExpanded = true
                }
            }
        )
    }

    private var httpMethodBinding: Binding<CodexHTTPMethod> {
        Binding(
            get: { draft?.httpUsageMethod ?? .get },
            set: { draft?.httpUsageMethod = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title, subtitle: subtitle) {
                onCancel()
            }

            SheetDivider()

            Form {
                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Status.error)
                    }
                }

                if currentDraft != nil {
                    Section {
                        TextField(
                            NSLocalizedString("codex.accounts.config.name", value: "Name", comment: "Codex config name"),
                            text: binding(\.name)
                        )
                        SecureField(
                            NSLocalizedString("codex.accounts.config.api_key", value: "API Key", comment: "Codex API key"),
                            text: binding(\.apiKey)
                        )
                    } header: {
                        Text(NSLocalizedString("codex.accounts.config.basic", value: "Basic", comment: "Basic config section"))
                    } footer: {
                        Text(
                            isRelayMode
                            ? NSLocalizedString(
                                "codex.accounts.config.basic.footer.relay",
                                value: "先完成连接信息，保存后就能作为一张可切换的 Relay 卡使用。",
                                comment: "Relay basic footer"
                            )
                            : NSLocalizedString(
                                "codex.accounts.config.basic.footer.api_key",
                                value: "名称和 API Key 必填。Base URL 默认官方地址，其它配置都可以之后再补。",
                                comment: "API key basic footer"
                            )
                        )
                    }

                    if !isRelayMode {
                        Section {
                            DisclosureGroup(
                                NSLocalizedString("codex.accounts.config.advanced", value: "Advanced", comment: "Advanced config section title"),
                                isExpanded: $isAPIKeyAdvancedExpanded
                            ) {
                                TextField(
                                    NSLocalizedString("codex.accounts.config.base_url", value: "Base URL", comment: "Codex relay base URL"),
                                    text: binding(\.baseURL)
                                )

                                Text(
                                    NSLocalizedString(
                                        "codex.accounts.config.api_key_advanced.footer",
                                        value: "可选。默认使用 OpenAI 官方地址 https://api.openai.com/v1。",
                                        comment: "API key advanced footer"
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                        }
                    }

                    if isRelayMode {
                        Section {
                            TextField(
                                NSLocalizedString("codex.accounts.config.base_url", value: "Base URL", comment: "Codex relay base URL"),
                                text: binding(\.baseURL)
                            )
                            TextField(
                                NSLocalizedString("codex.accounts.config.model_provider", value: "Model Provider", comment: "Codex relay model provider"),
                                text: binding(\.modelProvider)
                            )
                        } header: {
                            Text(NSLocalizedString("codex.accounts.config.relay", value: "Relay", comment: "Relay section title"))
                        } footer: {
                            Text(NSLocalizedString(
                                "codex.accounts.config.relay.footer",
                                value: "通常只需要 Base URL 和 Provider；query/header 属于高级选项。",
                                comment: "Relay config footer"
                            ))
                        }

                        Section {
                            DisclosureGroup(
                                NSLocalizedString("codex.accounts.config.advanced", value: "Advanced", comment: "Advanced config section title"),
                                isExpanded: $isRelayAdvancedExpanded
                            ) {
                                TextField(
                                    NSLocalizedString("codex.accounts.config.query_params", value: "query=value", comment: "Relay query params"),
                                    text: binding(\.queryParamsText),
                                    axis: .vertical
                                )
                                .lineLimit(3, reservesSpace: true)

                                TextField(
                                    NSLocalizedString("codex.accounts.config.headers", value: "header=value", comment: "Relay headers"),
                                    text: binding(\.headersText),
                                    axis: .vertical
                                )
                                .lineLimit(3, reservesSpace: true)

                                Text(
                                    NSLocalizedString(
                                        "codex.accounts.config.advanced.footer",
                                        value: "One key=value pair per line.",
                                        comment: "Advanced config footer"
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                        }
                    }

                    Section {
                        DisclosureGroup(
                            isExpanded: $isHTTPUsageExpanded
                        ) {
                            Toggle(
                                NSLocalizedString("codex.accounts.http_usage.enabled", value: "Enable HTTP Usage Query", comment: "Enable HTTP usage query"),
                                isOn: httpUsageEnabledBinding
                            )

                            if currentDraft?.httpUsageEnabled == true {
                                Picker(
                                    NSLocalizedString("codex.accounts.http_usage.method", value: "Method", comment: "HTTP usage method"),
                                    selection: httpMethodBinding
                                ) {
                                    ForEach(CodexHTTPMethod.allCases, id: \.self) { method in
                                        Text(method.rawValue).tag(method)
                                    }
                                }

                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.url", value: "https://…", comment: "HTTP usage URL"),
                                    text: binding(\.httpUsageURL)
                                )

                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.timeout", value: "15", comment: "HTTP usage timeout"),
                                    text: binding(\.httpUsageTimeoutSeconds)
                                )

                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.headers", value: "Header=Value", comment: "HTTP usage headers"),
                                    text: binding(\.httpUsageHeadersText),
                                    axis: .vertical
                                )
                                .lineLimit(3, reservesSpace: true)

                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.body", value: "Optional body", comment: "HTTP usage body"),
                                    text: binding(\.httpUsageBody),
                                    axis: .vertical
                                )
                                .lineLimit(3, reservesSpace: true)

                                DisclosureGroup(
                                    NSLocalizedString("codex.accounts.http_usage.credentials", value: "Credentials Override", comment: "HTTP usage credentials"),
                                    isExpanded: $isHTTPCredentialsExpanded
                                ) {
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.override.base_url", value: "Override Base URL", comment: "Override base URL"),
                                        text: binding(\.httpUsageOverrideBaseURL)
                                    )
                                    SecureField(
                                        NSLocalizedString("codex.accounts.http_usage.override.api_key", value: "Override API Key", comment: "Override API key"),
                                        text: binding(\.httpUsageOverrideAPIKey)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.override.access_token", value: "Override Access Token", comment: "Override access token"),
                                        text: binding(\.httpUsageOverrideAccessToken)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.override.user_id", value: "Override User ID", comment: "Override user ID"),
                                        text: binding(\.httpUsageOverrideUserID)
                                    )
                                }

                                DisclosureGroup(
                                    NSLocalizedString("codex.accounts.http_usage.mapping", value: "Mapping", comment: "HTTP usage mapping"),
                                    isExpanded: $isHTTPMappingExpanded
                                ) {
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.plan", value: "Plan Path", comment: "Plan path"),
                                        text: binding(\.httpUsagePlanPath)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.credits", value: "Credits Remaining Path", comment: "Credits remaining path"),
                                        text: binding(\.httpUsageCreditsRemainingPath)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.used", value: "Used Path", comment: "Used path"),
                                        text: binding(\.httpUsageUsedPath)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.total", value: "Total Path", comment: "Total path"),
                                        text: binding(\.httpUsageTotalPath)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.cost_today", value: "Today Cost Path", comment: "Today cost path"),
                                        text: binding(\.httpUsageCostTodayPath)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.cost_30d", value: "30D Cost Path", comment: "30D cost path"),
                                        text: binding(\.httpUsageCostLast30DaysPath)
                                    )
                                    TextField(
                                        NSLocalizedString("codex.accounts.http_usage.mapping.error", value: "Error Message Path", comment: "Error message path"),
                                        text: binding(\.httpUsageErrorMessagePath)
                                    )
                                }

                                Button(NSLocalizedString("codex.accounts.http_usage.test", value: "Test Request", comment: "Test HTTP usage request")) {
                                    onTest()
                                }
                                .disabled(!canRunTest)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("codex.accounts.http_usage.section", value: "HTTP Usage Query", comment: "HTTP usage section"))
                                Text(
                                    NSLocalizedString(
                                        "codex.accounts.http_usage.summary",
                                        value: "可选。只有在你想覆盖默认 CLI 用量来源时才需要配置。",
                                        comment: "HTTP usage summary"
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                        }
                    }

                    if let testSuccessMessage, !testSuccessMessage.isEmpty {
                        Section {
                            Text(testSuccessMessage)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Status.success)
                        } header: {
                            Text(NSLocalizedString("codex.accounts.http_usage.test.result", value: "Latest Test", comment: "Latest HTTP usage test"))
                        }
                    }

                    if let testErrorMessage, !testErrorMessage.isEmpty {
                        Section {
                            Text(testErrorMessage)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Status.error)
                        } header: {
                            Text(NSLocalizedString("codex.accounts.http_usage.test.error", value: "Latest Error", comment: "Latest HTTP usage error"))
                        }
                    }
                }
            }
            .formStyle(.grouped)

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")) {
                    onCancel()
                }
                .dsSecondaryButton()

                Spacer()

                Button(primaryActionTitle) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSaveDraft)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(minWidth: 620, minHeight: isRelayMode ? 720 : 520)
        .onAppear {
            if isRelayMode {
                isRelayAdvancedExpanded = false
            } else {
                isAPIKeyAdvancedExpanded = false
            }
            if currentDraft?.httpUsageEnabled == true {
                isHTTPUsageExpanded = true
            }
        }
    }
}
