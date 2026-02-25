import AppKit
import Observation
import ProviderCatalog
import SwiftUI
import STFilePath
import CodexProvider
import NolonResourceKit

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

    private var provider: Provider
    private let manager: CodexBinaryManager
    private let linkService: CodexLinkService
    private let modelPreferenceService: CodexModelPreferenceService

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

    private func resolvedConfigFile() -> STFile? {
        modelPreferenceService.resolvedConfigFile(for: provider)
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
    let provider: Provider
    @State private var viewModel: CodexAdvancedConfigViewModel

    init(provider: Provider) {
        self.provider = provider
        self._viewModel = State(initialValue: CodexAdvancedConfigViewModel(provider: provider))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(NSLocalizedString("codex.binary.section.preferences", value: "Run Preferences", comment: "Preferences section"))
                combinedPreferencesSection

                if viewModel.isCodexXcodeProvider {
                    sectionHeader(NSLocalizedString("codex.advanced.xcode_links.title", value: "Xcode Folder Links", comment: "Xcode folder links section title"))
                    xcodeFolderLinksSection
                }
            }
            .padding()
        }
        .task(id: provider.id) {
            viewModel.updateProvider(provider)
            await viewModel.load()
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

    private var combinedPreferencesSection: some View {
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

            HStack {
                Spacer(minLength: 0)
                Button(NSLocalizedString("codex.binary.open_config", value: "Open Config", comment: "Open config file")) {
                    viewModel.openModelConfig()
                }
                .dsSecondaryButton()
            }

            availableModelsSection
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
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

            reasoningEffortSection
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

            if viewModel.models.isEmpty {
                Text(NSLocalizedString(
                    "provider.binary.codex.model.empty",
                    value: "No model list found in models_cache.json. Run Codex CLI once to refresh cache.",
                    comment: "No cached model list"
                ))
                .font(.caption)
                .dsSecondaryText(font: .caption)
            } else {
                if viewModel.hasHiddenActiveModel {
                    Text(NSLocalizedString(
                        "codex.advanced.models_cache.hidden_active_hint",
                        value: "Current model is hidden from list. Activate a visible model to replace it.",
                        comment: "Hidden active model hint"
                    ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
                }

                let visibleModels = viewModel.visibleModels
                VStack(spacing: 0) {
                    ForEach(visibleModels, id: \.slug) { model in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.callout)
                                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Spacer(minLength: 0)
                            if viewModel.activeModelSlug == model.slug {
                                Button(NSLocalizedString("codex.advanced.models_cache.activated", value: "Activated", comment: "Activated state")) {}
                                    .dsPrimaryButton()
                                    .disabled(true)
                            } else {
                                Button(NSLocalizedString("codex.advanced.models_cache.activate", value: "Activate", comment: "Activate model")) {
                                    Task { await viewModel.activateModel(model) }
                                }
                                .dsPrimaryButton()
                                .disabled(viewModel.isApplyingModel)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        if model.slug != visibleModels.last?.slug {
                            Divider()
                        }
                    }
                }
                .dsCard(
                    background: DesignSystem.Colors.Background.surface.opacity(0.38),
                    cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.22)
                )

                if let active = viewModel.activeModel {
                    activeModelSummarySection(active)
                }
            }
        }
    }

    private func activeModelSummarySection(_ model: CodexModelsCache.Model) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("codex.advanced.models_cache.detail", value: "Model Details", comment: "Model details title"))
                .font(.callout.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            HStack(spacing: 8) {
                statChip(
                    title: NSLocalizedString("codex.advanced.models_cache.field.default_reasoning_level", value: "Default Reasoning", comment: "Default reasoning level field"),
                    value: model.defaultReasoningLevel ?? "-"
                )
                statChip(
                    title: NSLocalizedString("codex.advanced.models_cache.field.context_window", value: "Context Window", comment: "Context window field"),
                    value: model.contextWindow.map(String.init) ?? "-"
                )
                statChip(
                    title: NSLocalizedString("codex.advanced.models_cache.field.supported_reasoning_levels", value: "Reasoning Levels", comment: "Supported reasoning levels field"),
                    value: model.supportedReasoningLevels.map(\.effort).joined(separator: ", ").nonEmpty ?? "-"
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.3),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.2)
        )
    }

    private var reasoningEffortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(NSLocalizedString(
                    "codex.advanced.models_cache.reasoning_effort",
                    value: "Reasoning Effort",
                    comment: "Reasoning effort title"
                ))
                .font(.callout)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer(minLength: 0)

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

                if viewModel.isApplyingReasoning {
                    ProgressView().controlSize(.small)
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
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.35),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.2)
        )
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.Component.controlFillSubtle.opacity(0.35), in: Capsule())
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
