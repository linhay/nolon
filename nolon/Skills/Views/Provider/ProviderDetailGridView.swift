import SwiftUI
import ProviderCatalog
import Observation

/// Detail 区域 - Grid 布局显示 Skills 或 Workflows
struct ProviderDetailGridView: View {
    let provider: Provider?
    let selectedTab: ProviderContentTabType?
    @ObservedObject var settings: ProviderSettings
    var refreshTrigger: Int
    
    @State private var viewModel: ProviderDetailGridViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]
    
    init(provider: Provider?, selectedTab: ProviderContentTabType?, settings: ProviderSettings, refreshTrigger: Int = 0) {
        self.provider = provider
        self.selectedTab = selectedTab
        self.settings = settings
        self.refreshTrigger = refreshTrigger
        self._viewModel = State(initialValue: ProviderDetailGridViewModel(provider: provider, settings: settings))
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
            } else {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label {
                            Text("Error Loading Data")
                                .dsEmptyStateErrorTitle()
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .dsEmptyStateIcon(color: DesignSystem.Colors.Status.error)
                        }
                    } description: {
                        Text(error)
                            .dsSecondaryText(font: .body)
                    }
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
        .sheet(item: $viewModel.selectedSkillForDetail, onDismiss: {
            Task {
                await viewModel.loadData()
            }
        }) { skill in
            SkillDetailView(skill: skill, provider: provider, settings: settings)
                .frame(minWidth: 900, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        }
        .sheet(item: $viewModel.showingRemoteBrowser) { browserType in
            if let provider = provider {
                let tabType: RemoteContentTabType = browserType == .skill ? .skills : (browserType == .workflow ? .workflows : .mcps)
                RemoteSkillsBrowserView(
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
                    }
                )
                .frame(minWidth: 980, idealWidth: 1100, maxWidth: .infinity,
                       minHeight: 700, idealHeight: 760, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                        if isCodexXcodeProvider {
                            codexXcodeNotice
                        }
                        tabContent
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding()
                
                // Floating Action Button - 根据当前 tab 显示
                if selectedTab == .skills || selectedTab == .workflows || selectedTab == .mcp {
                    quickInstallButton
                }
            }
        }
    }

    private var isCodexXcodeProvider: Bool {
        provider?.templateId == "codexXcode"
    }

    private var shouldShowSearch: Bool {
        selectedTab == .skills || selectedTab == .workflows || selectedTab == .mcp
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .skills:
            if let provider = provider {
                ProviderSkillsGridView(viewModel: viewModel, columns: columns, provider: provider)
            }
        case .workflows:
            ProviderWorkflowsGridView(viewModel: viewModel, columns: columns)
        case .mcp:
            mcpGrid
        case .binary:
            if let provider = provider {
                CodexBinaryConfigView(provider: provider)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .accounts:
            if let provider = provider {
                ProviderUsageView(provider: provider)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .usage:
            if let provider = provider {
                ProviderUsageView(provider: provider)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .none:
            EmptyView()
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
            case .mcp:
                viewModel.showingRemoteBrowser = .mcp
            case .binary:
                break
            case .accounts:
                break
            case .usage:
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
    
    @ViewBuilder
    private var mcpGrid: some View {
        ProviderMcpGridView(
            provider: provider,
            viewModel: viewModel,
            columns: columns
        )
    }
}
