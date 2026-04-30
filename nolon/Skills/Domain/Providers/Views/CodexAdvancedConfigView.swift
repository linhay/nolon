import AppKit
import CodexProvider
import NolonResourceKit
import ProviderCatalog
import SwiftUI
import UniformTypeIdentifiers
import NolonUI
import NolonUIFoundation

struct CodexAdvancedConfigView: View {
    private struct RoleEditorTarget: Identifiable {
        enum Mode: Equatable {
            case existing(UUID)
            case creating
        }

        let mode: Mode

        var id: String {
            switch mode {
            case .existing(let roleID):
                return "existing-\(roleID.uuidString)"
            case .creating:
                return "creating"
            }
        }
    }

    private enum FilePickerTarget: String, Identifiable {
        case experimentalCompactPromptFile
        case roleConfigFile

        var id: String { rawValue }
    }

    private enum LargeTextEditorTarget: String, Identifiable {
        case compactPrompt

        var id: String { rawValue }
    }

    let provider: Provider
    let markerBaseItems: [PageMarkerItem]
    @State private var viewModel: CodexAdvancedConfigViewModel
    @State private var isEditingRawConfig = false
    @State private var roleEditorTarget: RoleEditorTarget?
    @State private var pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
    @State private var featureSearchText: String = ""
    @State private var filePickerTarget: FilePickerTarget?
    @State private var textEditorTarget: LargeTextEditorTarget?

    init(provider: Provider, markerBaseItems: [PageMarkerItem] = []) {
        self.provider = provider
        self.markerBaseItems = markerBaseItems
        self._viewModel = State(initialValue: CodexAdvancedConfigViewModel(provider: provider))
    }

    var body: some View {
        NolonUI.ProviderTabScrollScaffold {
            if CodexiCloudSyncCloudKitRuntimeSupport.isProductEnabled {
                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString("codex.advanced.cloud_sync.title", value: "Cloud Sync", comment: "Cloud sync section title")
                )
                CodexCloudSyncSettingsView(provider: provider)
            }

            NolonUI.CodexAdvancedSectionHeaderView(
                title: NSLocalizedString("codex.advanced.config.options.title", value: "Common Options", comment: "Common options")
            )
            commonOptionsSection

            NolonUI.CodexAdvancedSectionHeaderView(
                title: NSLocalizedString("codex.advanced.config.features.title", value: "Feature Flags", comment: "Feature flags")
            )
            featureFlagsSection

            NolonUI.CodexAdvancedSectionHeaderView(
                title: NSLocalizedString("codex.advanced.config.runtime.title", value: "History & Compaction", comment: "History and compaction")
            )
            runtimeControlsSection

            NolonUI.CodexAdvancedSectionHeaderView(
                title: NSLocalizedString("codex.advanced.config.multi_agent.title", value: "Multi-Agent Roles", comment: "Multi-agent roles")
            )
            multiAgentSection

            if viewModel.isCodexXcodeProvider {
                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString("codex.advanced.xcode_links.title", value: "Xcode Folder Links", comment: "Xcode folder links section title")
                )
                xcodeFolderLinksSection
            }
        }
        .textSelection(.enabled)
        .task(id: provider.id) {
            viewModel.updateProvider(provider)
            await viewModel.load()
        }
        .sheet(isPresented: $isEditingRawConfig) {
            if let configURL = viewModel.configFileURL {
                CodexConfigEditorView(configURL: configURL) {
                    viewModel.loadConfigDraft()
                }
            } else {
                EmptyView()
            }
        }
        .sheet(item: $roleEditorTarget) { target in
            roleEditorSheet(for: target)
        }
        .sheet(item: $textEditorTarget) { target in
            largeTextEditorSheet(for: target)
        }
        .fileImporter(
            isPresented: Binding(
                get: { filePickerTarget != nil },
                set: { if !$0 { filePickerTarget = nil } }
            ),
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .messageAlert(
            title: NSLocalizedString("codex.binary.error.title", value: "Binary Error", comment: "Binary error"),
            message: $viewModel.errorMessage
        )
        .messageAlert(
            title: NSLocalizedString("codex.advanced.config.error.title", value: "Config Error", comment: "Config error"),
            message: $viewModel.configErrorMessage
        )
        .triActionAlert(
            data: linkConflictAlertData,
            isPresented: Binding(
                get: { viewModel.pendingConflict != nil },
                set: { if !$0 { viewModel.pendingConflict = nil } }
            ),
            onDestructive: {
                Task { await viewModel.confirmPendingConflict() }
            },
            onSecondary: {
                viewModel.openFinderForPendingConflict()
            },
            onCancel: {}
        )
    }

    private var commonOptionsSection: some View {
        NolonUI.CodexAdvancedSectionCardView {
            runtimeOverviewSection

            if !viewModel.isCodexXcodeProvider, viewModel.pathStatus?.configured != true {
                Divider().padding(.vertical, 6)
                NolonUI.CodexPathStatusBarView(
                    data: pathStatusBarData,
                    onConfigure: {
                        Task { await viewModel.installPath() }
                    },
                    onCheck: {
                        Task { await viewModel.refreshPathStatus() }
                    }
                )
            }

            Divider().padding(.vertical, 4)

            availableModelsSection

            Divider()

            commonOptionPickerRow(
                title: "approval_policy",
                selection: $viewModel.approvalPolicyDraft,
                description: NSLocalizedString(
                    "codex.config.description.approval_policy",
                    value: "Controls when Codex asks for permission before running sensitive commands.",
                    comment: "Description for approval_policy"
                ),
                options: mergedOptions(
                    current: viewModel.approvalPolicyDraft,
                    defaults: ["untrusted", "on-request", "never"]
                ),
                quickOptions: ["untrusted", "on-request", "never"]
            )
            commonOptionPickerRow(
                title: "sandbox_mode",
                selection: $viewModel.sandboxModeDraft,
                description: localizedConfigDescription(
                    key: "sandbox_mode",
                    fallback: "Controls the filesystem and network sandbox level available to Codex."
                ),
                options: mergedOptions(
                    current: viewModel.sandboxModeDraft,
                    defaults: ["read-only", "workspace-write", "danger-full-access"]
                ),
                quickOptions: ["read-only", "workspace-write", "danger-full-access"]
            )
            commonOptionPickerRow(
                title: "web_search",
                selection: $viewModel.webSearchDraft,
                description: localizedConfigDescription(
                    key: "web_search",
                    fallback: "Controls whether Codex uses cached or live web results, or disables web search entirely."
                ),
                options: mergedOptions(
                    current: viewModel.webSearchDraft,
                    defaults: ["cached", "live", "disabled"]
                ),
                quickOptions: ["cached", "live", "disabled"]
            )
            commonOptionRow(
                title: "model_provider",
                text: $viewModel.modelProviderDraft,
                description: localizedConfigDescription(
                    key: "model_provider",
                    fallback: "Overrides which provider preset supplies model defaults and credentials."
                )
            )
            commonOptionRow(
                title: "profile",
                text: $viewModel.profileDraft,
                description: localizedConfigDescription(
                    key: "profile",
                    fallback: "Selects the named profile block to merge into the active configuration."
                )
            )
            commonOptionPickerRow(
                title: "personality",
                selection: $viewModel.personalityDraft,
                description: localizedConfigDescription(
                    key: "personality",
                    fallback: "Adjusts the default assistant tone for Codex sessions."
                ),
                options: mergedOptions(
                    current: viewModel.personalityDraft,
                    defaults: ["none", "friendly", "pragmatic"]
                ),
                quickOptions: ["none", "friendly", "pragmatic"]
            )
            commonOptionPickerRow(
                title: "model_reasoning_summary",
                selection: $viewModel.reasoningSummaryDraft,
                description: localizedConfigDescription(
                    key: "model_reasoning_summary",
                    fallback: "Controls whether Codex shows a reasoning summary in responses."
                ),
                options: mergedOptions(
                    current: viewModel.reasoningSummaryDraft,
                    defaults: ["none", "auto", "concise", "detailed"]
                ),
                quickOptions: ["none", "auto", "concise", "detailed"]
            )
            commonOptionPickerRow(
                title: "model_verbosity",
                selection: $viewModel.verbosityDraft,
                description: NSLocalizedString(
                    "codex.config.description.model_verbosity",
                    value: "Sets response detail level. Low is concise, high is more detailed.",
                    comment: "Description for model_verbosity"
                ),
                options: mergedOptions(
                    current: viewModel.verbosityDraft,
                    defaults: ["low", "medium", "high"]
                ),
                quickOptions: ["low", "medium", "high"]
            )

            Divider()

            NolonUI.CodexAdvancedTrailingActionRowView(
                title: NSLocalizedString("codex.advanced.config.edit_raw", value: "Edit Raw TOML", comment: "Edit raw TOML"),
                onTap: {
                    isEditingRawConfig = true
                }
            )

            docsRow(commonOptionDocs)
        }
        .debugCardLocator(sectionMarkerItems("Common Options"))
    }

    private var linkConflictAlertData: TriActionAlertData {
        TriActionAlertData(
            title: NSLocalizedString("codex.advanced.link.conflict.title", value: "Directory Contains Files", comment: "Conflict title"),
            message: NSLocalizedString(
                "codex.advanced.link.conflict.message",
                value: "The target folder already contains files. Confirm to delete its visible contents and replace it with a symlink.",
                comment: "Conflict message"
            ),
            destructiveTitle: NSLocalizedString("codex.advanced.link.confirm", value: "Confirm", comment: "Confirm action"),
            secondaryTitle: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
            cancelTitle: NSLocalizedString("action.cancel", comment: "Cancel")
        )
    }

    private var featureFlagsSection: some View {
        let knownKeys = Set(CodexAdvancedConfigViewModel.supportedFeatures.map(\.key))
        let extraFeatures = viewModel.featureValues.keys
            .filter { !knownKeys.contains($0) }
            .sorted()
            .map { key in
                CodexFeatureDefinition(
                    key: key,
                    maturity: NSLocalizedString("codex.features.maturity.unknown", value: "Unknown", comment: "Unknown feature maturity"),
                    description: NSLocalizedString(
                        "codex.features.description.unrecognized",
                        value: "Detected from config.toml but not in current built-in feature registry.",
                        comment: "Unrecognized feature description"
                    ),
                    source: NSLocalizedString(
                        "codex.features.source.config_unrecognized",
                        value: "config.toml (unrecognized key)",
                        comment: "Unrecognized feature source"
                    )
                )
            }
        let query = featureSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let renderedFeatures = (CodexAdvancedConfigViewModel.supportedFeatures + extraFeatures)
            .sorted { lhs, rhs in
                let lhsRank = featureSortRank(lhs.maturity)
                let rhsRank = featureSortRank(rhs.maturity)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.key < rhs.key
            }
            .filter { feature in
                guard !query.isEmpty else { return true }
                let values = [
                    feature.key,
                    feature.maturity,
                    localizedMaturityLabel(feature.maturity),
                    localizedFeatureDescription(feature),
                    feature.source
                ]
                return values.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        let renderedRows = renderedFeatures.map { feature in
            featureRowData(feature: feature, query: query)
        }

        return VStack(spacing: 10) {
            NolonUI.CodexAdvancedFeatureFlagsSectionView(
                searchText: $featureSearchText,
                rows: renderedRows,
                onToggle: { featureID, newValue in
                    viewModel.setFeature(featureID, enabled: newValue)
                    viewModel.scheduleStructuredSaveIfReady()
                }
            )
            docsRow([
                .init(id: "config-basics-features", title: "Config Basics", url: CodexAdvancedDocs.configBasics),
                .init(id: "config-reference-features", title: "Config Reference", url: CodexAdvancedDocs.configReference)
            ])
        }
        .debugCardLocator(sectionMarkerItems("Feature Flags"))
    }

    private var runtimeControlsSection: some View {
        NolonUI.CodexAdvancedSectionCardView {
            commonOptionPickerRow(
                title: "history.persistence",
                selection: $viewModel.historyPersistenceDraft,
                description: localizedConfigDescription(
                    key: "history.persistence",
                    fallback: "Control whether Codex saves transcripts to history.jsonl."
                ),
                options: mergedOptions(
                    current: viewModel.historyPersistenceDraft,
                    defaults: ["save-all", "none"]
                ),
                quickOptions: ["save-all", "none"]
            )
            numericInputRow(
                label: "history.max_bytes",
                text: $viewModel.historyMaxBytesDraft,
                description: localizedConfigDescription(
                    key: "history.max_bytes",
                    fallback: "Sets the maximum size of the local history file before old entries are trimmed."
                ),
                presets: historyMaxBytesPresets
            )
            triStateBoolRow(
                title: "hide_agent_reasoning",
                description: localizedConfigDescription(
                    key: "hide_agent_reasoning",
                    fallback: "Suppress reasoning events in the TUI and codex exec output."
                ),
                value: $viewModel.hideAgentReasoningDraft
            )
            numericInputRow(
                label: "model_auto_compact_token_limit",
                text: $viewModel.modelAutoCompactTokenLimitDraft,
                description: localizedConfigDescription(
                    key: "model_auto_compact_token_limit",
                    fallback: "Automatically compacts conversation history after the token count crosses this threshold."
                ),
                presets: autoCompactTokenPresets
            )
            largeTextOptionRow(
                title: "compact_prompt",
                text: $viewModel.compactPromptDraft,
                description: localizedConfigDescription(
                    key: "compact_prompt",
                    fallback: "Inline override for the history compaction prompt."
                )
            )
            filePathOptionRow(
                title: "experimental_compact_prompt_file",
                text: $viewModel.experimentalCompactPromptFileDraft,
                description: localizedConfigDescription(
                    key: "experimental_compact_prompt_file",
                    fallback: "Load the compaction prompt override from a file."
                ),
                pickerTarget: .experimentalCompactPromptFile
            )

            docsRow(runtimeDocs)
        }
        .debugCardLocator(sectionMarkerItems("History & Compaction"))
    }

    private func featureSortRank(_ maturity: String) -> Int {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") { return 0 }
        if normalized.contains("experimental") || normalized.contains("beta") { return 1 }
        return 2
    }

    private func localizedMaturityLabel(_ maturity: String) -> String {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") {
            return NSLocalizedString("codex.features.maturity.stable", value: "Stable", comment: "Stable maturity")
        }
        if normalized.contains("experimental") {
            return NSLocalizedString("codex.features.maturity.experimental", value: "Experimental", comment: "Experimental maturity")
        }
        if normalized.contains("beta") {
            return NSLocalizedString("codex.features.maturity.beta", value: "Beta", comment: "Beta maturity")
        }
        if normalized.contains("under_development") || normalized.contains("underdevelopment") {
            return NSLocalizedString("codex.features.maturity.under_development", value: "Under Development", comment: "Under development maturity")
        }
        if normalized.contains("deprecated") {
            return NSLocalizedString("codex.features.maturity.deprecated", value: "Deprecated", comment: "Deprecated maturity")
        }
        if normalized.contains("removed") {
            return NSLocalizedString("codex.features.maturity.removed", value: "Removed", comment: "Removed maturity")
        }
        return NSLocalizedString("codex.features.maturity.unknown", value: "Unknown", comment: "Unknown feature maturity")
    }

    private func localizedFeatureDescription(_ feature: CodexFeatureDefinition) -> String {
        let key = "codex.features.description.\(feature.key)"
        return NSLocalizedString(
            key,
            value: feature.description,
            comment: "Feature description"
        )
    }

    private func normalizedMaturityToken(_ maturity: String) -> String {
        maturity
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func sourceTag(for source: String) -> CodexFeatureSourceTag {
        let normalized = source.lowercased()

        // Priority: app server / cli list > docs > core > compatibility > config unknown
        if normalized.contains("app-server") {
            return .appServer
        }
        if normalized.contains("codex features list") {
            return .cliFeaturesList
        }
        if normalized.contains("codex docs") {
            return .codexDocs
        }
        if normalized.contains("codex-rs/core/src/features.rs") {
            return .coreFeatures
        }
        if normalized.contains("legacy") || normalized.contains("compatibility") {
            return .nolonCompatibility
        }
        if normalized.contains("unrecognized") || normalized.contains("unknown") || normalized.contains("config.toml") {
            return .configUnknown
        }
        return .nolonCompatibility
    }

    private func maturityChipTone(_ maturity: String) -> CodexFeatureChipTone {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") {
            return .success
        }
        if normalized.contains("experimental") || normalized.contains("beta") || normalized.contains("under_development") || normalized.contains("underdevelopment") {
            return .warning
        }
        if normalized.contains("deprecated") || normalized.contains("removed") {
            return .error
        }
        return .secondary
    }

    private func sourceChipTone(_ source: CodexFeatureSourceTag) -> CodexFeatureChipTone {
        switch source {
        case .appServer, .cliFeaturesList:
            return .success
        case .codexDocs:
            return .info
        case .coreFeatures:
            return .warning
        case .nolonCompatibility, .configUnknown:
            return .secondary
        }
    }

    private func featureRowData(feature: CodexFeatureDefinition, query: String) -> CodexAdvancedFeatureRowData {
        let source = sourceTag(for: feature.source)
        return CodexAdvancedFeatureRowData(
            id: feature.id,
            keyText: feature.key,
            descriptionText: localizedFeatureDescription(feature),
            maturityText: localizedMaturityLabel(feature.maturity),
            sourceText: source.localizedTitle,
            queryText: query,
            maturityTone: maturityChipTone(feature.maturity),
            sourceTone: sourceChipTone(source),
            isEnabled: viewModel.featureEnabled(feature.key)
        )
    }

    private var multiAgentSection: some View {
        NolonUI.CodexAdvancedSectionCardView {
            NolonUI.CodexAdvancedMultiAgentToggleRowView(
                data: multiAgentToggleRowData,
                onToggle: { newValue in
                    viewModel.setFeature("multi_agent", enabled: newValue)
                    viewModel.scheduleStructuredSaveIfReady()
                }
            )

            NolonUI.CodexAdvancedMultiAgentStatusRowView(
                data: multiAgentStatusRowData
            )

            numericInputRow(
                label: "agents.max_threads",
                text: $viewModel.agentsMaxThreadsDraft,
                presets: agentThreadPresets
            )
            numericInputRow(
                label: "agents.max_depth",
                text: $viewModel.agentsMaxDepthDraft,
                presets: agentDepthPresets
            )

            NolonUI.CodexAdvancedRoleListView(
                emptyText: NSLocalizedString(
                    "codex.advanced.config.multi_agent.empty",
                    value: "No roles configured yet. Click Add Role to create the first role.",
                    comment: "No multi-agent roles"
                ),
                roles: roleListRows,
                onEdit: { roleID in
                    guard let roleUUID = UUID(uuidString: roleID) else { return }
                    roleEditorTarget = RoleEditorTarget(mode: .existing(roleUUID))
                },
                onDelete: { roleID in
                    guard let roleUUID = UUID(uuidString: roleID) else { return }
                    viewModel.removeRoleDraft(roleUUID)
                    if case .existing(let editingID) = roleEditorTarget?.mode, editingID == roleUUID {
                        roleEditorTarget = nil
                    }
                }
            )

            NolonUI.CodexAdvancedRoleSectionFooterView(
                addTitle: NSLocalizedString(
                    "codex.advanced.config.multi_agent.add_role",
                    value: "Add Role",
                    comment: "Add role"
                ),
                saveTitle: NSLocalizedString("action.save", value: "Save", comment: "Save"),
                isSaveDisabled: viewModel.isSavingConfig
            ) {
                NolonUI.CodexAdvancedRoleAddMenuContentView(
                    addEmptyTitle: NSLocalizedString(
                        "codex.advanced.config.multi_agent.add_role.empty",
                        value: "Add Empty Role",
                        comment: "Add empty role"
                    ),
                    builtinItems: roleAddBuiltinItems,
                    onAddEmpty: {
                        pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
                        roleEditorTarget = RoleEditorTarget(mode: .creating)
                    },
                    onSelectBuiltin: { builtinRoleRawValue in
                        guard let builtinRole = CodexBuiltinAgentRole(rawValue: builtinRoleRawValue) else { return }
                        if viewModel.roleDrafts.contains(where: { $0.name == builtinRole.rawValue }) {
                            let roleID = viewModel.upsertBuiltinRole(builtinRole)
                            roleEditorTarget = RoleEditorTarget(mode: .existing(roleID))
                        } else {
                            pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeBuiltinRoleDraft(builtinRole)
                            roleEditorTarget = RoleEditorTarget(mode: .creating)
                        }
                    }
                )
            } onSave: {
                    Task { await viewModel.saveStructuredConfig() }
            }

            docsRow(multiAgentDocs)
        }
        .debugCardLocator(sectionMarkerItems("Multi-Agent Roles"))
    }

    @ViewBuilder
    private func roleEditorSheet(for target: RoleEditorTarget) -> some View {
        if let role = roleBinding(for: target) {
            NolonUI.CodexAdvancedEditorScaffold(
                config: .init(
                    title: role.wrappedValue.name.nonEmpty ?? NSLocalizedString(
                        "codex.advanced.config.multi_agent.unnamed_role",
                        value: "Unnamed Role",
                        comment: "Unnamed role"
                    )
                )
            ) {
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("name"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.role_name",
                            value: "role name",
                            comment: "Role name placeholder"
                        ),
                        text: role.name
                    )
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("description"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.description",
                            value: "description",
                            comment: "Role description placeholder"
                        ),
                        text: role.description
                    )
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("config_file"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.config_file",
                            value: "config file path",
                            comment: "Role config file placeholder"
                        ),
                        text: role.configFile
                    )
                    HStack {
                        Spacer()
                        if !role.wrappedValue.configFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                                role.wrappedValue.configFile = ""
                                viewModel.scheduleStructuredSaveIfReady()
                            }
                            .buttonStyle(.borderless)
                        }
                        Button(NSLocalizedString("codex.advanced.action.choose_file", value: "Choose File", comment: "Choose file")) {
                            filePickerTarget = .roleConfigFile
                        }
                        .buttonStyle(.borderless)
                    }
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("model"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.model",
                            value: "model",
                            comment: "Role model placeholder"
                        ),
                        text: role.model
                    )
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("model_reasoning_effort"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "model_reasoning_effort", value: "")
                        )] + ["minimal", "low", "medium", "high", "xhigh"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "model_reasoning_effort", value: $0)
                            )
                        },
                        selection: role.modelReasoningEffort,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "model_reasoning_effort", selection: role.modelReasoningEffort, options: ["minimal", "low", "medium", "high", "xhigh"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("model_reasoning_summary"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "model_reasoning_summary", value: "")
                        )] + ["auto", "concise", "detailed", "none"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "model_reasoning_summary", value: $0)
                            )
                        },
                        selection: role.modelReasoningSummary,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "model_reasoning_summary", selection: role.modelReasoningSummary, options: ["none", "auto", "concise", "detailed"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("model_verbosity"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "model_verbosity", value: "")
                        )] + ["low", "medium", "high"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "model_verbosity", value: $0)
                            )
                        },
                        selection: role.modelVerbosity,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "model_verbosity", selection: role.modelVerbosity, options: ["low", "medium", "high"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("sandbox_mode"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "sandbox_mode", value: "")
                        )] + ["read-only", "workspace-write", "danger-full-access"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "sandbox_mode", value: $0)
                            )
                        },
                        selection: role.sandboxMode,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "sandbox_mode", selection: role.sandboxMode, options: ["read-only", "workspace-write", "danger-full-access"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("approval_policy"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "approval_policy", value: "")
                        )] + ["untrusted", "on-request", "never"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "approval_policy", value: $0)
                            )
                        },
                        selection: role.approvalPolicy,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "approval_policy", selection: role.approvalPolicy, options: ["untrusted", "on-request", "never"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("personality"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "personality", value: "")
                        )] + ["none", "friendly", "pragmatic"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "personality", value: $0)
                            )
                        },
                        selection: role.personality,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "personality", selection: role.personality, options: ["none", "friendly", "pragmatic"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("web_search"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "web_search", value: "")
                        )] + ["cached", "live", "disabled"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "web_search", value: $0)
                            )
                        },
                        selection: role.webSearch,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "web_search", selection: role.webSearch, options: ["cached", "live", "disabled"])

                    Divider().padding(.top, 4)

                    NolonUI.CodexAdvancedEditorFooterView(
                        closeTitle: NSLocalizedString("generic.close", value: "Close", comment: "Close"),
                        saveTitle: NSLocalizedString("action.save", value: "Save", comment: "Save"),
                        isSaveDisabled: viewModel.isSavingConfig,
                        onClose: {
                            closeRoleEditor(target)
                        },
                        onSave: {
                            commitRoleEditorIfNeeded(target)
                            Task { await viewModel.saveStructuredConfig() }
                            closeRoleEditor(target)
                        }
                    )
            }
        } else {
            EmptyView()
        }
    }

    private func roleBinding(for target: RoleEditorTarget) -> Binding<CodexAgentRoleDraft>? {
        switch target.mode {
        case .creating:
            return Binding(
                get: { pendingNewRoleDraft },
                set: { pendingNewRoleDraft = $0 }
            )
        case .existing(let roleID):
            guard let index = viewModel.roleDrafts.firstIndex(where: { $0.id == roleID }) else {
                return nil
            }
            return $viewModel.roleDrafts[index]
        }
    }

    private func commitRoleEditorIfNeeded(_ target: RoleEditorTarget) {
        if case .creating = target.mode {
            _ = viewModel.addRoleDraft(pendingNewRoleDraft)
            pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
        }
    }

    private func closeRoleEditor(_ target: RoleEditorTarget) {
        if case .creating = target.mode {
            pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
        }
        roleEditorTarget = nil
    }

    private func commonOptionRow(title: String, text: Binding<String>, description: String? = nil) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            HStack(spacing: 8) {
                TextField(localizedConfigLabel(title), text: text)
                    .onChange(of: text.wrappedValue) { _, _ in
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

                if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                        text.wrappedValue = ""
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func triStateBoolRow(title: String, description: String? = nil, value: Binding<Bool?>) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            Picker(
                "",
                selection: Binding<String>(
                    get: {
                        switch value.wrappedValue {
                        case true: return "true"
                        case false: return "false"
                        case nil: return ""
                        }
                    },
                    set: { newValue in
                        switch newValue {
                        case "true": value.wrappedValue = true
                        case "false": value.wrappedValue = false
                        default: value.wrappedValue = nil
                        }
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                )
            ) {
                Text(NSLocalizedString("codex.config.option.unset", value: "Unset", comment: "Unset option")).tag("")
                Text(NSLocalizedString("codex.config.option.boolean.false", value: "Off", comment: "Boolean off")).tag("false")
                Text(NSLocalizedString("codex.config.option.boolean.true", value: "On", comment: "Boolean on")).tag("true")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func filePathOptionRow(
        title: String,
        text: Binding<String>,
        description: String? = nil,
        pickerTarget: FilePickerTarget
    ) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            HStack(spacing: 8) {
                TextField(localizedConfigLabel(title), text: text)
                    .onChange(of: text.wrappedValue) { _, _ in
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

                Button(NSLocalizedString("codex.advanced.action.choose_file", value: "Choose File", comment: "Choose file")) {
                    filePickerTarget = pickerTarget
                }
                .buttonStyle(.borderless)

                if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(NSLocalizedString("action.show_in_finder", value: "Show in Finder", comment: "Show in Finder")) {
                        NSWorkspace.shared.selectFile(text.wrappedValue, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.borderless)

                    Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                        text.wrappedValue = ""
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func largeTextOptionRow(title: String, text: Binding<String>, description: String? = nil) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            HStack(spacing: 8) {
                Text(
                    text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? NSLocalizedString("codex.advanced.value.empty", value: "Not configured", comment: "Not configured")
                        : text.wrappedValue
                )
                .font(.caption)
                .foregroundStyle(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Button(NSLocalizedString("codex.advanced.action.edit_text", value: "Edit", comment: "Edit text")) {
                    textEditorTarget = .compactPrompt
                }
                .buttonStyle(.borderless)

                if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                        text.wrappedValue = ""
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func numericInputRow(
        label: String,
        text: Binding<String>,
        description: String? = nil,
        presets: [String] = []
    ) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(label),
            description: description
        ) {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("", text: text)
                        .onChange(of: text.wrappedValue) { _, newValue in
                            let filtered = newValue.filter(\.isNumber)
                            if filtered != newValue {
                                text.wrappedValue = filtered
                                return
                            }
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 180)

                    if !text.wrappedValue.isEmpty {
                        Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                            text.wrappedValue = ""
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if !presets.isEmpty {
                    quickValueButtons(selection: text, options: presets)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(label))
    }

    private func commonOptionPickerRow(
        title: String,
        selection: Binding<String>,
        description: String? = nil,
        options: [String],
        quickOptions: [String] = []
    ) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            NolonUI.CodexAdvancedPickerRowView(
                label: localizedConfigLabel(title),
                description: description,
                options: [CodexAdvancedPickerOption(
                    id: "",
                    title: localizedOptionLabel(key: title, value: "")
                )] + options.map {
                    CodexAdvancedPickerOption(
                        id: $0,
                        title: localizedOptionLabel(key: title, value: $0)
                    )
                },
                selection: selection,
                onSelectionChanged: {
                    viewModel.scheduleStructuredSaveIfReady()
                }
            )

            if !quickOptions.isEmpty {
                quickOptionButtons(
                    key: title,
                    selection: selection,
                    options: quickOptions
                )
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    @ViewBuilder
    private func quickOptionButtons(key: String, selection: Binding<String>, options: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option
                    Button(localizedOptionLabel(key: key, value: option)) {
                        selection.wrappedValue = selection.wrappedValue == option ? "" : option
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func quickValueButtons(selection: Binding<String>, options: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option
                    Button(option) {
                        selection.wrappedValue = selection.wrappedValue == option ? "" : option
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var commonOptionDocs: [CodexConfigDocLink] {
        [
            .init(id: "config-basics", title: "Config Basics", url: CodexAdvancedDocs.configBasics),
            .init(id: "config-reference", title: "Config Reference", url: CodexAdvancedDocs.configReference),
            .init(id: "sandbox", title: "Sandboxing", url: CodexAdvancedDocs.sandboxing),
            .init(id: "approvals", title: "Approvals", url: CodexAdvancedDocs.approvals),
            .init(id: "models", title: "Models", url: CodexAdvancedDocs.models)
        ]
    }

    private var runtimeDocs: [CodexConfigDocLink] {
        [
            .init(id: "config-reference-runtime", title: "Config Reference", url: CodexAdvancedDocs.configReference),
            .init(id: "config-advanced-runtime", title: "Advanced Config", url: CodexAdvancedDocs.configAdvanced)
        ]
    }

    private var multiAgentDocs: [CodexConfigDocLink] {
        [
            .init(id: "subagents", title: "Subagents", url: CodexAdvancedDocs.subagents),
            .init(id: "config-reference-subagents", title: "Config Reference", url: CodexAdvancedDocs.configReference)
        ]
    }

    @ViewBuilder
    private func docsRow(_ links: [CodexConfigDocLink]) -> some View {
        if !links.isEmpty {
            Divider().padding(.top, 2)
            HStack(spacing: 8) {
                Text(NSLocalizedString("codex.advanced.docs.title", value: "Official Docs", comment: "Official docs"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(links) { link in
                    Button(link.title) {
                        openURL(link.url)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func openURL(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func mergedOptions(current: String, defaults: [String]) -> [String] {
        var options = defaults
        let normalized = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty && !options.contains(normalized) {
            options.insert(normalized, at: 0)
        }
        return options
    }

    private func localizedConfigLabel(_ key: String) -> String {
        NSLocalizedString("codex.config.label.\(key)", value: key, comment: "Codex config field label")
    }

    private func localizedConfigDescription(key: String, fallback: String) -> String {
        NSLocalizedString("codex.config.description.\(key)", value: fallback, comment: "Codex config field description")
    }

    private func localizedOptionLabel(key: String, value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return NSLocalizedString("codex.config.option.unset", value: "Unset", comment: "Unset option")
        }
        let optionKey = "codex.config.option.\(key).\(normalized)"
        return NSLocalizedString(optionKey, value: normalized, comment: "Codex config option value")
    }

    @ViewBuilder
    private func largeTextEditorSheet(for target: LargeTextEditorTarget) -> some View {
        switch target {
        case .compactPrompt:
            VStack(alignment: .leading, spacing: 12) {
                Text(localizedConfigLabel("compact_prompt"))
                    .font(.headline)
                Text(localizedConfigDescription(
                    key: "compact_prompt",
                    fallback: "Inline override for the history compaction prompt."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.compactPromptDraft)
                    .font(.body.monospaced())
                    .frame(minWidth: 560, minHeight: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                HStack {
                    if !viewModel.compactPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                            viewModel.compactPromptDraft = ""
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    }
                    Spacer()
                    Button(NSLocalizedString("generic.close", value: "Close", comment: "Close")) {
                        textEditorTarget = nil
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                }
            }
            .padding(20)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let target = filePickerTarget else { return }
        defer { filePickerTarget = nil }
        guard case .success(let urls) = result, let url = urls.first else { return }
        let path = url.path
        switch target {
        case .experimentalCompactPromptFile:
            viewModel.experimentalCompactPromptFileDraft = path
        case .roleConfigFile:
            pendingNewRoleDraft.configFile = path
            if case .existing(let roleID) = roleEditorTarget?.mode,
               let index = viewModel.roleDrafts.firstIndex(where: { $0.id == roleID }) {
                viewModel.roleDrafts[index].configFile = path
            }
        }
        viewModel.scheduleStructuredSaveIfReady()
    }

    private var historyMaxBytesPresets: [String] { ["5242880", "20971520", "104857600"] }
    private var autoCompactTokenPresets: [String] { ["32000", "64000", "128000"] }
    private var agentThreadPresets: [String] { ["4", "8", "16"] }
    private var agentDepthPresets: [String] { ["2", "4", "8"] }

    private var runtimeOverviewSection: some View {
        NolonUI.CodexAdvancedRuntimeOverviewView(
            stats: runtimeOverviewStats,
            metaRows: runtimeOverviewMetaRows
        )
    }

    private var availableModelsSection: some View {
        let visibleModels = viewModel.visibleModels
        return NolonUI.CodexAdvancedModelsCacheSectionView(
            title: NSLocalizedString(
                "codex.advanced.models_cache.title",
                value: "Models Cache",
                comment: "Models cache section title"
            ),
            isApplyingModel: viewModel.isApplyingModel,
            reasoningLabel: NSLocalizedString(
                "codex.advanced.models_cache.reasoning_effort",
                value: "Reasoning Effort",
                comment: "Reasoning effort title"
            ),
            reasoningOptions: reasoningEffortOptions,
            reasoningSelection: Binding(
                get: { viewModel.selectedReasoningEffort ?? "__default__" },
                set: { value in
                    let effort = value == "__default__" ? nil : value
                    Task { await viewModel.applyReasoningEffort(effort) }
                }
            ),
            isReasoningDisabled: viewModel.availableReasoningEfforts.isEmpty
                || viewModel.isApplyingReasoning
                || viewModel.activeModel == nil,
            isApplyingReasoning: viewModel.isApplyingReasoning,
            showsReasoningUnsupportedHint: viewModel.availableReasoningEfforts.isEmpty,
            reasoningUnsupportedHintText: NSLocalizedString(
                "codex.advanced.models_cache.reasoning_effort.unsupported",
                value: "The active model does not support configurable reasoning effort.",
                comment: "Reasoning unsupported text"
            ),
            isModelsEmpty: viewModel.models.isEmpty,
            modelsEmptyHintText: NSLocalizedString(
                "provider.binary.codex.model.empty",
                value: "No model list found in models_cache.json. Run Codex CLI once to refresh cache.",
                comment: "No cached model list"
            ),
            hasHiddenActiveModel: viewModel.hasHiddenActiveModel,
            hiddenActiveModelHintText: NSLocalizedString(
                "codex.advanced.models_cache.hidden_active_hint",
                value: "Current model is hidden from list. Activate a visible model to replace it.",
                comment: "Hidden active model hint"
            ),
            modelLabel: NSLocalizedString(
                "codex.advanced.models_cache.column.model",
                value: "Model",
                comment: "Model column title"
            ),
            modelOptions: visibleModels.map {
                CodexAdvancedPickerOption(id: $0.slug, title: $0.displayName)
            },
            modelSelection: Binding(
                get: { viewModel.activeModelSlug ?? "" },
                set: { slug in
                    guard
                        !slug.isEmpty,
                        slug != viewModel.activeModelSlug,
                        let model = visibleModels.first(where: { $0.slug == slug })
                    else { return }
                    Task { await viewModel.activateModel(model) }
                }
            ),
            isModelDisabled: viewModel.isApplyingModel || visibleModels.isEmpty
        )
    }

    private var reasoningEffortOptions: [CodexAdvancedPickerOption] {
        let defaultOption = CodexAdvancedPickerOption(
            id: "__default__",
            title: NSLocalizedString(
                "codex.advanced.models_cache.reasoning_effort.default",
                value: "Use Model Default",
                comment: "Default reasoning effort"
            )
        )
        let effortOptions = viewModel.availableReasoningEfforts.map {
            CodexAdvancedPickerOption(
                id: $0,
                title: localizedOptionLabel(key: "model_reasoning_effort", value: $0)
            )
        }
        return [defaultOption] + effortOptions
    }

    private var runtimeOverviewMetaRows: [CodexAdvancedMetaRowData] {
        var rows: [CodexAdvancedMetaRowData] = []
        if let sourcePath = viewModel.modelsCacheSourcePath, !sourcePath.isEmpty {
            rows.append(
                CodexAdvancedMetaRowData(
                    id: "sourcePath",
                    text: sourcePath,
                    isMonospaced: true
                )
            )
        }
        if let clientVersion = viewModel.modelsCacheClientVersion, !clientVersion.isEmpty {
            rows.append(
                CodexAdvancedMetaRowData(
                    id: "clientVersion",
                    text: "client: \(clientVersion)",
                    isMonospaced: false
                )
            )
        }
        return rows
    }

    private var xcodeFolderLinksSection: some View {
        NolonUI.CodexXcodeFolderLinksSectionView(
            descriptionText: NSLocalizedString(
                "codex.advanced.xcode_links.desc",
                value: "Link Xcode Codex folders to ~/.codex equivalents.",
                comment: "Xcode links description"
            ),
            cards: xcodeFolderLinkCards,
            onToggleLink: { folderID, enabled in
                guard let folder = CodexLinkFolder(rawValue: folderID) else { return }
                Task { await viewModel.requestSetLink(enabled, folder: folder) }
            },
            onShowInFinder: { folderID in
                guard let folder = CodexLinkFolder(rawValue: folderID) else { return }
                let state = viewModel.linkState(for: folder)
                NSWorkspace.shared.activateFileViewerSelecting([state.targetURL])
            }
        )
        .debugCardLocator(sectionMarkerItems("Xcode Folder Links"))
    }

    private var xcodeFolderLinkCards: [CodexXcodeFolderLinkCardData] {
        CodexLinkFolder.allCases.map { folder in
            let state = viewModel.linkState(for: folder)
            return xcodeFolderLinkCardData(folder: folder, state: state)
        }
    }

    private func sectionMarkerItems(_ title: String) -> [PageMarkerItem] {
        let prefix = markerBaseItems.isEmpty
            ? [
                PageMarkerItem(title: provider.displayName),
                PageMarkerItem(title: ProviderContentTabType.advanced.localizedName(for: provider))
            ]
            : markerBaseItems
        return prefix + [PageMarkerItem(title: title)]
    }

    private func itemMarkerItems(_ title: String) -> [PageMarkerItem] {
        let prefix = markerBaseItems.isEmpty
            ? [
                PageMarkerItem(title: provider.displayName),
                PageMarkerItem(title: ProviderContentTabType.advanced.localizedName(for: provider))
            ]
            : markerBaseItems
        return prefix + [PageMarkerItem(title: title)]
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func linkStatusText(isLinked: Bool) -> String {
        if isLinked {
            return NSLocalizedString("status.linked", value: "Linked", comment: "Linked status")
        }
        return NSLocalizedString("status.not_linked", value: "Not Linked", comment: "Not linked status")
    }

    private func xcodeFolderLinkCardData(
        folder: CodexLinkFolder,
        state: CodexLinkState
    ) -> CodexXcodeFolderLinkCardData {
        CodexXcodeFolderLinkCardData(
            id: folder.id,
            folderTitle: folder.rawValue.capitalized,
            statusText: linkStatusText(isLinked: state.isLinked),
            isLinked: state.isLinked,
            sourcePathText: "~/.codex/\(folder.rawValue)",
            targetPathText: displayPath(state.targetURL.path),
            hasVisibleEntries: state.hasVisibleEntries,
            conflictHintText: NSLocalizedString(
                "codex.advanced.link.conflict.short",
                value: "Contains visible files",
                comment: "Short conflict hint"
            ),
            showInFinderTitle: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
            isApplying: viewModel.applyingLinkFolders.contains(folder)
        )
    }

    private func roleRowData(_ role: CodexAgentRoleDraft) -> CodexAdvancedRoleRowData {
        CodexAdvancedRoleRowData(
            id: role.id.uuidString,
            title: role.name.nonEmpty ?? NSLocalizedString(
                "codex.advanced.config.multi_agent.unnamed_role",
                value: "Unnamed Role",
                comment: "Unnamed role"
            ),
            modelText: role.model.nonEmpty ?? "-",
            editTitle: NSLocalizedString("action.edit", value: "Edit", comment: "Edit action")
        )
    }

    private var roleListRows: [CodexAdvancedRoleRowData] {
        viewModel.roleDrafts.map(roleRowData)
    }

    private var multiAgentToggleRowData: CodexAdvancedMultiAgentToggleRowData {
        CodexAdvancedMultiAgentToggleRowData(
            labelText: NSLocalizedString(
                "codex.advanced.config.multi_agent.toggle_label",
                value: "[features].multi_agent",
                comment: "multi-agent toggle label"
            ),
            isEnabled: viewModel.featureEnabled("multi_agent")
        )
    }

    private var roleAddBuiltinItems: [CodexAdvancedRoleAddBuiltinItem] {
        CodexBuiltinAgentRole.allCases.map { builtinRole in
            CodexAdvancedRoleAddBuiltinItem(
                id: builtinRole.rawValue,
                title: String(
                    format: NSLocalizedString(
                        "codex.advanced.config.multi_agent.add_builtin.format",
                        value: "Add or Override: %@",
                        comment: "Add/override builtin role format"
                    ),
                    builtinRole.rawValue
                )
            )
        }
    }

    private var multiAgentStatusRowData: CodexAdvancedMultiAgentStatusRowData {
        let enabled = viewModel.featureEnabled("multi_agent")
        return CodexAdvancedMultiAgentStatusRowData(
            isEnabled: enabled,
            messageText: NSLocalizedString(
                enabled
                    ? "codex.advanced.config.multi_agent.status_enabled"
                    : "codex.advanced.config.multi_agent.status_disabled",
                value: enabled
                    ? "Multi-agent is enabled. You can edit roles and agents settings below."
                    : "Multi-agent is disabled. Enable the switch above to edit roles.",
                comment: "multi-agent status"
            )
        )
    }

    private var runtimeOverviewStats: [CodexAdvancedStatTileData] {
        [
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.active", value: "Active", comment: "Active model"),
                value: viewModel.activeModel?.displayName ?? "-"
            ),
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.total", value: "Total", comment: "Total models"),
                value: "\(viewModel.visibleModels.count)"
            ),
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.reasoning_effort", value: "Reasoning Effort", comment: "Reasoning effort title"),
                value: viewModel.selectedReasoningEffort ?? NSLocalizedString(
                    "codex.advanced.models_cache.reasoning_effort.default",
                    value: "Use Model Default",
                    comment: "Default reasoning effort"
                )
            ),
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.meta.fetched_at", value: "Last Fetch", comment: "Last fetch"),
                value: viewModel.modelsCacheFetchedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-"
            )
        ]
    }

    private func pathStatusText(_ status: CodexBinaryManager.CodexPathStatus) -> String {
        let configured = status.configured
            ? NSLocalizedString("codex.binary.path.configured", value: "Yes", comment: "Configured label")
            : NSLocalizedString("codex.binary.path.not_configured", value: "No", comment: "Not configured label")
        let active = status.active
            ? NSLocalizedString("codex.binary.path.active", value: "Yes", comment: "Active label")
            : NSLocalizedString("codex.binary.path.inactive", value: "No", comment: "Inactive label")
        return String(
            format: NSLocalizedString(
                "codex.binary.path.status",
                value: "Shell: %@ (%@) • Configured: %@ • Active: %@",
                comment: "PATH status line"
            ),
            status.shellName,
            status.profilePath,
            configured,
            active
        )
    }

    private var pathStatusBarData: CodexPathStatusBarData {
        CodexPathStatusBarData(
            title: NSLocalizedString("codex.binary.path.section", value: "Terminal PATH", comment: "PATH section title"),
            statusText: viewModel.pathStatus.map(pathStatusText),
            configureTitle: NSLocalizedString("codex.binary.path.configure", value: "Add to PATH", comment: "Add codex path to shell profile"),
            checkTitle: NSLocalizedString("codex.binary.path.check", value: "Check", comment: "Check PATH status"),
            isCheckingPath: viewModel.isCheckingPath,
            isConfiguringPath: viewModel.isConfiguringPath
        )
    }

}
