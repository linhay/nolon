import AppKit
import Observation
import ProviderCatalog
import SwiftUI
import STFilePath
import CodexProvider
import NolonResourceKit
import TOML

enum CodexLinkFolder: String, CaseIterable, Identifiable, Hashable {
    case prompts
    case rules
    case skills

    var id: String { rawValue }
}

struct CodexLinkState: Sendable {
    let folder: CodexLinkFolder
    let sourceURL: URL
    let targetURL: URL
    let isLinked: Bool
    let hasVisibleEntries: Bool
}

struct CodexLinkConflict: Identifiable {
    let folder: CodexLinkFolder
    let targetURL: URL

    var id: String { folder.rawValue }
}

struct CodexConfigDocLink: Identifiable, Sendable {
    let id: String
    let title: String
    let url: String
}

struct CodexFeatureDefinition: Identifiable, Sendable {
    let key: String
    let maturity: String
    let description: String
    let source: String

    var id: String { key }
}

private struct CodexFeatureChipStyle {
    let foreground: Color
    let background: Color
    let border: Color
}

private enum CodexFeatureSourceTag: String, CaseIterable {
    case coreFeatures
    case cliFeaturesList
    case appServer
    case codexDocs
    case nolonCompatibility
    case configUnknown

    var localizedTitle: String {
        switch self {
        case .coreFeatures:
            return NSLocalizedString("codex.features.source.tag.core_features", value: "Core Features", comment: "Core features source tag")
        case .cliFeaturesList:
            return NSLocalizedString("codex.features.source.tag.cli_features_list", value: "CLI Features List", comment: "CLI features list source tag")
        case .appServer:
            return NSLocalizedString("codex.features.source.tag.app_server", value: "App Server", comment: "App server source tag")
        case .codexDocs:
            return NSLocalizedString("codex.features.source.tag.codex_docs", value: "Codex Docs", comment: "Codex docs source tag")
        case .nolonCompatibility:
            return NSLocalizedString("codex.features.source.tag.nolon_compatibility", value: "Nolon Compatibility", comment: "Nolon compatibility source tag")
        case .configUnknown:
            return NSLocalizedString("codex.features.source.tag.config_unknown", value: "Config Unknown Key", comment: "Config unknown source tag")
        }
    }
}

struct CodexAgentRoleDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var description: String
    var configFile: String
    var model: String
    var modelReasoningEffort: String
    var sandboxMode: String
    var approvalPolicy: String
}

enum CodexBuiltinAgentRole: String, CaseIterable, Identifiable {
    case `default`
    case worker
    case explorer
    case monitor

    var id: String { rawValue }

    var defaultDescription: String {
        switch self {
        case .default:
            return "General fallback role."
        case .worker:
            return "Execution-focused role for implementation and fixes."
        case .explorer:
            return "Read-focused role for repository exploration."
        case .monitor:
            return "Long-running task monitor role optimized for wait/poll workflows."
        }
    }
}

@MainActor
@Observable
final class CodexAdvancedConfigViewModel {
    var preferredModelDraft: String = ""
    var errorMessage: String?
    var pathStatus: CodexBinaryManager.CodexPathStatus?
    var isConfiguringPath = false
    var isCheckingPath = false
    var models: [CodexModelsCache.Model] = []
    var activeModelSlug: String?
    var selectedReasoningEffort: String?
    var isApplyingModel = false
    var isApplyingReasoning = false
    var modelsCacheSourcePath: String?
    var modelsCacheFetchedAt: Date?
    var modelsCacheClientVersion: String?
    var modelsCacheETag: String?
    var pendingConflict: CodexLinkConflict?
    var linkStates: [CodexLinkFolder: CodexLinkState] = [:]
    var applyingLinkFolders: Set<CodexLinkFolder> = []
    var configFileURL: URL?
    var isSavingConfig = false
    var configErrorMessage: String?
    var approvalPolicyDraft: String = ""
    var sandboxModeDraft: String = ""
    var webSearchDraft: String = ""
    var modelProviderDraft: String = ""
    var profileDraft: String = ""
    var personalityDraft: String = ""
    var reasoningSummaryDraft: String = ""
    var verbosityDraft: String = ""
    var agentsMaxThreadsDraft: String = ""
    var agentsMaxDepthDraft: String = ""
    var featureValues: [String: Bool] = [:]
    var roleDrafts: [CodexAgentRoleDraft] = []

    private var provider: Provider
    private let manager: CodexBinaryManager
    private let linkService: CodexLinkService
    private let modelPreferenceService: CodexModelPreferenceService

    nonisolated deinit {}

    static let supportedFeatures: [CodexFeatureDefinition] = [
        .init(key: "undo", maturity: "Stable", description: "Create a ghost commit at each turn.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "shell_tool", maturity: "Stable", description: "Enable the default shell tool.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "unified_exec", maturity: "Stable", description: "Use the unified PTY-backed exec tool.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "shell_snapshot", maturity: "Experimental", description: "Snapshot shell env for repeated commands.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "web_search_request", maturity: "Deprecated", description: "Legacy live web search toggle.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "web_search_cached", maturity: "Deprecated", description: "Legacy cached web search toggle.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "search_tool", maturity: "Under Development", description: "Enable search_tool_bm25 tool discovery.", source: "codex-rs/core/src/features.rs"),
        .init(key: "runtime_metrics", maturity: "Under Development", description: "Show runtime metrics summaries in TUI.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "sqlite", maturity: "Under Development", description: "Persist rollout metadata to local SQLite.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "memory_tool", maturity: "Under Development", description: "Enable startup memory extraction and consolidation.", source: "codex-rs/core/src/features.rs"),
        .init(key: "child_agents_md", maturity: "Under Development", description: "Append additional AGENTS.md guidance.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "apply_patch_freeform", maturity: "Under Development", description: "Enable freeform apply_patch tool mode.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "exec_policy", maturity: "Under Development", description: "Enable exec policy pipeline.", source: "codex features list (local CLI)"),
        .init(key: "use_linux_sandbox_bwrap", maturity: "Under Development", description: "Use Linux bubblewrap sandbox pipeline.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "request_rule", maturity: "Stable", description: "Enable smart approval prefix rule suggestions.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "experimental_windows_sandbox", maturity: "Under Development", description: "Enable Windows restricted-token sandbox.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "elevated_windows_sandbox", maturity: "Under Development", description: "Enable elevated Windows sandbox runner.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "remote_compaction", maturity: "Under Development", description: "Enable remote compaction flow.", source: "codex features list (local CLI)"),
        .init(key: "remote_models", maturity: "Under Development", description: "Refresh remote model list before readiness.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "powershell_utf8", maturity: "Under Development", description: "Enforce UTF8 output in PowerShell.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "enable_request_compression", maturity: "Stable", description: "Enable compressed request bodies.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "collab", maturity: "Experimental", description: "Enable collab/sub-agent tools.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "apps", maturity: "Experimental", description: "Enable ChatGPT Apps/connectors support.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "skill_mcp_dependency_install", maturity: "Stable", description: "Allow installing missing MCP dependencies for skills.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "skill_env_var_dependency_prompt", maturity: "Under Development", description: "Prompt for missing skill env var dependencies.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "steer", maturity: "Stable", description: "Enable steer mode behavior.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "collaboration_modes", maturity: "Stable", description: "Enable collaboration modes such as plan mode.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "personality", maturity: "Stable", description: "Enable personality selection controls.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "responses_websockets", maturity: "Under Development", description: "Use Responses API WebSocket transport by default.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "responses_websockets_v2", maturity: "Under Development", description: "Enable Responses API websocket v2 mode.", source: "codex-rs/core/src/features.rs"),
        .init(key: "multi_agent", maturity: "Experimental", description: "Enable multi-agent collaboration tools.", source: "codex docs + Nolon config support"),
        .init(key: "apps_mcp_gateway", maturity: "Experimental", description: "Use the Apps MCP gateway endpoint.", source: "codex docs + Nolon config support"),
        .init(key: "web_search", maturity: "Deprecated", description: "Legacy web_search feature toggle.", source: "legacy compatibility (Nolon)"),
    ]

    init(
        provider: Provider,
        manager: CodexBinaryManager = .shared,
        linkService: CodexLinkService = CodexLinkService(),
        modelPreferenceService: CodexModelPreferenceService = CodexModelPreferenceService()
    ) {
        self.provider = provider
        self.manager = manager
        self.linkService = linkService
        self.modelPreferenceService = modelPreferenceService
    }

    func updateProvider(_ provider: Provider) {
        self.provider = provider
    }

    var isCodexXcodeProvider: Bool {
        if provider.templateId == "codexXcode" { return true }
        let expanded = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        return expanded.contains("/Library/Developer/Xcode/CodingAssistant/codex")
    }

    var visibleModels: [CodexModelsCache.Model] {
        models.filter { model in
            let visibility = model.visibility?.lowercased()
            return visibility == nil || visibility == "list"
        }
    }

    var activeModel: CodexModelsCache.Model? {
        if let activeModelSlug {
            return models.first(where: { $0.slug == activeModelSlug })
        }
        return nil
    }

    var hasHiddenActiveModel: Bool {
        guard let activeModelSlug else { return false }
        guard models.contains(where: { $0.slug == activeModelSlug }) else { return false }
        return !visibleModels.contains(where: { $0.slug == activeModelSlug })
    }

    var availableReasoningEfforts: [String] {
        guard let activeModel else { return [] }
        var unique: [String] = []
        for effort in activeModel.supportedReasoningLevels.map(\.effort) {
            let trimmed = effort.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !unique.contains(trimmed) {
                unique.append(trimmed)
            }
        }
        return unique
    }

    func load() async {
        loadModelsCache()
        loadSelectionsFromConfig()
        loadConfigDraft()
        if isCodexXcodeProvider {
            pathStatus = nil
            refreshLinkStates()
        } else {
            await refreshPathStatus()
            linkStates = [:]
        }
    }

    func applySelectedModel() async {
        do {
            let trimmed = preferredModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            try await manager.applyModelToConfig(trimmed, configFile: resolvedConfigFile())
            preferredModelDraft = trimmed
            activeModelSlug = trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPreferredModel() async {
        do {
            try await manager.clearPreferredModel(configFile: resolvedConfigFile())
            preferredModelDraft = ""
            activeModelSlug = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activateModel(_ model: CodexModelsCache.Model) async {
        isApplyingModel = true
        defer { isApplyingModel = false }
        do {
            try await manager.applyModelToConfig(model.slug, configFile: resolvedConfigFile())
            activeModelSlug = model.slug
            preferredModelDraft = model.slug
            await normalizeReasoningEffortForActiveModel(persist: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyReasoningEffort(_ effort: String?) async {
        let normalized = effort?.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = availableReasoningEfforts
        if let normalized, !normalized.isEmpty, !options.contains(normalized) {
            return
        }
        isApplyingReasoning = true
        defer { isApplyingReasoning = false }
        do {
            try await manager.setModelReasoningEffort(
                normalized?.isEmpty == false ? normalized : nil,
                configFile: resolvedConfigFile()
            )
            selectedReasoningEffort = normalized?.isEmpty == false ? normalized : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openModelConfig() {
        let configFile = resolvedConfigFile()
        let configPath = configFile ?? STFile("\(NSHomeDirectory())/.codex/config.toml")
        do {
            _ = STFolder(configPath.url.deletingLastPathComponent()).createIfNotExists()
            if !configPath.isExists {
                let initialModel = preferredModelDraft.nonEmpty ?? "gpt-5.3-codex"
                try "model = \"\(initialModel)\"\n".write(to: configPath.url, atomically: true, encoding: .utf8)
            }
            NSWorkspace.shared.open(configPath.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPathStatus() async {
        guard !isCodexXcodeProvider else {
            pathStatus = nil
            return
        }
        isCheckingPath = true
        defer { isCheckingPath = false }
        pathStatus = await manager.codexPathStatus()
    }

    func installPath() async {
        guard !isCodexXcodeProvider else { return }
        isConfiguringPath = true
        defer { isConfiguringPath = false }
        do {
            try await manager.installCodexPathToShellProfile()
            pathStatus = await manager.codexPathStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestSetLink(_ enabled: Bool, folder: CodexLinkFolder) async {
        if enabled {
            guard let state = linkStates[folder] else { return }
            if state.isLinked { return }
            if state.hasVisibleEntries {
                pendingConflict = CodexLinkConflict(folder: folder, targetURL: state.targetURL)
                return
            }
            await setLink(enabled: true, folder: folder)
            return
        }

        await setLink(enabled: false, folder: folder)
    }

    func confirmPendingConflict() async {
        guard let pendingConflict else { return }
        let folder = pendingConflict.folder
        self.pendingConflict = nil
        await setLink(enabled: true, folder: folder)
    }

    func openFinderForPendingConflict() {
        guard let pendingConflict else { return }
        NSWorkspace.shared.activateFileViewerSelecting([pendingConflict.targetURL])
    }

    func refreshLinkStates() {
        guard isCodexXcodeProvider else {
            linkStates = [:]
            return
        }

        var result: [CodexLinkFolder: CodexLinkState] = [:]
        for folder in CodexLinkFolder.allCases {
            let status = linkService.status(folder: map(folder), provider: provider)
            result[folder] = CodexLinkState(
                folder: folder,
                sourceURL: status.sourceURL,
                targetURL: status.targetURL,
                isLinked: status.isLinked,
                hasVisibleEntries: status.hasVisibleEntries
            )
        }
        linkStates = result
    }

    func linkState(for folder: CodexLinkFolder) -> CodexLinkState {
        if let cached = linkStates[folder] {
            return cached
        }
        let pair = linkService.linkPair(folder: map(folder), provider: provider)
        return CodexLinkState(
            folder: folder,
            sourceURL: pair.sourceURL,
            targetURL: pair.targetURL,
            isLinked: false,
            hasVisibleEntries: false
        )
    }

    private func setLink(enabled: Bool, folder: CodexLinkFolder) async {
        guard isCodexXcodeProvider else { return }
        applyingLinkFolders.insert(folder)
        defer { applyingLinkFolders.remove(folder) }

        do {
            try linkService.apply(enabled: enabled, folder: map(folder), provider: provider)
            refreshLinkStates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadModelsCache() {
        let snapshot = modelPreferenceService.loadModelsCache(for: provider)
        models = snapshot.models
        modelsCacheSourcePath = snapshot.sourcePath
        modelsCacheFetchedAt = snapshot.fetchedAt
        modelsCacheClientVersion = snapshot.clientVersion
        modelsCacheETag = snapshot.etag

        if let activeModelSlug, !models.contains(where: { $0.slug == activeModelSlug }) {
            self.activeModelSlug = nil
        }
    }

    func featureEnabled(_ key: String) -> Bool {
        featureValues[key] ?? false
    }

    func setFeature(_ key: String, enabled: Bool) {
        featureValues[key] = enabled
        if key == "multi_agent", !enabled {
            roleDrafts = []
            agentsMaxDepthDraft = ""
            agentsMaxThreadsDraft = ""
        }
    }

    static func makeEmptyRoleDraft() -> CodexAgentRoleDraft {
        CodexAgentRoleDraft(
            name: "",
            description: "",
            configFile: "",
            model: "",
            modelReasoningEffort: "",
            sandboxMode: "",
            approvalPolicy: ""
        )
    }

    static func makeBuiltinRoleDraft(_ builtinRole: CodexBuiltinAgentRole) -> CodexAgentRoleDraft {
        CodexAgentRoleDraft(
            name: builtinRole.rawValue,
            description: builtinRole.defaultDescription,
            configFile: "",
            model: "",
            modelReasoningEffort: "",
            sandboxMode: "",
            approvalPolicy: ""
        )
    }

    @discardableResult
    func addRoleDraft(_ role: CodexAgentRoleDraft? = nil) -> UUID {
        let role = role ?? Self.makeEmptyRoleDraft()
        roleDrafts.append(role)
        return role.id
    }

    @discardableResult
    func upsertBuiltinRole(_ builtinRole: CodexBuiltinAgentRole) -> UUID {
        if let index = roleDrafts.firstIndex(where: { $0.name == builtinRole.rawValue }) {
            roleDrafts[index].description = builtinRole.defaultDescription
            return roleDrafts[index].id
        }

        let role = Self.makeBuiltinRoleDraft(builtinRole)
        roleDrafts.append(role)
        return role.id
    }

    func removeRoleDraft(_ id: UUID) {
        roleDrafts.removeAll { $0.id == id }
    }

    func saveStructuredConfig() async {
        guard let configFile = resolvedConfigFile() else { return }
        isSavingConfig = true
        defer { isSavingConfig = false }

        do {
            let base = loadConfigFromFile(configFile) ?? CodexConfigToml()
            let merged = mergeDraft(into: base)
            let data = try TOMLEncoder().encode(merged)
            try configFile.overlay(with: String(decoding: data, as: UTF8.self))
            loadConfigDraft()
        } catch {
            configErrorMessage = error.localizedDescription
        }
    }

    func reloadConfigDraft() {
        loadConfigDraft()
    }

    private func resolvedConfigFile() -> STFile? {
        modelPreferenceService.resolvedConfigFile(for: provider)
    }

    private func loadConfigFromFile(_ configFile: STFile) -> CodexConfigToml? {
        guard configFile.isExists else { return nil }
        guard let data = try? Data(contentsOf: configFile.url), !data.isEmpty else { return nil }
        return try? CodexGeneratedFilesParser.parseConfigToml(data: data)
    }

    private func loadConfigDraft() {
        guard let configFile = resolvedConfigFile() else { return }
        configFileURL = configFile.url
        let config = loadConfigFromFile(configFile) ?? CodexConfigToml()

        approvalPolicyDraft = config.approvalPolicy ?? ""
        sandboxModeDraft = config.sandboxMode ?? ""
        webSearchDraft = config.webSearch ?? ""
        modelProviderDraft = config.modelProvider ?? ""
        profileDraft = config.profile ?? ""
        personalityDraft = config.personality ?? ""
        reasoningSummaryDraft = config.modelReasoningSummary ?? ""
        verbosityDraft = config.modelVerbosity ?? ""
        agentsMaxThreadsDraft = config.agents?.maxThreads.map(String.init) ?? ""
        agentsMaxDepthDraft = config.agents?.maxDepth.map(String.init) ?? ""
        featureValues = config.features ?? [:]
        roleDrafts = (config.agents?.roles ?? [:]).keys.sorted().compactMap { key in
            guard let role = config.agents?.roles[key] else { return nil }
            return CodexAgentRoleDraft(
                name: key,
                description: role.description ?? "",
                configFile: role.configFile ?? "",
                model: role.model ?? "",
                modelReasoningEffort: role.modelReasoningEffort ?? "",
                sandboxMode: role.sandboxMode ?? "",
                approvalPolicy: role.approvalPolicy ?? ""
            )
        }
    }

    private func mergeDraft(into base: CodexConfigToml) -> CodexConfigToml {
        var roles: [String: CodexConfigToml.AgentRole] = [:]
        for role in roleDrafts {
            let name = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            roles[name] = .init(
                description: role.description.nonEmpty,
                configFile: role.configFile.nonEmpty,
                model: role.model.nonEmpty,
                modelReasoningEffort: role.modelReasoningEffort.nonEmpty,
                modelReasoningSummary: nil,
                modelVerbosity: nil,
                approvalPolicy: role.approvalPolicy.nonEmpty,
                sandboxMode: role.sandboxMode.nonEmpty,
                personality: nil,
                webSearch: nil
            )
        }

        let maxThreads = Int(agentsMaxThreadsDraft.trimmingCharacters(in: .whitespacesAndNewlines))
        let maxDepth = Int(agentsMaxDepthDraft.trimmingCharacters(in: .whitespacesAndNewlines))
        let agents = (!roles.isEmpty || maxThreads != nil || maxDepth != nil)
            ? CodexConfigToml.Agents(maxThreads: maxThreads, maxDepth: maxDepth, roles: roles)
            : nil
        let normalizedFeatures = featureValues.filter { $0.value || (base.features?[$0.key] != nil) }

        return CodexConfigToml(
            model: base.model,
            reviewModel: base.reviewModel,
            modelProvider: modelProviderDraft.nonEmpty,
            modelContextWindow: base.modelContextWindow,
            modelAutoCompactTokenLimit: base.modelAutoCompactTokenLimit,
            profile: profileDraft.nonEmpty,
            approvalPolicy: approvalPolicyDraft.nonEmpty,
            sandboxMode: sandboxModeDraft.nonEmpty,
            sandboxWorkspaceWrite: base.sandboxWorkspaceWrite,
            notify: base.notify,
            instructions: base.instructions,
            developerInstructions: base.developerInstructions,
            compactPrompt: base.compactPrompt,
            modelReasoningEffort: base.modelReasoningEffort,
            modelReasoningSummary: reasoningSummaryDraft.nonEmpty,
            modelVerbosity: verbosityDraft.nonEmpty,
            modelSupportsReasoningSummaries: base.modelSupportsReasoningSummaries,
            personality: personalityDraft.nonEmpty,
            chatgptBaseURL: base.chatgptBaseURL,
            webSearch: webSearchDraft.nonEmpty,
            tools: base.tools,
            agents: agents,
            features: normalizedFeatures.isEmpty ? nil : normalizedFeatures,
            suppressUnstableFeaturesWarning: base.suppressUnstableFeaturesWarning,
            checkForUpdateOnStartup: base.checkForUpdateOnStartup,
            hideAgentReasoning: base.hideAgentReasoning,
            showRawAgentReasoning: base.showRawAgentReasoning,
            ossProvider: base.ossProvider,
            history: base.history,
            mcpServers: base.mcpServers,
            profiles: base.profiles
        )
    }

    private func loadSelectionsFromConfig() {
        guard let config = modelPreferenceService.loadConfig(for: provider) else {
            preferredModelDraft = ""
            activeModelSlug = nil
            selectedReasoningEffort = nil
            return
        }
        let model = config.model?.trimmingCharacters(in: .whitespacesAndNewlines)
        preferredModelDraft = model ?? ""
        activeModelSlug = model
        selectedReasoningEffort = config.modelReasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeReasoningEffortForActiveModel(persist: Bool) async {
        let options = availableReasoningEfforts
        if options.isEmpty {
            if persist {
                try? await manager.setModelReasoningEffort(nil, configFile: resolvedConfigFile())
            }
            selectedReasoningEffort = nil
            return
        }

        if let selectedReasoningEffort, options.contains(selectedReasoningEffort) {
            return
        }

        let fallback = [activeModel?.defaultReasoningLevel, options.first]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { options.contains($0) })

        selectedReasoningEffort = fallback
        if persist {
            try? await manager.setModelReasoningEffort(fallback, configFile: resolvedConfigFile())
        }
    }

    private func map(_ folder: CodexLinkFolder) -> CodexLinkFolderKind {
        switch folder {
        case .prompts: return .prompts
        case .rules: return .rules
        case .skills: return .skills
        }
    }
}

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

    let provider: Provider
    @State private var viewModel: CodexAdvancedConfigViewModel
    @State private var isEditingRawConfig = false
    @State private var roleEditorTarget: RoleEditorTarget?
    @State private var pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
    @State private var featureSearchText: String = ""

    init(provider: Provider) {
        self.provider = provider
        self._viewModel = State(initialValue: CodexAdvancedConfigViewModel(provider: provider))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(NSLocalizedString("codex.advanced.config.options.title", value: "Common Options", comment: "Common options"))
                commonOptionsSection

                sectionHeader(NSLocalizedString("codex.advanced.config.features.title", value: "Feature Flags", comment: "Feature flags"))
                featureFlagsSection

                sectionHeader(NSLocalizedString("codex.advanced.config.multi_agent.title", value: "Multi-Agent Roles", comment: "Multi-agent roles"))
                multiAgentSection

                if viewModel.isCodexXcodeProvider {
                    sectionHeader(NSLocalizedString("codex.advanced.xcode_links.title", value: "Xcode Folder Links", comment: "Xcode folder links section title"))
                    xcodeFolderLinksSection
                }
            }
            .padding()
        }
        .textSelection(.enabled)
        .task(id: provider.id) {
            viewModel.updateProvider(provider)
            await viewModel.load()
        }
        .sheet(isPresented: $isEditingRawConfig) {
            if let configURL = viewModel.configFileURL {
                CodexConfigEditorView(configURL: configURL) {
                    viewModel.reloadConfigDraft()
                }
            } else {
                EmptyView()
            }
        }
        .sheet(item: $roleEditorTarget) { target in
            roleEditorSheet(for: target)
        }
        .alert(
            NSLocalizedString("codex.binary.error.title", value: "Binary Error", comment: "Binary error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(
            NSLocalizedString("codex.advanced.config.error.title", value: "Config Error", comment: "Config error"),
            isPresented: Binding(
                get: { viewModel.configErrorMessage != nil },
                set: { if !$0 { viewModel.configErrorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.configErrorMessage = nil
            }
        } message: {
            Text(viewModel.configErrorMessage ?? "")
        }
        .alert(
            NSLocalizedString("codex.advanced.link.conflict.title", value: "Directory Contains Files", comment: "Conflict title"),
            isPresented: Binding(
                get: { viewModel.pendingConflict != nil },
                set: { if !$0 { viewModel.pendingConflict = nil } }
            )
        ) {
            Button(NSLocalizedString("codex.advanced.link.confirm", value: "Confirm", comment: "Confirm action"), role: .destructive) {
                Task { await viewModel.confirmPendingConflict() }
            }
            Button(NSLocalizedString("action.show_in_finder", comment: "Show in Finder")) {
                viewModel.openFinderForPendingConflict()
            }
            Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "codex.advanced.link.conflict.message",
                    value: "The target folder already contains files. Confirm to delete its visible contents and replace it with a symlink.",
                    comment: "Conflict message"
                )
            )
        }
    }

    private var commonOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            runtimeOverviewSection

            if !viewModel.isCodexXcodeProvider, viewModel.pathStatus?.configured != true {
                Divider().padding(.vertical, 6)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("codex.binary.path.section", value: "Terminal PATH", comment: "PATH section title"))
                            .font(.callout)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        HStack(spacing: 8) {
                            if viewModel.isCheckingPath {
                                ProgressView().controlSize(.small)
                            }
                            if let status = viewModel.pathStatus {
                                Text(pathStatusText(status))
                                    .font(.footnote)
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Button(NSLocalizedString("codex.binary.path.configure", value: "Add to PATH", comment: "Add codex path to shell profile")) {
                        Task { await viewModel.installPath() }
                    }
                    .dsPrimaryButton()
                    .disabled(viewModel.isConfiguringPath || viewModel.isCheckingPath)
                    Button(NSLocalizedString("codex.binary.path.check", value: "Check", comment: "Check PATH status")) {
                        Task { await viewModel.refreshPathStatus() }
                    }
                    .dsSecondaryButton()
                    .disabled(viewModel.isConfiguringPath || viewModel.isCheckingPath)
                }
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
                    defaults: ["untrusted", "on-failure", "on-request", "never"]
                )
            )
            commonOptionPickerRow(
                title: "sandbox_mode",
                selection: $viewModel.sandboxModeDraft,
                options: mergedOptions(
                    current: viewModel.sandboxModeDraft,
                    defaults: ["read-only", "workspace-write", "danger-full-access"]
                )
            )
            commonOptionPickerRow(
                title: "web_search",
                selection: $viewModel.webSearchDraft,
                options: mergedOptions(
                    current: viewModel.webSearchDraft,
                    defaults: ["cached", "live", "disabled"]
                )
            )
            commonOptionRow(title: "model_provider", text: $viewModel.modelProviderDraft)
            commonOptionRow(title: "profile", text: $viewModel.profileDraft)
            commonOptionPickerRow(
                title: "personality",
                selection: $viewModel.personalityDraft,
                options: mergedOptions(
                    current: viewModel.personalityDraft,
                    defaults: ["balanced", "concise", "verbose"]
                )
            )
            commonOptionPickerRow(
                title: "model_reasoning_summary",
                selection: $viewModel.reasoningSummaryDraft,
                options: mergedOptions(
                    current: viewModel.reasoningSummaryDraft,
                    defaults: ["none", "auto", "concise", "detailed"]
                )
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
                )
            )

            Divider()

            HStack {
                Spacer(minLength: 0)
                Button(NSLocalizedString("codex.advanced.config.edit_raw", value: "Edit Raw TOML", comment: "Edit raw TOML")) {
                    isEditingRawConfig = true
                }
                .dsSecondaryButton()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
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

        return VStack(alignment: .leading, spacing: 8) {
            TextField(
                NSLocalizedString(
                    "codex.features.search.placeholder",
                    value: "Search features...",
                    comment: "Feature search placeholder"
                ),
                text: $featureSearchText
            )
            .textFieldStyle(.roundedBorder)

            ForEach(renderedFeatures) { feature in
                let source = sourceTag(for: feature.source)
                let maturityStyle = maturityChipStyle(feature.maturity)
                let sourceStyle = sourceChipStyle(source)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        highlightedText(feature.key, query: query)
                            .font(.callout.monospaced())
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        highlightedText(localizedFeatureDescription(feature), query: query)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        HStack(spacing: 6) {
                            highlightedText(localizedMaturityLabel(feature.maturity), query: query)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(maturityStyle.foreground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    maturityStyle.background,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(maturityStyle.border, lineWidth: 1)
                                )
                            highlightedText(source.localizedTitle, query: query)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(sourceStyle.foreground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    sourceStyle.background,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(sourceStyle.border, lineWidth: 1)
                                )
                        }
                    }
                    Spacer(minLength: 0)
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { viewModel.featureEnabled(feature.key) },
                            set: { newValue in
                                viewModel.setFeature(feature.key, enabled: newValue)
                                Task { await viewModel.saveStructuredConfig() }
                            }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsCard(
                    background: DesignSystem.Colors.Background.surface.opacity(0.25),
                    cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
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

    private func highlightedText(_ raw: String, query: String) -> Text {
        var text = AttributedString(raw)
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return Text(text) }

        let lowerRaw = raw.lowercased()
        let lowerKeyword = keyword.lowercased()
        var searchStart = lowerRaw.startIndex
        while let range = lowerRaw.range(of: lowerKeyword, range: searchStart..<lowerRaw.endIndex) {
            let lowerBound = lowerRaw.distance(from: lowerRaw.startIndex, to: range.lowerBound)
            let upperBound = lowerRaw.distance(from: lowerRaw.startIndex, to: range.upperBound)
            let start = text.index(text.startIndex, offsetByCharacters: lowerBound)
            let end = text.index(text.startIndex, offsetByCharacters: upperBound)
            text[start..<end].backgroundColor = NSColor.systemYellow.withAlphaComponent(0.35)
            searchStart = range.upperBound
        }

        return Text(text)
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

    private func maturityChipStyle(_ maturity: String) -> CodexFeatureChipStyle {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") {
            return .init(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.14),
                border: DesignSystem.Colors.Status.success.opacity(0.45)
            )
        }
        if normalized.contains("experimental") || normalized.contains("beta") || normalized.contains("under_development") || normalized.contains("underdevelopment") {
            return .init(
                foreground: DesignSystem.Colors.Status.warning,
                background: DesignSystem.Colors.Status.warning.opacity(0.14),
                border: DesignSystem.Colors.Status.warning.opacity(0.45)
            )
        }
        if normalized.contains("deprecated") || normalized.contains("removed") {
            return .init(
                foreground: DesignSystem.Colors.Status.error,
                background: DesignSystem.Colors.Status.error.opacity(0.14),
                border: DesignSystem.Colors.Status.error.opacity(0.45)
            )
        }
        return .init(
            foreground: DesignSystem.Colors.Text.secondary,
            background: DesignSystem.Colors.Component.controlFillSubtle.opacity(0.25),
            border: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }

    private func sourceChipStyle(_ source: CodexFeatureSourceTag) -> CodexFeatureChipStyle {
        switch source {
        case .appServer, .cliFeaturesList:
            return .init(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.14),
                border: DesignSystem.Colors.Status.success.opacity(0.45)
            )
        case .codexDocs:
            return .init(
                foreground: DesignSystem.Colors.Status.info,
                background: DesignSystem.Colors.Status.info.opacity(0.14),
                border: DesignSystem.Colors.Status.info.opacity(0.45)
            )
        case .coreFeatures:
            return .init(
                foreground: DesignSystem.Colors.Status.warning,
                background: DesignSystem.Colors.Status.warning.opacity(0.14),
                border: DesignSystem.Colors.Status.warning.opacity(0.45)
            )
        case .nolonCompatibility, .configUnknown:
            return .init(
                foreground: DesignSystem.Colors.Text.secondary,
                background: DesignSystem.Colors.Component.controlFillSubtle.opacity(0.25),
                border: DesignSystem.Colors.Component.border.opacity(0.35)
            )
        }
    }

    private var multiAgentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(NSLocalizedString(
                    "codex.advanced.config.multi_agent.toggle_label",
                    value: "[features].multi_agent",
                    comment: "multi-agent toggle label"
                ))
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.featureEnabled("multi_agent") },
                        set: { newValue in
                            viewModel.setFeature("multi_agent", enabled: newValue)
                            Task { await viewModel.saveStructuredConfig() }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            HStack(spacing: 8) {
                let enabled = viewModel.featureEnabled("multi_agent")
                Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(enabled ? DesignSystem.Colors.Status.success : DesignSystem.Colors.Text.secondary)
                Text(NSLocalizedString(
                    enabled
                        ? "codex.advanced.config.multi_agent.status_enabled"
                        : "codex.advanced.config.multi_agent.status_disabled",
                    value: enabled
                        ? "Multi-agent is enabled. You can edit roles and agents settings below."
                        : "Multi-agent is disabled. Enable the switch above to edit roles.",
                    comment: "multi-agent status"
                ))
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            numericInputRow(
                label: "agents.max_threads",
                text: $viewModel.agentsMaxThreadsDraft
            )
            numericInputRow(
                label: "agents.max_depth",
                text: $viewModel.agentsMaxDepthDraft
            )

            if viewModel.roleDrafts.isEmpty {
                Text(NSLocalizedString(
                    "codex.advanced.config.multi_agent.empty",
                    value: "No roles configured yet. Click Add Role to create the first role.",
                    comment: "No multi-agent roles"
                ))
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsCard(
                    background: DesignSystem.Colors.Background.surface.opacity(0.26),
                    cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
                )
            } else {
                ForEach(viewModel.roleDrafts) { role in
                    let roleID = role.id
                    HStack(spacing: 8) {
                        Text(role.name.nonEmpty ?? NSLocalizedString(
                            "codex.advanced.config.multi_agent.unnamed_role",
                            value: "Unnamed Role",
                            comment: "Unnamed role"
                        ))
                        .font(.headline)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text(role.model.nonEmpty ?? "-")
                            .font(.caption.monospaced())
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)

                        Spacer(minLength: 0)

                        Button(NSLocalizedString("action.edit", value: "Edit", comment: "Edit action")) {
                            roleEditorTarget = RoleEditorTarget(mode: .existing(roleID))
                        }
                        .buttonStyle(.borderless)

                        Button(role: .destructive) {
                            viewModel.removeRoleDraft(roleID)
                            if case .existing(let editingID) = roleEditorTarget?.mode, editingID == roleID {
                                roleEditorTarget = nil
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard(
                        background: DesignSystem.Colors.Background.surface.opacity(0.26),
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                        borderColor: DesignSystem.Colors.Component.border.opacity(0.18)
                    )
                }
            }

            HStack {
                Menu {
                    Button(NSLocalizedString(
                        "codex.advanced.config.multi_agent.add_role.empty",
                        value: "Add Empty Role",
                        comment: "Add empty role"
                    )) {
                        pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
                        roleEditorTarget = RoleEditorTarget(mode: .creating)
                    }
                    Divider()
                    ForEach(CodexBuiltinAgentRole.allCases) { builtinRole in
                        Button(
                            String(
                                format: NSLocalizedString(
                                    "codex.advanced.config.multi_agent.add_builtin.format",
                                    value: "Add or Override: %@",
                                    comment: "Add/override builtin role format"
                                ),
                                builtinRole.rawValue
                            )
                        ) {
                            if viewModel.roleDrafts.contains(where: { $0.name == builtinRole.rawValue }) {
                                let roleID = viewModel.upsertBuiltinRole(builtinRole)
                                roleEditorTarget = RoleEditorTarget(mode: .existing(roleID))
                            } else {
                                pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeBuiltinRoleDraft(builtinRole)
                                roleEditorTarget = RoleEditorTarget(mode: .creating)
                            }
                        }
                    }
                } label: {
                    Label(
                        NSLocalizedString("codex.advanced.config.multi_agent.add_role", value: "Add Role", comment: "Add role"),
                        systemImage: "plus"
                    )
                }
                .dsSecondaryButton()
                Spacer(minLength: 0)
                Button(NSLocalizedString("action.save", value: "Save", comment: "Save")) {
                    Task { await viewModel.saveStructuredConfig() }
                }
                .dsPrimaryButton()
                .disabled(viewModel.isSavingConfig)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }

    @ViewBuilder
    private func roleEditorSheet(for target: RoleEditorTarget) -> some View {
        if let role = roleBinding(for: target) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(role.wrappedValue.name.nonEmpty ?? NSLocalizedString(
                        "codex.advanced.config.multi_agent.unnamed_role",
                        value: "Unnamed Role",
                        comment: "Unnamed role"
                    ))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                    roleTextFieldRow(
                        label: "name",
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.role_name",
                            value: "role name",
                            comment: "Role name placeholder"
                        ),
                        text: role.name
                    )
                    roleTextFieldRow(
                        label: "description",
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.description",
                            value: "description",
                            comment: "Role description placeholder"
                        ),
                        text: role.description
                    )
                    roleTextFieldRow(
                        label: "config_file",
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.config_file",
                            value: "config file path",
                            comment: "Role config file placeholder"
                        ),
                        text: role.configFile
                    )
                    roleTextFieldRow(
                        label: "model",
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.model",
                            value: "model",
                            comment: "Role model placeholder"
                        ),
                        text: role.model
                    )
                    roleEnumPickerField(
                        label: "model_reasoning_effort",
                        selection: role.modelReasoningEffort,
                        key: "model_reasoning_effort",
                        options: ["minimal", "low", "medium", "high"]
                    )
                    roleEnumPickerField(
                        label: "sandbox_mode",
                        selection: role.sandboxMode,
                        key: "sandbox_mode",
                        options: ["read-only", "workspace-write", "danger-full-access"]
                    )
                    roleEnumPickerField(
                        label: "approval_policy",
                        selection: role.approvalPolicy,
                        key: "approval_policy",
                        options: ["untrusted", "on-failure", "on-request", "never"]
                    )

                    Divider().padding(.top, 4)

                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Button(NSLocalizedString("generic.close", value: "Close", comment: "Close")) {
                            closeRoleEditor(target)
                        }
                        .dsSecondaryButton()
                        Button(NSLocalizedString("action.save", value: "Save", comment: "Save")) {
                            commitRoleEditorIfNeeded(target)
                            Task { await viewModel.saveStructuredConfig() }
                            closeRoleEditor(target)
                        }
                        .dsPrimaryButton()
                        .disabled(viewModel.isSavingConfig)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 680, minHeight: 420)
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
        alignedConfigRow(label: title, description: description) {
            TextField(title, text: text)
                .onChange(of: text.wrappedValue) { _, _ in
                    Task { await viewModel.saveStructuredConfig() }
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }

    private func roleTextFieldRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 180, alignment: .leading)
            Spacer(minLength: 12)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360, alignment: .trailing)
        }
    }

    private func roleEnumPickerField(
        label: String,
        selection: Binding<String>,
        key: String,
        options: [String]
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 180, alignment: .leading)
            Spacer(minLength: 12)
            Picker("", selection: selection) {
                Text(localizedOptionLabel(key: key, value: "")).tag("")
                ForEach(options, id: \.self) { value in
                    Text(localizedOptionLabel(key: key, value: value)).tag(value)
                }
            }
            .onChange(of: selection.wrappedValue) { _, _ in
                Task { await viewModel.saveStructuredConfig() }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 260, alignment: .trailing)
        }
    }

    private func numericInputRow(label: String, text: Binding<String>) -> some View {
        return alignedConfigRow(label: label) {
            TextField("", text: text)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue {
                        text.wrappedValue = filtered
                        return
                    }
                    Task { await viewModel.saveStructuredConfig() }
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }

    private func commonOptionPickerRow(
        title: String,
        selection: Binding<String>,
        description: String? = nil,
        options: [String]
    ) -> some View {
        alignedConfigRow(label: title, description: description) {
            Picker("", selection: selection) {
                Text(localizedOptionLabel(key: title, value: "")).tag("")
                ForEach(options, id: \.self) { value in
                    Text(localizedOptionLabel(key: title, value: value)).tag(value)
                }
            }
            .onChange(of: selection.wrappedValue) { _, _ in
                Task { await viewModel.saveStructuredConfig() }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private func alignedConfigRow<Control: View>(
        label: String,
        description: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 12)
            control()
                .frame(minWidth: 200, maxWidth: 420, alignment: .trailing)
        }
    }

    private func mergedOptions(current: String, defaults: [String]) -> [String] {
        var options = defaults
        let normalized = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty && !options.contains(normalized) {
            options.insert(normalized, at: 0)
        }
        return options
    }

    private func localizedOptionLabel(key: String, value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return NSLocalizedString("codex.config.option.unset", value: "Unset", comment: "Unset option")
        }
        let optionKey = "codex.config.option.\(key).\(normalized)"
        return NSLocalizedString(optionKey, value: normalized, comment: "Codex config option value")
    }

    private var runtimeOverviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 160), spacing: 10),
                    GridItem(.flexible(minimum: 160), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                statTile(
                    title: NSLocalizedString("codex.advanced.models_cache.active", value: "Active", comment: "Active model"),
                    value: viewModel.activeModel?.displayName ?? "-"
                )
                statTile(
                    title: NSLocalizedString("codex.advanced.models_cache.total", value: "Total", comment: "Total models"),
                    value: "\(viewModel.visibleModels.count)"
                )
                statTile(
                    title: NSLocalizedString("codex.advanced.models_cache.reasoning_effort", value: "Reasoning Effort", comment: "Reasoning effort title"),
                    value: viewModel.selectedReasoningEffort ?? NSLocalizedString(
                        "codex.advanced.models_cache.reasoning_effort.default",
                        value: "Use Model Default",
                        comment: "Default reasoning effort"
                    )
                )
                statTile(
                    title: NSLocalizedString("codex.advanced.models_cache.meta.fetched_at", value: "Last Fetch", comment: "Last fetch"),
                    value: viewModel.modelsCacheFetchedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-"
                )
            }

            if let sourcePath = viewModel.modelsCacheSourcePath {
                Text(sourcePath)
                    .font(.caption.monospaced())
                    .dsSecondaryText(font: .caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let clientVersion = viewModel.modelsCacheClientVersion, !clientVersion.isEmpty {
                Text("client: \(clientVersion)")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }
        }
    }

    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("codex.advanced.models_cache.title", value: "Models Cache", comment: "Models cache section title"))
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                Spacer(minLength: 0)
                if viewModel.isApplyingModel {
                    ProgressView().controlSize(.small)
                }
            }

            reasoningEffortSection

            if viewModel.models.isEmpty {
                Text(NSLocalizedString(
                    "provider.binary.codex.model.empty",
                    value: "No model list found in models_cache.json. Run Codex CLI once to refresh cache.",
                    comment: "No cached model list"
                ))
                .font(.caption)
                .dsSecondaryText(font: .caption)
            } else {
                let visibleModels = viewModel.visibleModels

                if viewModel.hasHiddenActiveModel {
                    Text(NSLocalizedString(
                        "codex.advanced.models_cache.hidden_active_hint",
                        value: "Current model is hidden from list. Activate a visible model to replace it.",
                        comment: "Hidden active model hint"
                    ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
                }

                alignedConfigRow(label: NSLocalizedString(
                    "codex.advanced.models_cache.column.model",
                    value: "Model",
                    comment: "Model column title"
                )) {
                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.activeModelSlug ?? "" },
                            set: { slug in
                                guard
                                    !slug.isEmpty,
                                    slug != viewModel.activeModelSlug,
                                    let model = visibleModels.first(where: { $0.slug == slug })
                                else { return }
                                Task { await viewModel.activateModel(model) }
                            }
                        )
                    ) {
                        ForEach(visibleModels, id: \.slug) { model in
                            Text(model.displayName).tag(model.slug)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(viewModel.isApplyingModel || visibleModels.isEmpty)
                }
            }
        }
    }

    private var reasoningEffortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            alignedConfigRow(
                label: NSLocalizedString(
                    "codex.advanced.models_cache.reasoning_effort",
                    value: "Reasoning Effort",
                    comment: "Reasoning effort title"
                )
            ) {
                HStack(spacing: 8) {
                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.selectedReasoningEffort ?? "__default__" },
                            set: { value in
                                let effort = value == "__default__" ? nil : value
                                Task { await viewModel.applyReasoningEffort(effort) }
                            }
                        )
                    ) {
                        Text(NSLocalizedString(
                            "codex.advanced.models_cache.reasoning_effort.default",
                            value: "Use Model Default",
                            comment: "Default reasoning effort"
                        ))
                        .tag("__default__")
                        ForEach(viewModel.availableReasoningEfforts, id: \.self) { effort in
                            Text(effort).tag(effort)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(
                        viewModel.availableReasoningEfforts.isEmpty
                        || viewModel.isApplyingReasoning
                        || viewModel.activeModel == nil
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    if viewModel.isApplyingReasoning {
                        ProgressView().controlSize(.small)
                    }
                }
            }

            if viewModel.availableReasoningEfforts.isEmpty {
                Text(NSLocalizedString(
                    "codex.advanced.models_cache.reasoning_effort.unsupported",
                    value: "The active model does not support configurable reasoning effort.",
                    comment: "Reasoning unsupported text"
                ))
                .font(.caption)
                .dsSecondaryText(font: .caption)
            }
        }
    }

    private var xcodeFolderLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString(
                "codex.advanced.xcode_links.desc",
                value: "Link Xcode Codex folders to ~/.codex equivalents.",
                comment: "Xcode links description"
            ))
            .font(.callout)
            .dsSecondaryText(font: .callout)
            .padding(.horizontal, 2)

            ForEach(CodexLinkFolder.allCases) { folder in
                let state = viewModel.linkState(for: folder)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(folder.rawValue.capitalized)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                                Text(linkStatusText(isLinked: state.isLinked))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(
                                        state.isLinked
                                        ? DesignSystem.Colors.Status.success
                                        : DesignSystem.Colors.Text.secondary
                                    )
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        (state.isLinked
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
                                get: { state.isLinked },
                                set: { enabled in
                                    Task { await viewModel.requestSetLink(enabled, folder: folder) }
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(viewModel.applyingLinkFolders.contains(folder))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            Text("~/.codex/\(folder.rawValue)")
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .dsCard(
                            background: DesignSystem.Colors.Background.surface.opacity(0.22),
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                            borderColor: DesignSystem.Colors.Component.border.opacity(0.14)
                        )

                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            Text(displayPath(state.targetURL.path))
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .dsCard(
                            background: DesignSystem.Colors.Background.surface.opacity(0.22),
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                            borderColor: DesignSystem.Colors.Component.border.opacity(0.14)
                        )
                    }

                    if state.hasVisibleEntries {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(NSLocalizedString(
                                "codex.advanced.link.conflict.short",
                                value: "Contains visible files",
                                comment: "Short conflict hint"
                            ))
                            .font(.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.Status.warning)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        Menu {
                            Button(NSLocalizedString("action.show_in_finder", comment: "Show in Finder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([state.targetURL])
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
                .contextMenu {
                    Button(NSLocalizedString("action.show_in_finder", comment: "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([state.targetURL])
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.22), lineWidth: 1)
        )
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

}
