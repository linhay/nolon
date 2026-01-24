import SwiftUI
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
                ContentUnavailableView(
                    NSLocalizedString("detail.no_provider", comment: "Select a Provider"),
                    systemImage: "sidebar.left"
                )
            } else if selectedTab == nil {
                ContentUnavailableView(
                    NSLocalizedString("detail.select_tab", comment: "Select a Tab"),
                    systemImage: "list.bullet"
                )
            } else {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Error Loading Data",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
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
    }
    
    @ViewBuilder
    private var gridContent: some View {
        NavigationStack {
            ScrollView {
                switch selectedTab {
                case .skills:
                    if let provider = provider {
                        ProviderSkillsGridView(viewModel: viewModel, columns: columns, provider: provider)
                    }
                case .workflows:
                    ProviderWorkflowsGridView(viewModel: viewModel, columns: columns)
                case .mcp:
                    mcpGrid
                case .none:
                    EmptyView()
                }
            }
            .padding()
            .searchable(text: $viewModel.searchText)
        }
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
