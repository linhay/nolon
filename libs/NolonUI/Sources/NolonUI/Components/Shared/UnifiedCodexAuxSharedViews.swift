import Foundation
import NolonUIFoundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - CLITerminalMenuButton.swift"

public struct CLITerminalMenuButton: View {
    let title: String
    let systemImage: String
    let options: [CLITerminalMenuOption]
    let onSelect: (CLITerminalMenuOption) -> Void

    public struct Config {
        public var title: String
        public var systemImage: String
        public var options: [CLITerminalMenuOption]
        public var onSelect: (CLITerminalMenuOption) -> Void

        public init(
            title: String = NSLocalizedString(
                "provider.cli.open",
                value: "Open CLI",
                comment: "Open CLI"
            ),
            systemImage: String = "terminal",
            options: [CLITerminalMenuOption],
            onSelect: @escaping (CLITerminalMenuOption) -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.options = options
            self.onSelect = onSelect
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.options = config.options
        self.onSelect = config.onSelect
    }

    public init(
        title: String = NSLocalizedString(
            "provider.cli.open",
            value: "Open CLI",
            comment: "Open CLI"
        ),
        systemImage: String = "terminal",
        options: [CLITerminalMenuOption],
        onSelect: @escaping (CLITerminalMenuOption) -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                options: options,
                onSelect: onSelect
            )
        )
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.title) {
                    onSelect(option)
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .disabled(options.isEmpty)
    }
}

// MARK: - CodexConfigEditorSheetView.swift"

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

    public struct Config {
        public var title: String
        public var subtitle: String?
        public var primaryActionTitle: String
        public var errorMessage: String?
        public var testSuccessMessage: String?
        public var testErrorMessage: String?
        public var isRelayMode: Bool
        public var isTestingUsageQuery: Bool
        public var canRunTest: Bool
        public var canSaveDraft: Bool
        public var httpMethods: [String]
        public var onCancel: () -> Void
        public var onTest: () -> Void
        public var onSave: () -> Void

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
            self.onCancel = onCancel
            self.onTest = onTest
            self.onSave = onSave
        }
    }

    public init(
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
        config: Config
    ) {
        self.title = config.title
        self.subtitle = config.subtitle
        self.primaryActionTitle = config.primaryActionTitle
        self.errorMessage = config.errorMessage
        self.testSuccessMessage = config.testSuccessMessage
        self.testErrorMessage = config.testErrorMessage
        self.isRelayMode = config.isRelayMode
        self.isTestingUsageQuery = config.isTestingUsageQuery
        self.canRunTest = config.canRunTest
        self.canSaveDraft = config.canSaveDraft
        self.httpMethods = config.httpMethods
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
        self.onCancel = config.onCancel
        self.onTest = config.onTest
        self.onSave = config.onSave
    }
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
        self.init(
            selectedHTTPMethod: selectedHTTPMethod,
            name: name,
            apiKey: apiKey,
            baseURL: baseURL,
            modelProvider: modelProvider,
            queryParamsText: queryParamsText,
            headersText: headersText,
            httpUsageEnabled: httpUsageEnabled,
            httpUsageURL: httpUsageURL,
            httpUsageTimeoutSeconds: httpUsageTimeoutSeconds,
            httpUsageHeadersText: httpUsageHeadersText,
            httpUsageBody: httpUsageBody,
            httpUsageOverrideBaseURL: httpUsageOverrideBaseURL,
            httpUsageOverrideAPIKey: httpUsageOverrideAPIKey,
            httpUsageOverrideAccessToken: httpUsageOverrideAccessToken,
            httpUsageOverrideUserID: httpUsageOverrideUserID,
            httpUsagePlanPath: httpUsagePlanPath,
            httpUsageCreditsRemainingPath: httpUsageCreditsRemainingPath,
            httpUsageUsedPath: httpUsageUsedPath,
            httpUsageTotalPath: httpUsageTotalPath,
            httpUsageCostTodayPath: httpUsageCostTodayPath,
            httpUsageCostLast30DaysPath: httpUsageCostLast30DaysPath,
            httpUsageErrorMessagePath: httpUsageErrorMessagePath,
            config: Config(
                title: title,
                subtitle: subtitle,
                primaryActionTitle: primaryActionTitle,
                errorMessage: errorMessage,
                testSuccessMessage: testSuccessMessage,
                testErrorMessage: testErrorMessage,
                isRelayMode: isRelayMode,
                isTestingUsageQuery: isTestingUsageQuery,
                canRunTest: canRunTest,
                canSaveDraft: canSaveDraft,
                httpMethods: httpMethods,
                onCancel: onCancel,
                onTest: onTest,
                onSave: onSave
            )
        )
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

// MARK: - CodexImportSheetComponents.swift"

public struct CodexImportErrorBannerView: View {
    let message: String

    public struct Config {
        public var message: String

        public init(message: String) {
            self.message = message
        }
    }

    public init(config: Config) {
        self.message = config.message
    }

    public init(message: String) {
        self.init(config: Config(message: message))
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Status.error)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(DesignSystem.Colors.Status.error.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .strokeBorder(DesignSystem.Colors.Status.error.opacity(0.25), lineWidth: 1)
        }
    }
}

public struct CodexImportCandidateRowView: View {
    let data: CodexImportCandidateRowData
    let onSetSelected: @Sendable (Bool) -> Void
    let onRetry: @Sendable () -> Void
    let onRemove: @Sendable () -> Void

    public struct Config {
        public var data: CodexImportCandidateRowData
        public var onSetSelected: @Sendable (Bool) -> Void
        public var onRetry: @Sendable () -> Void
        public var onRemove: @Sendable () -> Void

        public init(
            data: CodexImportCandidateRowData,
            onSetSelected: @escaping @Sendable (Bool) -> Void,
            onRetry: @escaping @Sendable () -> Void,
            onRemove: @escaping @Sendable () -> Void
        ) {
            self.data = data
            self.onSetSelected = onSetSelected
            self.onRetry = onRetry
            self.onRemove = onRemove
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onSetSelected = config.onSetSelected
        self.onRetry = config.onRetry
        self.onRemove = config.onRemove
    }

    public init(
        data: CodexImportCandidateRowData,
        onSetSelected: @escaping @Sendable (Bool) -> Void,
        onRetry: @escaping @Sendable () -> Void,
        onRemove: @escaping @Sendable () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onSetSelected: onSetSelected,
                onRetry: onRetry,
                onRemove: onRemove
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { data.isSelected },
                        set: onSetSelected
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(data.isSelectionDisabled)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(data.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(data.isValid ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                    if let email = data.email, !email.isEmpty {
                        Text(email)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        Text(data.sourceFileName)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    } else {
                        Text(data.sourceFileName)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge

                    HStack(spacing: 8) {
                        if data.canRetry {
                            Button(NSLocalizedString("codex.import.sheet.retry_single", value: "重试", comment: "Retry single import test")) {
                                onRetry()
                            }
                            .disabled(data.isRetryDisabled)
                            .buttonStyle(.link)
                        }

                        if data.canRemove {
                            Button(NSLocalizedString("codex.import.sheet.remove", value: "移除", comment: "Remove import candidate")) {
                                onRemove()
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }

            if let summary = data.testSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(data.statusBadge.tone == .error ? DesignSystem.Colors.Status.error : DesignSystem.Colors.Text.secondary)
                    .padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(data.isValid ? DesignSystem.Colors.Background.elevated.opacity(0.6) : DesignSystem.Colors.Background.elevated.opacity(0.25))
        }
        .opacity(data.isValid ? 1 : 0.72)
    }

    private var statusBadge: some View {
        Text(data.statusBadge.text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch data.statusBadge.tone {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .info:
            return DesignSystem.Colors.primary
        case .success:
            return DesignSystem.Colors.Status.success
        case .error:
            return DesignSystem.Colors.Status.error
        }
    }
}

public struct CodexImportSectionCardView<Content: View>: View {
    let data: CodexImportSectionCardData
    let onSelectAction: () -> Void
    let content: () -> Content

    public struct Config {
        public var data: CodexImportSectionCardData
        public var onSelectAction: () -> Void
        public var content: () -> Content

        public init(
            data: CodexImportSectionCardData,
            onSelectAction: @escaping () -> Void,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.data = data
            self.onSelectAction = onSelectAction
            self.content = content
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onSelectAction = config.onSelectAction
        self.content = config.content
    }

    public init(
        data: CodexImportSectionCardData,
        onSelectAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                data: data,
                onSelectAction: onSelectAction,
                content: content
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(.headline)
                    Text(String(
                        format: NSLocalizedString("codex.import.sheet.group.count", value: "%d / %d 已选", comment: "Selected count in import group"),
                        data.selectedItemCount,
                        data.selectableItemCount
                    ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Spacer()

                Button(data.selectActionTitle) {
                    onSelectAction()
                }
                .disabled(data.isSelectActionDisabled)
                .font(.caption)
                .buttonStyle(.link)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            VStack(spacing: 4) {
                content()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(DesignSystem.Colors.Component.border.opacity(0.45), lineWidth: 1)
        }
    }
}

public struct CodexImportDropZoneView: View {
    let data: CodexImportDropZoneData
    @Binding var isTargeted: Bool
    let onPickFiles: () -> Void
    let onPaste: () -> Void
    let onDroppedURLs: ([URL]) -> Void

    public struct Config {
        public var data: CodexImportDropZoneData
        public var isTargeted: Binding<Bool>
        public var onPickFiles: () -> Void
        public var onPaste: () -> Void
        public var onDroppedURLs: ([URL]) -> Void

        public init(
            data: CodexImportDropZoneData,
            isTargeted: Binding<Bool>,
            onPickFiles: @escaping () -> Void,
            onPaste: @escaping () -> Void,
            onDroppedURLs: @escaping ([URL]) -> Void
        ) {
            self.data = data
            self.isTargeted = isTargeted
            self.onPickFiles = onPickFiles
            self.onPaste = onPaste
            self.onDroppedURLs = onDroppedURLs
        }
    }

    public init(config: Config) {
        self.data = config.data
        self._isTargeted = config.isTargeted
        self.onPickFiles = config.onPickFiles
        self.onPaste = config.onPaste
        self.onDroppedURLs = config.onDroppedURLs
    }

    public init(
        data: CodexImportDropZoneData,
        isTargeted: Binding<Bool>,
        onPickFiles: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onDroppedURLs: @escaping ([URL]) -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                isTargeted: isTargeted,
                onPickFiles: onPickFiles,
                onPaste: onPaste,
                onDroppedURLs: onDroppedURLs
            )
        )
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.primary)
            Text(data.title)
                .font(.headline)
            Text(data.subtitle)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            HStack(spacing: 10) {
                Button(data.pickFilesTitle) {
                    onPickFiles()
                }
                .buttonStyle(.borderedProminent)
                Button(data.pasteTitle) {
                    onPaste()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: data.minHeight)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(isTargeted ? DesignSystem.Colors.primary.opacity(0.12) : DesignSystem.Colors.Background.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(
                    isTargeted ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.7),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            resolveDroppedURLs(from: providers)
        }
    }

    private func resolveDroppedURLs(from providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        let accumulator = URLAccumulator()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let resolvedURL: URL? = {
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    }
                    if let url = item as? URL {
                        return url
                    }
                    if let string = item as? String {
                        return URL(string: string)
                    }
                    return nil
                }()
                guard let resolvedURL else { return }
                accumulator.append(resolvedURL)
            }
        }

        group.notify(queue: .main) {
            let urls = accumulator.snapshot()
            guard !urls.isEmpty else { return }
            onDroppedURLs(urls)
        }
        return true
    }
}

public struct CodexImportToolbarView: View {
    let data: CodexImportToolbarData
    @Binding var searchText: String
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onExportZip: () -> Void
    let onExportSub2api: () -> Void
    let onPaste: () -> Void
    let onRetryAll: () -> Void

    public struct Config {
        public var data: CodexImportToolbarData
        public var searchText: Binding<String>
        public var onSelectAll: () -> Void
        public var onDeselectAll: () -> Void
        public var onExportZip: () -> Void
        public var onExportSub2api: () -> Void
        public var onPaste: () -> Void
        public var onRetryAll: () -> Void

        public init(
            data: CodexImportToolbarData,
            searchText: Binding<String>,
            onSelectAll: @escaping () -> Void,
            onDeselectAll: @escaping () -> Void,
            onExportZip: @escaping () -> Void,
            onExportSub2api: @escaping () -> Void,
            onPaste: @escaping () -> Void,
            onRetryAll: @escaping () -> Void
        ) {
            self.data = data
            self.searchText = searchText
            self.onSelectAll = onSelectAll
            self.onDeselectAll = onDeselectAll
            self.onExportZip = onExportZip
            self.onExportSub2api = onExportSub2api
            self.onPaste = onPaste
            self.onRetryAll = onRetryAll
        }
    }

    public init(config: Config) {
        self.data = config.data
        self._searchText = config.searchText
        self.onSelectAll = config.onSelectAll
        self.onDeselectAll = config.onDeselectAll
        self.onExportZip = config.onExportZip
        self.onExportSub2api = config.onExportSub2api
        self.onPaste = config.onPaste
        self.onRetryAll = config.onRetryAll
    }

    public init(
        data: CodexImportToolbarData,
        searchText: Binding<String>,
        onSelectAll: @escaping () -> Void,
        onDeselectAll: @escaping () -> Void,
        onExportZip: @escaping () -> Void,
        onExportSub2api: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onRetryAll: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                searchText: searchText,
                onSelectAll: onSelectAll,
                onDeselectAll: onDeselectAll,
                onExportZip: onExportZip,
                onExportSub2api: onExportSub2api,
                onPaste: onPaste,
                onRetryAll: onRetryAll
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.selectedCountText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Text(data.sourceGroupCountText)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Spacer()

                SearchField(
                    config: .init(
                        placeholder: data.searchPlaceholder,
                        text: $searchText,
                        width: 260
                    )
                )
            }

            HStack(spacing: 10) {
                Spacer()

                Button(data.selectAllTitle) {
                    onSelectAll()
                }
                .disabled(data.isSelectAllDisabled)

                Button(data.deselectAllTitle) {
                    onDeselectAll()
                }
                .disabled(data.isDeselectAllDisabled)

                Button(data.exportZipTitle) {
                    onExportZip()
                }
                .disabled(data.isExportZipDisabled)

                Button(data.exportSub2apiTitle) {
                    onExportSub2api()
                }
                .disabled(data.isExportSub2apiDisabled)

                Button(data.pasteTitle) {
                    onPaste()
                }

                Button(data.retryAllTitle) {
                    onRetryAll()
                }
                .disabled(data.isRetryAllDisabled)
            }
        }
    }
}

public struct CodexImportCandidateListContainerView<Content: View>: View {
    let data: CodexImportCandidateListContainerData
    let content: () -> Content

    public struct Config {
        public var data: CodexImportCandidateListContainerData
        public var content: () -> Content

        public init(
            data: CodexImportCandidateListContainerData,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.data = data
            self.content = content
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.content = config.content
    }

    public init(
        data: CodexImportCandidateListContainerData,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(config: Config(data: data, content: content))
    }

    public var body: some View {
        Group {
            if !data.hasItems {
                if data.hasSearchText {
                    ContentUnavailableView(
                        data.emptySearchTitle,
                        systemImage: "magnifyingglass",
                        description: Text(data.emptySearchSubtitle)
                    )
                } else {
                    ContentUnavailableView(
                        data.emptyTitle,
                        systemImage: "tray",
                        description: Text(data.emptySubtitle)
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        content()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

public struct CodexImportSheetScaffold<DropZone: View, Toolbar: View, CandidateList: View>: View {
    let data: CodexImportSheetScaffoldData
    let globalErrorMessage: String?
    let onCancel: () -> Void
    let onImport: () -> Void
    let dropZone: () -> DropZone
    let toolbar: () -> Toolbar
    let candidateList: () -> CandidateList

    public struct Config {
        public var data: CodexImportSheetScaffoldData
        public var globalErrorMessage: String?
        public var onCancel: () -> Void
        public var onImport: () -> Void
        public var dropZone: () -> DropZone
        public var toolbar: () -> Toolbar
        public var candidateList: () -> CandidateList

        public init(
            data: CodexImportSheetScaffoldData,
            globalErrorMessage: String?,
            onCancel: @escaping () -> Void,
            onImport: @escaping () -> Void,
            @ViewBuilder dropZone: @escaping () -> DropZone,
            @ViewBuilder toolbar: @escaping () -> Toolbar,
            @ViewBuilder candidateList: @escaping () -> CandidateList
        ) {
            self.data = data
            self.globalErrorMessage = globalErrorMessage
            self.onCancel = onCancel
            self.onImport = onImport
            self.dropZone = dropZone
            self.toolbar = toolbar
            self.candidateList = candidateList
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.globalErrorMessage = config.globalErrorMessage
        self.onCancel = config.onCancel
        self.onImport = config.onImport
        self.dropZone = config.dropZone
        self.toolbar = config.toolbar
        self.candidateList = config.candidateList
    }

    public init(
        data: CodexImportSheetScaffoldData,
        globalErrorMessage: String?,
        onCancel: @escaping () -> Void,
        onImport: @escaping () -> Void,
        @ViewBuilder dropZone: @escaping () -> DropZone,
        @ViewBuilder toolbar: @escaping () -> Toolbar,
        @ViewBuilder candidateList: @escaping () -> CandidateList
    ) {
        self.init(
            config: Config(
                data: data,
                globalErrorMessage: globalErrorMessage,
                onCancel: onCancel,
                onImport: onImport,
                dropZone: dropZone,
                toolbar: toolbar,
                candidateList: candidateList
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.title3.weight(.semibold))
                Text(data.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            dropZone()

            if let globalErrorMessage, !globalErrorMessage.isEmpty {
                CodexImportErrorBannerView(message: globalErrorMessage)
            }

            if data.hasAnyCandidates {
                toolbar()
                candidateList()
            }

            HStack(alignment: .center, spacing: 12) {
                Button(data.cancelTitle) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                if data.isBusy {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(data.isRunningValidation ? data.validatingProgressText : data.testingProgressText)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                Spacer()
                Button(data.importButtonTitle) {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!data.canImport || data.isRunningValidation)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: data.minWidth, minHeight: data.minHeight)
    }
}

private final class URLAccumulator: @unchecked Sendable {
    private var urls: [URL] = []
    private let lock = NSLock()

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    func snapshot() -> [URL] {
        lock.lock()
        let current = urls
        lock.unlock()
        return current
    }
}

// MARK: - CodexPathStatusBarView.swift"

public struct CodexPathStatusBarView: View {
    let data: CodexPathStatusBarData
    let onConfigure: () -> Void
    let onCheck: () -> Void

    public struct Config {
        public var data: CodexPathStatusBarData
        public var onConfigure: () -> Void
        public var onCheck: () -> Void

        public init(
            data: CodexPathStatusBarData,
            onConfigure: @escaping () -> Void,
            onCheck: @escaping () -> Void
        ) {
            self.data = data
            self.onConfigure = onConfigure
            self.onCheck = onCheck
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onConfigure = config.onConfigure
        self.onCheck = config.onCheck
    }

    public init(
        data: CodexPathStatusBarData,
        onConfigure: @escaping () -> Void,
        onCheck: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onConfigure: onConfigure,
                onCheck: onCheck
            )
        )
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.title)
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                HStack(spacing: 8) {
                    if data.isCheckingPath {
                        ProgressView().controlSize(.small)
                    }
                    if let statusText = data.statusText, !statusText.isEmpty {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(data.configureTitle) {
                onConfigure()
            }
            .dsPrimaryButton()
            .disabled(data.isConfiguringPath || data.isCheckingPath)

            Button(data.checkTitle) {
                onCheck()
            }
            .dsSecondaryButton()
            .disabled(data.isConfiguringPath || data.isCheckingPath)
        }
    }
}

// MARK: - CodexXcodeFolderLinkCardView.swift"

public struct CodexXcodeFolderLinkCardView: View {
    let data: CodexXcodeFolderLinkCardData
    let onToggleLink: (Bool) -> Void
    let onShowInFinder: () -> Void

    public struct Config {
        public var data: CodexXcodeFolderLinkCardData
        public var onToggleLink: (Bool) -> Void
        public var onShowInFinder: () -> Void

        public init(
            data: CodexXcodeFolderLinkCardData,
            onToggleLink: @escaping (Bool) -> Void,
            onShowInFinder: @escaping () -> Void
        ) {
            self.data = data
            self.onToggleLink = onToggleLink
            self.onShowInFinder = onShowInFinder
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onToggleLink = config.onToggleLink
        self.onShowInFinder = config.onShowInFinder
    }

    public init(
        data: CodexXcodeFolderLinkCardData,
        onToggleLink: @escaping (Bool) -> Void,
        onShowInFinder: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onToggleLink: onToggleLink,
                onShowInFinder: onShowInFinder
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(data.folderTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text(data.statusText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(
                                data.isLinked
                                ? DesignSystem.Colors.Status.success
                                : DesignSystem.Colors.Text.secondary
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (data.isLinked
                                    ? DesignSystem.Colors.Status.success
                                    : DesignSystem.Colors.Component.controlFillSubtle).opacity(0.12),
                                in: Capsule()
                            )
                    }
                }

                Spacer(minLength: 0)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { data.isLinked },
                        set: { onToggleLink($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(data.isApplying)
            }

            VStack(alignment: .leading, spacing: 6) {
                CodexAdvancedPathInfoRowView(
                    data: CodexAdvancedPathInfoRowData(
                        iconName: "link",
                        text: data.sourcePathText
                    )
                )

                CodexAdvancedPathInfoRowView(
                    data: CodexAdvancedPathInfoRowData(
                        iconName: "folder",
                        text: data.targetPathText
                    )
                )
            }

            if data.hasVisibleEntries {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(data.conflictHintText)
                        .font(.caption)
                }
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            }

            HStack {
                Spacer(minLength: 0)
                Menu {
                    Button(data.showInFinderTitle) {
                        onShowInFinder()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .frame(width: 28, height: 24)
                        .background(
                            DesignSystem.Colors.Component.controlFillSubtle.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.55),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
        )
    }
}

// MARK: - CodexXcodeFolderLinksSectionView.swift"

public struct CodexXcodeFolderLinksSectionView: View {
    let descriptionText: String
    let cards: [CodexXcodeFolderLinkCardData]
    let onToggleLink: (String, Bool) -> Void
    let onShowInFinder: (String) -> Void

    public struct Config {
        public var descriptionText: String
        public var cards: [CodexXcodeFolderLinkCardData]
        public var onToggleLink: (String, Bool) -> Void
        public var onShowInFinder: (String) -> Void

        public init(
            descriptionText: String,
            cards: [CodexXcodeFolderLinkCardData],
            onToggleLink: @escaping (String, Bool) -> Void,
            onShowInFinder: @escaping (String) -> Void
        ) {
            self.descriptionText = descriptionText
            self.cards = cards
            self.onToggleLink = onToggleLink
            self.onShowInFinder = onShowInFinder
        }
    }

    public init(config: Config) {
        self.descriptionText = config.descriptionText
        self.cards = config.cards
        self.onToggleLink = config.onToggleLink
        self.onShowInFinder = config.onShowInFinder
    }

    public init(
        descriptionText: String,
        cards: [CodexXcodeFolderLinkCardData],
        onToggleLink: @escaping (String, Bool) -> Void,
        onShowInFinder: @escaping (String) -> Void
    ) {
        self.init(
            config: Config(
                descriptionText: descriptionText,
                cards: cards,
                onToggleLink: onToggleLink,
                onShowInFinder: onShowInFinder
            )
        )
    }

    public var body: some View {
        CodexAdvancedSectionCardView {
            Text(descriptionText)
                .font(.callout)
                .dsSecondaryText(font: .callout)
                .padding(.horizontal, 2)

            ForEach(cards) { card in
                CodexXcodeFolderLinkCardView(
                    data: card,
                    onToggleLink: { enabled in
                        onToggleLink(card.id, enabled)
                    },
                    onShowInFinder: {
                        onShowInFinder(card.id)
                    }
                )
            }
        }
    }
}
