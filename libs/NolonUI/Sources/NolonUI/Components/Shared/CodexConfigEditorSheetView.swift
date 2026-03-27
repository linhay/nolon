import SwiftUI

public struct CodexConfigEditorSheetView: View {
    let title: String
    let subtitle: String?
    let primaryActionTitle: String
    let errorMessage: String?
    let testSuccessMessage: String?
    let testErrorMessage: String?
    let isRelayMode: Bool
    let isTestingUsageQuery: Bool
    let canRunTest: Bool
    let canSaveDraft: Bool
    let httpMethods: [String]
    @Binding var selectedHTTPMethod: String
    @Binding var name: String
    @Binding var apiKey: String
    @Binding var baseURL: String
    @Binding var modelProvider: String
    @Binding var queryParamsText: String
    @Binding var headersText: String
    @Binding var httpUsageEnabled: Bool
    @Binding var httpUsageURL: String
    @Binding var httpUsageTimeoutSeconds: String
    @Binding var httpUsageHeadersText: String
    @Binding var httpUsageBody: String
    @Binding var httpUsageOverrideBaseURL: String
    @Binding var httpUsageOverrideAPIKey: String
    @Binding var httpUsageOverrideAccessToken: String
    @Binding var httpUsageOverrideUserID: String
    @Binding var httpUsagePlanPath: String
    @Binding var httpUsageCreditsRemainingPath: String
    @Binding var httpUsageUsedPath: String
    @Binding var httpUsageTotalPath: String
    @Binding var httpUsageCostTodayPath: String
    @Binding var httpUsageCostLast30DaysPath: String
    @Binding var httpUsageErrorMessagePath: String
    let onCancel: () -> Void
    let onTest: () -> Void
    let onSave: () -> Void

    @State private var isRelayAdvancedExpanded = false
    @State private var isAPIKeyAdvancedExpanded = false
    @State private var isHTTPUsageExpanded = false
    @State private var isHTTPCredentialsExpanded = false
    @State private var isHTTPMappingExpanded = false

    public init(
        title: String,
        subtitle: String?,
        primaryActionTitle: String,
        errorMessage: String?,
        testSuccessMessage: String?,
        testErrorMessage: String?,
        isRelayMode: Bool,
        isTestingUsageQuery: Bool,
        canRunTest: Bool,
        canSaveDraft: Bool,
        httpMethods: [String],
        selectedHTTPMethod: Binding<String>,
        name: Binding<String>,
        apiKey: Binding<String>,
        baseURL: Binding<String>,
        modelProvider: Binding<String>,
        queryParamsText: Binding<String>,
        headersText: Binding<String>,
        httpUsageEnabled: Binding<Bool>,
        httpUsageURL: Binding<String>,
        httpUsageTimeoutSeconds: Binding<String>,
        httpUsageHeadersText: Binding<String>,
        httpUsageBody: Binding<String>,
        httpUsageOverrideBaseURL: Binding<String>,
        httpUsageOverrideAPIKey: Binding<String>,
        httpUsageOverrideAccessToken: Binding<String>,
        httpUsageOverrideUserID: Binding<String>,
        httpUsagePlanPath: Binding<String>,
        httpUsageCreditsRemainingPath: Binding<String>,
        httpUsageUsedPath: Binding<String>,
        httpUsageTotalPath: Binding<String>,
        httpUsageCostTodayPath: Binding<String>,
        httpUsageCostLast30DaysPath: Binding<String>,
        httpUsageErrorMessagePath: Binding<String>,
        onCancel: @escaping () -> Void,
        onTest: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryActionTitle = primaryActionTitle
        self.errorMessage = errorMessage
        self.testSuccessMessage = testSuccessMessage
        self.testErrorMessage = testErrorMessage
        self.isRelayMode = isRelayMode
        self.isTestingUsageQuery = isTestingUsageQuery
        self.canRunTest = canRunTest
        self.canSaveDraft = canSaveDraft
        self.httpMethods = httpMethods
        self._selectedHTTPMethod = selectedHTTPMethod
        self._name = name
        self._apiKey = apiKey
        self._baseURL = baseURL
        self._modelProvider = modelProvider
        self._queryParamsText = queryParamsText
        self._headersText = headersText
        self._httpUsageEnabled = httpUsageEnabled
        self._httpUsageURL = httpUsageURL
        self._httpUsageTimeoutSeconds = httpUsageTimeoutSeconds
        self._httpUsageHeadersText = httpUsageHeadersText
        self._httpUsageBody = httpUsageBody
        self._httpUsageOverrideBaseURL = httpUsageOverrideBaseURL
        self._httpUsageOverrideAPIKey = httpUsageOverrideAPIKey
        self._httpUsageOverrideAccessToken = httpUsageOverrideAccessToken
        self._httpUsageOverrideUserID = httpUsageOverrideUserID
        self._httpUsagePlanPath = httpUsagePlanPath
        self._httpUsageCreditsRemainingPath = httpUsageCreditsRemainingPath
        self._httpUsageUsedPath = httpUsageUsedPath
        self._httpUsageTotalPath = httpUsageTotalPath
        self._httpUsageCostTodayPath = httpUsageCostTodayPath
        self._httpUsageCostLast30DaysPath = httpUsageCostLast30DaysPath
        self._httpUsageErrorMessagePath = httpUsageErrorMessagePath
        self.onCancel = onCancel
        self.onTest = onTest
        self.onSave = onSave
    }

    public var body: some View {
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

                Section {
                    TextField(
                        NSLocalizedString("codex.accounts.config.name", value: "Name", comment: "Codex config name"),
                        text: $name
                    )
                    SecureField(
                        NSLocalizedString("codex.accounts.config.api_key", value: "API Key", comment: "Codex API key"),
                        text: $apiKey
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
                                text: $baseURL
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
                            text: $baseURL
                        )
                        TextField(
                            NSLocalizedString("codex.accounts.config.model_provider", value: "Model Provider", comment: "Codex relay model provider"),
                            text: $modelProvider
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
                                text: $queryParamsText,
                                axis: .vertical
                            )
                            .lineLimit(3, reservesSpace: true)

                            TextField(
                                NSLocalizedString("codex.accounts.config.headers", value: "header=value", comment: "Relay headers"),
                                text: $headersText,
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
                            isOn: $httpUsageEnabled
                        )

                        if httpUsageEnabled {
                            Picker(
                                NSLocalizedString("codex.accounts.http_usage.method", value: "Method", comment: "HTTP usage method"),
                                selection: $selectedHTTPMethod
                            ) {
                                ForEach(httpMethods, id: \.self) { method in
                                    Text(method).tag(method)
                                }
                            }

                            TextField(
                                NSLocalizedString("codex.accounts.http_usage.url", value: "https://…", comment: "HTTP usage URL"),
                                text: $httpUsageURL
                            )

                            TextField(
                                NSLocalizedString("codex.accounts.http_usage.timeout", value: "15", comment: "HTTP usage timeout"),
                                text: $httpUsageTimeoutSeconds
                            )

                            TextField(
                                NSLocalizedString("codex.accounts.http_usage.headers", value: "Header=Value", comment: "HTTP usage headers"),
                                text: $httpUsageHeadersText,
                                axis: .vertical
                            )
                            .lineLimit(3, reservesSpace: true)

                            TextField(
                                NSLocalizedString("codex.accounts.http_usage.body", value: "Optional body", comment: "HTTP usage body"),
                                text: $httpUsageBody,
                                axis: .vertical
                            )
                            .lineLimit(3, reservesSpace: true)

                            DisclosureGroup(
                                NSLocalizedString("codex.accounts.http_usage.credentials", value: "Credentials Override", comment: "HTTP usage credentials"),
                                isExpanded: $isHTTPCredentialsExpanded
                            ) {
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.override.base_url", value: "Override Base URL", comment: "Override base URL"),
                                    text: $httpUsageOverrideBaseURL
                                )
                                SecureField(
                                    NSLocalizedString("codex.accounts.http_usage.override.api_key", value: "Override API Key", comment: "Override API key"),
                                    text: $httpUsageOverrideAPIKey
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.override.access_token", value: "Override Access Token", comment: "Override access token"),
                                    text: $httpUsageOverrideAccessToken
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.override.user_id", value: "Override User ID", comment: "Override user ID"),
                                    text: $httpUsageOverrideUserID
                                )
                            }

                            DisclosureGroup(
                                NSLocalizedString("codex.accounts.http_usage.mapping", value: "Mapping", comment: "HTTP usage mapping"),
                                isExpanded: $isHTTPMappingExpanded
                            ) {
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.plan", value: "Plan Path", comment: "Plan path"),
                                    text: $httpUsagePlanPath
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.credits", value: "Credits Remaining Path", comment: "Credits remaining path"),
                                    text: $httpUsageCreditsRemainingPath
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.used", value: "Used Path", comment: "Used path"),
                                    text: $httpUsageUsedPath
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.total", value: "Total Path", comment: "Total path"),
                                    text: $httpUsageTotalPath
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.cost_today", value: "Today Cost Path", comment: "Today cost path"),
                                    text: $httpUsageCostTodayPath
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.cost_30d", value: "30D Cost Path", comment: "30D cost path"),
                                    text: $httpUsageCostLast30DaysPath
                                )
                                TextField(
                                    NSLocalizedString("codex.accounts.http_usage.mapping.error", value: "Error Message Path", comment: "Error message path"),
                                    text: $httpUsageErrorMessagePath
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
            if httpUsageEnabled {
                isHTTPUsageExpanded = true
            }
        }
    }
}
