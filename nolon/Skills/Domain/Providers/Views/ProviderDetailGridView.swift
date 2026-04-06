import SwiftUI
import AppKit
import ProviderCatalog
import Observation
import STFilePath
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// Detail 区域 - Grid 布局显示 Skills 或 Workflows
struct ProviderDetailGridView: View, DebugPageLocatable {
    @Environment(\.openWindow) private var openWindow
    let provider: Provider?
    let selectedTab: ProviderContentTabType?
    let settings: ProviderSettings
    var refreshTrigger: Int
    var onSelectProvider: ((Provider.ID) -> Void)?
    var onSelectTab: ((ProviderContentTabType) -> Void)?
    var onSelectNolon: (() -> Void)?
    
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
        onSelectTab: ((ProviderContentTabType) -> Void)? = nil,
        onSelectNolon: (() -> Void)? = nil
    ) {
        self.provider = provider
        self.selectedTab = selectedTab
        self.settings = settings
        self.refreshTrigger = refreshTrigger
        self.onSelectProvider = onSelectProvider
        self.onSelectTab = onSelectTab
        self.onSelectNolon = onSelectNolon
        self._viewModel = State(initialValue: ProviderDetailGridViewModel(provider: provider, settings: settings))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.providerDetailItems(provider: provider, selectedTab: selectedTab)
    }
    
    var body: some View {
        NolonUI.ProviderDetailStateContainerView(
            hasProvider: provider != nil,
            hasSelectedTab: selectedTab != nil,
            isLoading: viewModel.isLoading
        ) {
            NolonUI.ProviderDetailPlaceholderView(preset: .noProvider)
            .debugCardLocator([
                PageMarkerItem(title: NSLocalizedString("detail.no_provider", comment: "Select a Provider"))
            ])
        } noTabView: {
            NolonUI.ProviderDetailPlaceholderView(preset: .noTab)
            .debugCardLocator([
                PageMarkerItem(title: NSLocalizedString("detail.select_tab", comment: "Select a Tab"))
            ])
        } content: {
            gridContent
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
            let tabType: ResourceCenterTabID
            switch browserType {
            case .skill:
                tabType = .skills
            case .workflow:
                tabType = .workflows
            case .mcp:
                tabType = .mcps
            }
            ResourceCenterWindowCoordinator.shared.payload = .init(
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
        .alert(
            NSLocalizedString(
                "provider.skills_link.confirm.title",
                value: "Enable Skills Link",
                comment: "Enable skills link confirmation title"
            ),
            isPresented: $viewModel.showingSkillsLinkEnableConfirmation
        ) {
            Button(
                NSLocalizedString(
                    "provider.skills_link.confirm.backup",
                    value: "Backup and Switch",
                    comment: "Backup and switch button"
                )
            ) {
                Task {
                    await viewModel.confirmSkillsLinkEnable(backupExisting: true)
                }
            }
            Button(
                NSLocalizedString(
                    "provider.skills_link.confirm.replace",
                    value: "Switch Without Backup",
                    comment: "Switch without backup button"
                ),
                role: .destructive
            ) {
                Task {
                    await viewModel.confirmSkillsLinkEnable(backupExisting: false)
                }
            }
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.cancelSkillsLinkEnableConfirmation()
            }
        } message: {
            Text(
                String(
                    format: NSLocalizedString(
                        "provider.skills_link.confirm.message",
                        value: "Current skills folder is not empty. Backup will overwrite existing backup at %@.",
                        comment: "Enable skills link confirmation message"
                    ),
                    viewModel.skillsLinkBackupPath ?? "skills.bak"
                )
            )
        }
        .debugPageLocator(debugPageMarkerItems)
    }
    
    @ViewBuilder
    private var gridContent: some View {
        NolonUI.ProviderDetailGridScaffoldView(
            showSearch: shouldShowSearch,
            searchText: $viewModel.searchText,
            showFloatingButton: shouldShowQuickInstallButton,
            searchTrailing: {
                guard let provider else { return AnyView(EmptyView()) }
                if selectedTab == .skills {
                    return AnyView(
                        NolonUI.ProviderSkillsLinkToolbarMenuButton(
                            isEnabled: Binding(
                                get: { viewModel.skillsLinkEnabled },
                                set: { _ in }
                            ),
                            isApplying: viewModel.isApplyingSkillsLink,
                            providerPath: provider.defaultSkillsPath,
                            onShowInFinder: {
                                viewModel.revealSkillsFolderInFinder()
                            },
                            onToggleRequested: { newValue in
                                Task { await viewModel.requestSetSkillsLinkEnabled(newValue) }
                            }
                        )
                    )
                }
                if selectedTab == .mcp, let mcpPath = providerMcpConfigPath {
                    return AnyView(
                        NolonUI.ProviderMCPLinkToolbarMenuButton(
                            isEnabled: Binding(
                                get: { viewModel.mcpLinkEnabled },
                                set: { _ in }
                            ),
                            providerPath: mcpPath,
                            onShowInFinder: {
                                viewModel.revealMcpConfigInFinder()
                            },
                            onToggleRequested: { newValue in
                                Task { await viewModel.requestSetMcpLinkEnabled(newValue) }
                            }
                        )
                    )
                }
                if selectedTab == .agents, provider.templateId == "codex" || provider.templateId == "codexXcode" {
                    return AnyView(
                        NolonUI.ProviderAgentsLinkToolbarMenuButton(
                            isEnabled: Binding(
                                get: { viewModel.agentsLinkEnabled },
                                set: { _ in }
                            ),
                            providerPath: NolonManager.shared.agentsURL.path,
                            onShowInFinder: {
                                viewModel.revealAgentsFolderInFinder()
                            },
                            onToggleRequested: { newValue in
                                Task { await viewModel.requestSetAgentsLinkEnabled(newValue) }
                            }
                        )
                    )
                }
                return AnyView(EmptyView())
            }
        ) { scrollProxy in
            NolonUI.ProviderCodexTopHintsView(
                noticeData: codexXcodeNoticeData,
                linkedHintData: codexLinkedHintData,
                onDismissNotice: {
                    codexXcodeNoticeDismissed = true
                },
                onTapLinkedHint: {
                    guard let selectedTab else { return }
                    handleCodexLinkedHintAction(for: selectedTab)
                }
            )
            resourceHealthSummary(scrollProxy: scrollProxy)
            tabContent
        } floatingButton: {
            quickInstallButton
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
        Self.shouldShowQuickInstallButton(
            selectedTab: selectedTab,
            isCurrentTabLinkedToCodex: isCurrentTabLinkedToCodex,
            skillsLinkEnabled: effectiveSkillsLinkEnabled,
            mcpLinkEnabled: effectiveMcpLinkEnabled,
            agentsLinkEnabled: effectiveAgentsLinkEnabled
        )
    }

    private var effectiveSkillsLinkEnabled: Bool {
        viewModel.skillsLinkEnabled || (provider?.skillsLinkEnabled ?? false)
    }

    private var effectiveMcpLinkEnabled: Bool {
        viewModel.mcpLinkEnabled || (provider?.mcpLinkEnabled ?? false)
    }

    private var effectiveAgentsLinkEnabled: Bool {
        viewModel.agentsLinkEnabled || (provider?.agentsLinkEnabled ?? false)
    }

    private var providerMcpConfigPath: String? {
        guard let provider,
              let templateId = provider.templateId,
              let template = ProviderTemplate(rawValue: templateId),
              template.supportsNativeMcpConfig
        else { return nil }
        return template.defaultMcpConfigPath.path
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
            NolonUI.ProviderResourceHealthSummaryCardView(
                data: .init(
                    warningTitle: NSLocalizedString(
                        "provider.resources.health.warn",
                        value: "Some resources need attention.",
                        comment: "Provider resources warning summary"
                    ),
                    orphanedSkillsText: summary.orphanedSkillCount > 0
                        ? String(
                            format: NSLocalizedString(
                                "provider.resources.health.orphaned_skills_count",
                                value: "orphaned skills %d",
                                comment: "Provider orphaned skills count"
                            ),
                            summary.orphanedSkillCount
                        )
                        : nil,
                    orphanedSkillsHelp: NSLocalizedString(
                        "provider.resources.health.orphaned_skills_scroll",
                        value: "Scroll to first orphaned skill",
                        comment: "Scroll to first orphaned skill help"
                    ),
                    brokenSkillsText: summary.brokenSkillCount > 0
                        ? String(
                            format: NSLocalizedString(
                                "provider.resources.health.broken_skills_count",
                                value: "broken skills %d",
                                comment: "Provider broken skills count"
                            ),
                            summary.brokenSkillCount
                        )
                        : nil,
                    unknownWorkflowsText: summary.unknownWorkflowCount > 0
                        ? String(
                            format: NSLocalizedString(
                                "provider.resources.health.unknown_workflows_count",
                                value: "unknown workflows %d",
                                comment: "Provider unknown workflows count"
                            ),
                            summary.unknownWorkflowCount
                        )
                        : nil,
                    mcpUpdateText: summary.mcpNeedUpdateCount > 0
                        ? String(
                            format: NSLocalizedString(
                                "provider.resources.health.mcp_update_count",
                                value: "MCP cache update %d",
                                comment: "Provider MCP cache update count"
                            ),
                            summary.mcpNeedUpdateCount
                        )
                        : nil
                ),
                onTapOrphanedSkills: {
                    scrollToFirstOrphanedSkill(using: scrollProxy)
                }
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
                if Self.shouldShowNolonSkillsLinkedPlaceholder(
                    skillsLinkEnabled: effectiveSkillsLinkEnabled,
                    selectedTab: selectedTab
                ) {
                    skillsLinkEnabledPlaceholderCard
                } else {
                    NolonUI.ProviderTabSectionView(warningMessage: viewModel.skillsErrorMessage) {
                        NolonUI.ProviderResourceGridSectionView(
                            isEmpty: viewModel.filteredSkills.isEmpty,
                            searchText: viewModel.searchText,
                            kind: .skills,
                            noResultsDescription: "No matching skills found",
                            columns: columns
                        ) {
                            ForEach(viewModel.groupedFilteredSkills, id: \.path) { group in
                                Section {
                                    ForEach(group.skills, id: \.uniqueId) { skill in
                                        NolonUI.SkillCardView(
                                            name: skill.name,
                                            description: skill.description,
                                            version: skill.version,
                                            isOrphaned: skill.installationState == .orphaned,
                                            hasWorkflow: viewModel.workflowIds.contains(skill.id),
                                            referenceCount: skill.referenceCount,
                                            scriptCount: skill.scriptCount,
                                            searchText: viewModel.searchText,
                                            onReveal: { viewModel.revealSkillInFinder(skill) },
                                            onUninstall: { await viewModel.uninstallSkill(skill) },
                                            onLinkWorkflow: { viewModel.linkSkillToWorkflow(skill) },
                                            onUnlinkWorkflow: { viewModel.unlinkSkillFromWorkflow(skill) },
                                            onMigrate: { await viewModel.migrateSkill(skill) },
                                            onTap: { viewModel.selectedSkillForDetail = skill }
                                        ) {
                                            debugPageMarkerMenuItem(
                                                [
                                                    PageMarkerItem(title: provider.displayName),
                                                    PageMarkerItem(title: NSLocalizedString("tab.skills", comment: "Skills")),
                                                    PageMarkerItem(title: skill.name)
                                                ]
                                            )
                                        }
                                        .id(skill.uniqueId)
                                        .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: skill.name)])
                                    }
                                } header: {
                                    NolonUI.ProviderGroupedPathHeaderView(
                                        title: viewModel.displayPath(for: group.path),
                                        columnCount: columns.count
                                    )
                                }
                            }
                        }
                    }
                }
            }
        case .workflows:
            NolonUI.ProviderTabSectionView(warningMessage: viewModel.workflowsErrorMessage) {
                NolonUI.ProviderResourceGridSectionView(
                    isEmpty: viewModel.filteredWorkflows.isEmpty,
                    searchText: viewModel.searchText,
                    kind: .workflows,
                    noResultsDescription: "No matching workflows found",
                    columns: columns
                ) {
                    ForEach(viewModel.filteredWorkflows) { workflow in
                        NolonUI.WorkflowCardView(
                            workflow: workflow,
                            searchText: viewModel.searchText,
                            onReveal: { viewModel.revealWorkflowInFinder(workflow) },
                            onDelete: { await viewModel.deleteWorkflow(workflow) },
                            onTap: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: workflow.path))
                            }
                        ) { workflow in
                            debugPageMarkerMenuItem(
                                [
                                    PageMarkerItem(title: NSLocalizedString("tab.workflows", comment: "Workflows")),
                                    PageMarkerItem(title: workflow.name)
                                ]
                            )
                        }
                        .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: workflow.name)])
                    }
                }
            }
        case .rules:
            NolonUI.ProviderTabSectionView(warningMessage: viewModel.rulesErrorMessage) {
                NolonUI.ProviderResourceGridSectionView(
                    isEmpty: viewModel.filteredRules.isEmpty,
                    searchText: viewModel.searchText,
                    kind: .rules,
                    noResultsDescription: NSLocalizedString(
                        "remote.search.no_results_desc",
                        value: "No matching workflows found",
                        comment: "No search results description"
                    ),
                    columns: columns
                ) {
                    ForEach(viewModel.filteredRules) { rule in
                        NolonUI.RuleCardView(
                            rule: rule,
                            searchText: viewModel.searchText,
                            onReveal: { viewModel.revealRuleInFinder(rule) },
                            onDelete: { await viewModel.deleteRule(rule) },
                            onTap: {
                                editingMarkdownDocument = EditingMarkdownDocument(url: URL(fileURLWithPath: rule.path))
                            }
                        ) { rule in
                            debugPageMarkerMenuItem(
                                [
                                    PageMarkerItem(title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules tab")),
                                    PageMarkerItem(title: rule.name)
                                ]
                            )
                        }
                        .debugCardLocator(debugPageMarkerItems + [PageMarkerItem(title: rule.name)])
                    }
                }
            }
        case .agents:
            if Self.shouldShowNolonAgentsLinkedPlaceholder(
                agentsLinkEnabled: effectiveAgentsLinkEnabled,
                selectedTab: selectedTab
            ) {
                agentsLinkEnabledPlaceholderCard
            } else {
                NolonUI.ProviderTabSectionView(warningMessage: viewModel.agentsErrorMessage) {
                    NolonUI.ProviderResourceGridSectionView(
                        isEmpty: viewModel.filteredAgentsFiles.isEmpty,
                        searchText: viewModel.searchText,
                        kind: .agents,
                        noResultsDescription: NSLocalizedString(
                            "remote.search.no_results_desc",
                            value: "No matching workflows found",
                            comment: "No search results description"
                        ),
                        columns: columns
                    ) {
                        ForEach(viewModel.filteredAgentsFiles) { doc in
                            NolonUI.AgentDocCardView(
                                doc: doc,
                                searchText: viewModel.searchText,
                                onReveal: { viewModel.revealAgentDocInFinder(doc) },
                                onDelete: { await viewModel.deleteAgentDoc(doc) },
                                onTap: {
                                    editingMarkdownDocument = EditingMarkdownDocument(url: URL(fileURLWithPath: doc.path))
                                }
                            ) { doc in
                                debugPageMarkerMenuItem(
                                    [
                                        PageMarkerItem(title: NSLocalizedString("tab.agents", value: "Agents", comment: "Agents tab")),
                                        PageMarkerItem(title: doc.fileName)
                                    ]
                                )
                            }
                        }
                    }
                }
            }
        case .mcp:
            if Self.shouldShowNolonMcpLinkedPlaceholder(
                mcpLinkEnabled: effectiveMcpLinkEnabled,
                selectedTab: selectedTab
            ) {
                mcpLinkEnabledPlaceholderCard
            } else {
                NolonUI.ProviderTabSectionView(warningMessage: viewModel.mcpErrorMessage) {
                    mcpGrid
                }
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

    static func shouldShowNolonSkillsLinkedPlaceholder(
        skillsLinkEnabled: Bool,
        selectedTab: ProviderContentTabType?
    ) -> Bool {
        skillsLinkEnabled && selectedTab == .skills
    }

    static func shouldShowQuickInstallButton(
        selectedTab: ProviderContentTabType?,
        isCurrentTabLinkedToCodex: Bool,
        skillsLinkEnabled: Bool,
        mcpLinkEnabled: Bool,
        agentsLinkEnabled: Bool
    ) -> Bool {
        guard let selectedTab else { return false }
        switch selectedTab {
        case .skills:
            return !isCurrentTabLinkedToCodex && !skillsLinkEnabled
        case .workflows, .rules:
            return !isCurrentTabLinkedToCodex
        case .agents:
            return !isCurrentTabLinkedToCodex && !agentsLinkEnabled
        case .mcp:
            return !mcpLinkEnabled
        default:
            return false
        }
    }

    static func shouldShowNolonAgentsLinkedPlaceholder(
        agentsLinkEnabled: Bool,
        selectedTab: ProviderContentTabType?
    ) -> Bool {
        agentsLinkEnabled && selectedTab == .agents
    }

    static func shouldShowNolonMcpLinkedPlaceholder(
        mcpLinkEnabled: Bool,
        selectedTab: ProviderContentTabType?
    ) -> Bool {
        mcpLinkEnabled && selectedTab == .mcp
    }

    private var skillsLinkEnabledPlaceholderCard: some View {
        VStack(spacing: 16) {
            skillsLinkPlaceholderArtwork

            VStack(spacing: 8) {
                Text(
                    NSLocalizedString(
                        "provider.skills_link.placeholder.title",
                        value: "Skills are linked to Nolon",
                        comment: "Skills link placeholder title"
                    )
                )
                .font(.headline)

                Text(
                    NSLocalizedString(
                        "provider.skills_link.placeholder.description",
                        value: "This provider now uses ~/.nolon/skills. Manage linked skills from the Nolon page.",
                        comment: "Skills link placeholder description"
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                onSelectNolon?()
            } label: {
                Label(
                    NSLocalizedString(
                        "provider.skills_link.placeholder.action",
                        value: "Go to Nolon",
                        comment: "Skills link placeholder action title"
                    ),
                    systemImage: "arrow.up.forward.app"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var skillsLinkPlaceholderArtwork: some View {
        HStack(spacing: 14) {
            placeholderFolderChip(systemImage: "folder", label: "Provider Skills")
            Image(systemName: "link")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            placeholderFolderChip(systemImage: "tray.2.fill", label: "Nolon Skills")
        }
        .padding(.vertical, 6)
    }

    private var mcpLinkEnabledPlaceholderCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                placeholderFolderChip(systemImage: "server.rack", label: "Provider MCP")
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                placeholderFolderChip(systemImage: "externaldrive.connected.to.line.below", label: "Nolon MCP")
            }
            .padding(.vertical, 6)

            VStack(spacing: 8) {
                Text(
                    NSLocalizedString(
                        "provider.mcp_link.placeholder.title",
                        value: "MCP is linked to Nolon",
                        comment: "MCP link placeholder title"
                    )
                )
                .font(.headline)

                Text(
                    NSLocalizedString(
                        "provider.mcp_link.placeholder.description",
                        value: "This provider now uses ~/.nolon/mcps. Manage linked MCP entries from the Nolon page.",
                        comment: "MCP link placeholder description"
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                onSelectNolon?()
            } label: {
                Label(
                    NSLocalizedString(
                        "provider.skills_link.placeholder.action",
                        value: "Go to Nolon",
                        comment: "Skills link placeholder action title"
                    ),
                    systemImage: "arrow.up.forward.app"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var agentsLinkEnabledPlaceholderCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                placeholderFolderChip(systemImage: "doc.text", label: "Provider AGENTS")
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                placeholderFolderChip(systemImage: "folder.badge.person.crop", label: "Nolon AGENTS")
            }
            .padding(.vertical, 6)

            VStack(spacing: 8) {
                Text(
                    NSLocalizedString(
                        "provider.agents_link.placeholder.title",
                        value: "AGENTS docs are linked to Nolon",
                        comment: "Agents link placeholder title"
                    )
                )
                .font(.headline)

                Text(
                    NSLocalizedString(
                        "provider.agents_link.placeholder.description",
                        value: "This provider now uses ~/.nolon/agents. Manage linked AGENTS docs from the Nolon page.",
                        comment: "Agents link placeholder description"
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                onSelectNolon?()
            } label: {
                Label(
                    NSLocalizedString(
                        "provider.skills_link.placeholder.action",
                        value: "Go to Nolon",
                        comment: "Skills link placeholder action title"
                    ),
                    systemImage: "arrow.up.forward.app"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func placeholderFolderChip(systemImage: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.4))
        )
    }

    private var codexXcodeNoticeData: ProviderCodexXcodeNoticeData? {
        guard isCodexXcodeProvider && !codexXcodeNoticeDismissed else { return nil }
        return ProviderCodexXcodeNoticeData(
            title: NSLocalizedString(
                "provider.codex_xcode.notice.title",
                value: "Xcode Built-in Codex",
                comment: "Xcode Codex banner title"
            ),
            description: NSLocalizedString(
                "provider.codex_xcode.notice.desc",
                value: "Uses Xcode's Codex folder at ~/Library/Developer/Xcode/CodingAssistant/codex for skills, workflows, and MCP. Account and usage are managed by Xcode.",
                comment: "Xcode Codex banner description"
            )
        )
    }

    private var quickInstallButton: some View {
        NolonUI.FloatingAccentActionButton {
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
        }
        .padding(32)
    }

    private struct EditingMarkdownDocument: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    private var codexProvider: Provider? {
        settings.providers.first { $0.templateId == "codex" }
    }

    private var codexLinkedHintData: ProviderCodexLinkedHintData? {
        guard isCodexXcodeProvider,
              let selectedTab,
              let folder = codexLinkFolder(for: selectedTab),
              let targetURL = linkedTargetURL(for: folder),
              isTargetLinked(to: codexSourceURL(for: folder), targetURL: targetURL)
        else {
            return nil
        }

        return .init(
            title: NSLocalizedString(
                "provider.codex_xcode.linked_hint.title",
                value: "Linked to Codex",
                comment: "Codex linked hint title"
            ),
            pathText: "~/.codex/\(folder.rawValue)",
            actionTitle: codexProvider == nil
                ? NSLocalizedString(
                    "provider.codex_xcode.linked_hint.add",
                    value: "Add Codex Provider",
                    comment: "Add codex provider quickly"
                )
                : NSLocalizedString(
                    "provider.codex_xcode.linked_hint.jump",
                    value: "Jump to Codex",
                    comment: "Jump to codex provider"
                )
        )
    }

    private func handleCodexLinkedHintAction(for selectedTab: ProviderContentTabType) {
        if let codexProvider {
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
            return
        }

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

    private func codexLinkFolder(for tab: ProviderContentTabType) -> CodexLinkFolder? {
        switch tab {
        case .skills:
            return .skills
        case .workflows:
            return .prompts
        case .rules:
            return .rules
        default:
            return nil
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
