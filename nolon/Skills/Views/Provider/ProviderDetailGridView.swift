import SwiftUI
import ProviderCatalog
import Observation
import STFilePath
import NolonResourceKit

/// Detail 区域 - Grid 布局显示 Skills 或 Workflows
struct ProviderDetailGridView: View, DebugPageLocatable {
    @Environment(\.openWindow) private var openWindow
    let provider: Provider?
    let selectedTab: ProviderContentTabType?
    let settings: ProviderSettings
    var refreshTrigger: Int
    var onSelectProvider: ((Provider.ID) -> Void)?
    var onSelectTab: ((ProviderContentTabType) -> Void)?
    
    @State private var viewModel: ProviderDetailGridViewModel
    @AppStorage("provider.codex_xcode.notice.dismissed") private var codexXcodeNoticeDismissed = false
    @State private var isAddingCodexProvider = false
    @State private var editingMarkdownDocument: EditingMarkdownDocument?
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]
    
    init(
        provider: Provider?,
        selectedTab: ProviderContentTabType?,
        settings: ProviderSettings,
        refreshTrigger: Int = 0,
        onSelectProvider: ((Provider.ID) -> Void)? = nil,
        onSelectTab: ((ProviderContentTabType) -> Void)? = nil
    ) {
        self.provider = provider
        self.selectedTab = selectedTab
        self.settings = settings
        self.refreshTrigger = refreshTrigger
        self.onSelectProvider = onSelectProvider
        self.onSelectTab = onSelectTab
        self._viewModel = State(initialValue: ProviderDetailGridViewModel(provider: provider, settings: settings))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.providerDetailItems(provider: provider, selectedTab: selectedTab)
    }
    
    var body: some View {
        Group {
            if provider == nil {
                ContentUnavailableView {
                    Label {
                        Text(NSLocalizedString("detail.no_provider", comment: "Select a Provider"))
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "sidebar.left")
                            .dsEmptyStateIcon()
                    }
                }
                .debugCardLocator([
                    PageMarkerItem(title: NSLocalizedString("detail.no_provider", comment: "Select a Provider"))
                ])
            } else if selectedTab == nil {
                ContentUnavailableView {
                    Label {
                        Text(NSLocalizedString("detail.select_tab", comment: "Select a Tab"))
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "list.bullet")
                            .dsEmptyStateIcon()
                    }
                }
                .debugCardLocator([
                    PageMarkerItem(title: NSLocalizedString("detail.select_tab", comment: "Select a Tab"))
                ])
            } else {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    gridContent
                }
            }
        }
        .task(id: "\(provider?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadData()
        }
        .onChange(of: provider) { _, newProvider in
            Task {
                await viewModel.updateProvider(newProvider)
            }
        }
        .onChange(of: viewModel.selectedSkillForDetail?.uniqueId) { _, _ in
            guard let skill = viewModel.selectedSkillForDetail else { return }
            SkillDetailWindowCoordinator.shared.presentLocal(
                skill: skill,
                provider: provider,
                settings: settings
            )
            openWindow(id: SkillDetailWindowCoordinator.windowID)
        }
        .onChange(of: viewModel.showingRemoteBrowser) { _, browserType in
            guard let provider, let browserType else { return }
            let tabType: ResourceContentTabType
            switch browserType {
            case .skill:
                tabType = .skills
            case .workflow:
                tabType = .workflows
            case .mcp:
                tabType = .mcps
            }
            ResourceCenterWindowCoordinator.shared.present(
                payload: .init(
                    settings: settings,
                    repository: viewModel.repository,
                    targetProvider: provider,
                    selectedTab: tabType,
                    onInstall: { skill, provider in
                        Task {
                            await viewModel.installRemoteSkill(skill, to: provider)
                        }
                    },
                    onInstallWorkflow: { workflow, provider in
                        Task {
                            await viewModel.installRemoteWorkflow(workflow, to: provider)
                        }
                    },
                    onInstallMCP: { mcp, provider in
                        Task {
                            await viewModel.installRemoteMCP(mcp, to: provider)
                        }
                    },
                    onRegisterDeleteRequest: nil,
                    onMakeDeleteRequestExecutor: nil,
                    onClose: nil
                )
            )
            openWindow(id: ResourceCenterWindowCoordinator.windowID)
            viewModel.showingRemoteBrowser = nil
        }
        .sheet(isPresented: $isAddingCodexProvider) {
            AddProviderSheet(settings: settings)
        }
        .sheet(item: $editingMarkdownDocument) { editingDocument in
            RuleMarkdownEditorView(ruleURL: editingDocument.url) { _ in
                await viewModel.loadData()
            }
        }
        .debugPageLocator(debugPageMarkerItems)
    }
    
    @ViewBuilder
    private var gridContent: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if shouldShowSearch {
                                HStack {
                                    SearchField(
                                        placeholder: NSLocalizedString("search.placeholder", value: "Search", comment: "Search placeholder"),
                                        text: $viewModel.searchText
                                    )
                                    Spacer()
                                }
                            }
                            if isCodexXcodeProvider && !codexXcodeNoticeDismissed {
                                codexXcodeNotice
                            }
                            codexLinkedHint
                            resourceHealthSummary(scrollProxy: scrollProxy)
                            tabContent
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding()
                }
                
                // Floating Action Button - 根据当前 tab 显示
                if shouldShowQuickInstallButton {
                    quickInstallButton
                }
            }
        }
    }

    private var isCodexXcodeProvider: Bool {
        guard let provider else { return false }
        if provider.templateId == "codexXcode" { return true }
        let expanded = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        return expanded.contains("/Library/Developer/Xcode/CodingAssistant/codex")
    }

    private var shouldShowSearch: Bool {
        selectedTab == .skills || selectedTab == .workflows || selectedTab == .rules || selectedTab == .agents || selectedTab == .mcp
    }

    private var shouldShowQuickInstallButton: Bool {
        guard let selectedTab else { return false }
        switch selectedTab {
        case .skills, .workflows, .rules, .agents:
            return !isCurrentTabLinkedToCodex
        case .mcp:
            return true
        default:
            return false
        }
    }

    private var orphanedSkillCount: Int {
        viewModel.installedSkills.filter { $0.installationState == .orphaned }.count
    }

    private var brokenSkillCount: Int {
        viewModel.installedSkills.filter { $0.installationState == .broken }.count
    }

    private var unknownWorkflowCount: Int {
        viewModel.workflows.filter { $0.source == .unknown }.count
    }

    private var mcpNeedUpdateCount: Int {
        viewModel.mcpCacheStates.values.filter { $0 == .migratedNeedsUpdate }.count
    }

    private struct TabIssueSummary {
        let orphanedSkillCount: Int
        let brokenSkillCount: Int
        let unknownWorkflowCount: Int
        let mcpNeedUpdateCount: Int

        var total: Int {
            orphanedSkillCount + brokenSkillCount + unknownWorkflowCount + mcpNeedUpdateCount
        }
    }

    private var currentTabIssueSummary: TabIssueSummary {
        switch selectedTab {
        case .skills:
            return TabIssueSummary(
                orphanedSkillCount: orphanedSkillCount,
                brokenSkillCount: brokenSkillCount,
                unknownWorkflowCount: 0,
                mcpNeedUpdateCount: 0
            )
        case .workflows:
            return TabIssueSummary(
                orphanedSkillCount: 0,
                brokenSkillCount: 0,
                unknownWorkflowCount: unknownWorkflowCount,
                mcpNeedUpdateCount: 0
            )
        case .mcp:
            return TabIssueSummary(
                orphanedSkillCount: 0,
                brokenSkillCount: 0,
                unknownWorkflowCount: 0,
                mcpNeedUpdateCount: mcpNeedUpdateCount
            )
        default:
            return TabIssueSummary(
                orphanedSkillCount: 0,
                brokenSkillCount: 0,
                unknownWorkflowCount: 0,
                mcpNeedUpdateCount: 0
            )
        }
    }

    @ViewBuilder
    private func resourceHealthSummary(scrollProxy: ScrollViewProxy) -> some View {
        let summary = currentTabIssueSummary
        if summary.total > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignSystem.Colors.Status.warning)
                    Text(
                        NSLocalizedString(
                            "provider.resources.health.warn",
                            value: "Some resources need attention.",
                            comment: "Provider resources warning summary"
                        )
                    )
                    .font(.callout.weight(.semibold))
                }
                HStack(spacing: 12) {
                    if summary.orphanedSkillCount > 0 {
                        Button {
                            scrollToFirstOrphanedSkill(using: scrollProxy)
                        } label: {
                            Text(
                                String(
                                    format: NSLocalizedString(
                                        "provider.resources.health.orphaned_skills_count",
                                        value: "orphaned skills %d",
                                        comment: "Provider orphaned skills count"
                                    ),
                                    summary.orphanedSkillCount
                                ),
                            )
                            .font(.caption)
                            .dsBadge(
                                foreground: DesignSystem.Colors.Status.warning,
                                background: DesignSystem.Colors.Status.warning.opacity(0.14)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(
                            NSLocalizedString(
                                "provider.resources.health.orphaned_skills_scroll",
                                value: "Scroll to first orphaned skill",
                                comment: "Scroll to first orphaned skill help"
                            )
                        )
                    }
                    if summary.brokenSkillCount > 0 {
                        Text(
                            String(
                                format: NSLocalizedString(
                                    "provider.resources.health.broken_skills_count",
                                    value: "broken skills %d",
                                    comment: "Provider broken skills count"
                                ),
                                summary.brokenSkillCount
                            )
                        )
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Status.error,
                            background: DesignSystem.Colors.Status.error.opacity(0.14)
                        )
                    }
                    if summary.unknownWorkflowCount > 0 {
                        Text(
                            String(
                                format: NSLocalizedString(
                                    "provider.resources.health.unknown_workflows_count",
                                    value: "unknown workflows %d",
                                    comment: "Provider unknown workflows count"
                                ),
                                summary.unknownWorkflowCount
                            )
                        )
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle
                        )
                    }
                    if summary.mcpNeedUpdateCount > 0 {
                        Text(
                            String(
                                format: NSLocalizedString(
                                    "provider.resources.health.mcp_update_count",
                                    value: "MCP cache update %d",
                                    comment: "Provider MCP cache update count"
                                ),
                                summary.mcpNeedUpdateCount
                            )
                        )
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.secondary,
                            background: DesignSystem.Colors.secondary.opacity(0.14)
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .dsCard(
                background: DesignSystem.Colors.Status.warning.opacity(0.08),
                cornerRadius: DesignSystem.Metrics.cornerRadiusM,
                borderColor: DesignSystem.Colors.Status.warning.opacity(0.25),
                borderWidth: 1
            )
        }
    }

    private func scrollToFirstOrphanedSkill(using scrollProxy: ScrollViewProxy) {
        guard selectedTab == .skills else { return }
        guard let targetID = Self.firstOrphanedSkillScrollID(from: viewModel.groupedFilteredSkills) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollProxy.scrollTo(targetID, anchor: .center)
        }
    }

    static func firstOrphanedSkillScrollID(from groupedSkills: [(path: String, skills: [Skill])]) -> String? {
        groupedSkills.lazy
            .flatMap(\.skills)
            .first(where: { $0.installationState == .orphaned })?
            .uniqueId
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .skills:
            if let provider = provider {
                VStack(alignment: .leading, spacing: 12) {
                    warningCard(viewModel.skillsErrorMessage)
                    ProviderSkillsGridView(
                        viewModel: viewModel,
                        columns: columns,
                        provider: provider,
                        markerBaseItems: debugPageMarkerItems
                    )
                }
            }
        case .workflows:
            VStack(alignment: .leading, spacing: 12) {
                warningCard(viewModel.workflowsErrorMessage)
                ProviderWorkflowsGridView(
                    viewModel: viewModel,
                    columns: columns,
                    markerBaseItems: debugPageMarkerItems
                )
            }
        case .rules:
            VStack(alignment: .leading, spacing: 12) {
                warningCard(viewModel.rulesErrorMessage)
                ProviderRulesGridView(
                    viewModel: viewModel,
                    columns: columns,
                    markerBaseItems: debugPageMarkerItems
                ) { rule in
                    editingMarkdownDocument = EditingMarkdownDocument(url: URL(fileURLWithPath: rule.path))
                }
            }
        case .agents:
            VStack(alignment: .leading, spacing: 12) {
                warningCard(viewModel.agentsErrorMessage)
                ProviderAgentsGridView(viewModel: viewModel, columns: columns) { doc in
                    editingMarkdownDocument = EditingMarkdownDocument(url: URL(fileURLWithPath: doc.path))
                }
            }
        case .mcp:
            VStack(alignment: .leading, spacing: 12) {
                warningCard(viewModel.mcpErrorMessage)
                mcpGrid
            }
        case .binary:
            if let provider = provider {
                CodexBinaryConfigView(provider: provider)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .advanced:
            if let provider = provider {
                CodexAdvancedConfigView(
                    provider: provider,
                    markerBaseItems: debugPageMarkerItems
                )
                    .id(provider.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .accounts:
            if let provider = provider {
                ProviderUsageView(provider: provider)
                    .debugCardLocator(debugPageMarkerItems)
                    .id(provider.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .usage:
            if let provider = provider {
                ProviderUsageView(provider: provider)
                    .debugCardLocator(debugPageMarkerItems)
                    .id(provider.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .runtime:
            if let provider = provider {
                CodexRuntimeTabView(provider: provider)
                    .id(provider.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func warningCard(_ message: String?) -> some View {
        if let message, !message.isEmpty {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
                Text(message)
                    .font(.callout)
                    .dsSecondaryText(font: .callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .dsCard(
                background: DesignSystem.Colors.Status.warning.opacity(0.08),
                cornerRadius: DesignSystem.Metrics.cornerRadiusM,
                borderColor: DesignSystem.Colors.Status.warning.opacity(0.25),
                borderWidth: 1
            )
        }
    }

    private var codexXcodeNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.Status.info)

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString(
                    "provider.codex_xcode.notice.title",
                    value: "Xcode Built-in Codex",
                    comment: "Xcode Codex banner title"
                ))
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(NSLocalizedString(
                    "provider.codex_xcode.notice.desc",
                    value: "Uses Xcode's Codex folder at ~/Library/Developer/Xcode/CodingAssistant/codex for skills, workflows, and MCP. Account and usage are managed by Xcode.",
                    comment: "Xcode Codex banner description"
                ))
                .font(.callout)
                .dsSecondaryText(font: .callout)
            }

            Spacer(minLength: 0)
            Button {
                codexXcodeNoticeDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .padding(6)
                    .background(DesignSystem.Colors.Component.controlFillSubtle, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }

    private var quickInstallButton: some View {
        Button {
            switch selectedTab {
            case .skills:
                viewModel.showingRemoteBrowser = .skill
            case .workflows:
                viewModel.showingRemoteBrowser = .workflow
            case .rules:
                if let url = viewModel.createRuleDraft() {
                    editingMarkdownDocument = EditingMarkdownDocument(url: url)
                }
            case .agents:
                if let url = viewModel.createAgentDocDraft() {
                    editingMarkdownDocument = EditingMarkdownDocument(url: url)
                }
            case .mcp:
                viewModel.showingRemoteBrowser = .mcp
            case .binary:
                break
            case .advanced:
                break
            case .accounts:
                break
            case .usage:
                break
            case .runtime:
                break
            case .none:
                break
            }
        } label: {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 56, height: 56)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.onAccent)
            }
        }
        .dsLinkButton()
        .padding(32)
    }

    private struct EditingMarkdownDocument: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    private var codexProvider: Provider? {
        settings.providers.first { $0.templateId == "codex" }
    }

    private var codexLinkedHint: some View {
        Group {
            guard isCodexXcodeProvider else { return AnyView(EmptyView()) }
            guard let selectedTab else { return AnyView(EmptyView()) }
            let folder: CodexLinkFolder?
            switch selectedTab {
            case .skills:
                folder = .skills
            case .workflows:
                folder = .prompts
            case .rules:
                folder = .rules
            case .agents:
                folder = nil
            default:
                folder = nil
            }
            guard let folder,
                  let targetURL = linkedTargetURL(for: folder),
                  isTargetLinked(to: codexSourceURL(for: folder), targetURL: targetURL) else {
                return AnyView(EmptyView())
            }

            return AnyView(
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString(
                            "provider.codex_xcode.linked_hint.title",
                            value: "Linked to Codex",
                            comment: "Codex linked hint title"
                        ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text("~/.codex/\(folder.rawValue)")
                            .font(.caption.monospaced())
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }

                    Spacer(minLength: 0)
                    if let codexProvider {
                        Button(NSLocalizedString(
                            "provider.codex_xcode.linked_hint.jump",
                            value: "Jump to Codex",
                            comment: "Jump to codex provider"
                        )) {
                            onSelectProvider?(codexProvider.id)
                            if selectedTab == .skills {
                                onSelectTab?(.skills)
                            } else if selectedTab == .workflows {
                                onSelectTab?(.workflows)
                            } else if selectedTab == .rules {
                                onSelectTab?(.rules)
                            } else if selectedTab == .agents {
                                onSelectTab?(.agents)
                            }
                        }
                        .dsPrimaryButton()
                    } else {
                        Button(NSLocalizedString(
                            "provider.codex_xcode.linked_hint.add",
                            value: "Add Codex Provider",
                            comment: "Add codex provider quickly"
                        )) {
                            if let template = ProviderTemplate(rawValue: "codex") {
                                let newProvider = template.createProvider()
                                settings.addProvider(newProvider)
                                onSelectProvider?(newProvider.id)
                                if selectedTab == .skills {
                                    onSelectTab?(.skills)
                                } else if selectedTab == .workflows {
                                    onSelectTab?(.workflows)
                                } else if selectedTab == .rules {
                                    onSelectTab?(.rules)
                                } else if selectedTab == .agents {
                                    onSelectTab?(.agents)
                                }
                            } else {
                                isAddingCodexProvider = true
                            }
                        }
                        .dsPrimaryButton()
                    }
                }
                .padding(12)
                .dsCard(
                    background: DesignSystem.Colors.Background.elevated,
                    cornerRadius: DesignSystem.Metrics.cornerRadiusM,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
                )
            )
        }
    }

    private var isCurrentTabLinkedToCodex: Bool {
        guard isCodexXcodeProvider, let selectedTab else { return false }
        let folder: CodexLinkFolder?
        switch selectedTab {
        case .skills:
            folder = .skills
        case .workflows:
            folder = .prompts
        case .rules:
            folder = .rules
        case .agents:
            folder = nil
        default:
            folder = nil
        }
        guard let folder,
              let targetURL = linkedTargetURL(for: folder) else { return false }
        return isTargetLinked(to: codexSourceURL(for: folder), targetURL: targetURL)
    }

    private func linkedTargetURL(for folder: CodexLinkFolder) -> URL? {
        guard let provider else { return nil }
        switch folder {
        case .skills:
            return URL(fileURLWithPath: provider.defaultSkillsPath, isDirectory: true)
        case .prompts:
            return URL(fileURLWithPath: provider.workflowPath, isDirectory: true)
        case .rules:
            return provider.codexRulesURL
        }
    }

    private func codexSourceURL(for folder: CodexLinkFolder) -> URL {
        STFolder("\(NSHomeDirectory())/.codex")
            .url
            .appendingPathComponent(folder.rawValue, isDirectory: true)
    }

    private func isTargetLinked(to sourceURL: URL, targetURL: URL) -> Bool {
        let targetPath = STPath(targetURL)
        guard targetPath.isSymbolicLink else {
            return false
        }
        do {
            let resolved = try targetPath.destinationOfSymbolicLink().url.standardizedFileURL
            return resolved.path == sourceURL.standardizedFileURL.path
        } catch {
            return false
        }
    }
    
    @ViewBuilder
    private var mcpGrid: some View {
        ProviderMcpGridView(
            provider: provider,
            viewModel: viewModel,
            columns: columns,
            markerBaseItems: debugPageMarkerItems
        )
    }
}
