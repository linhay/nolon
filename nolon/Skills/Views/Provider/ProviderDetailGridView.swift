import SwiftUI
import Observation

/// Detail 区域 Grid 视图的 ViewModel
@MainActor
@Observable
final class ProviderDetailGridViewModel {
    var provider: Provider?
    let settings: ProviderSettings
    
    // Skills
    var installedSkills: [Skill] = []
    var selectedSkillForDetail: Skill?
    
    // Workflows
    var workflows: [WorkflowInfo] = []
    var selectedWorkflowForDetail: WorkflowInfo?
    var workflowIds: Set<String> = []
    
    // State
    var isLoading = false
    var errorMessage: String?
    
    // Internals
    private var repository: SkillRepository
    private var installer: SkillInstaller
    
    init(provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        let repo = SkillRepository()
        self.repository = repo
        self.installer = SkillInstaller(repository: repo, settings: settings)
    }
    
    func updateProvider(_ provider: Provider?) async {
        self.provider = provider
        await loadData()
    }
    
    func loadData() async {
        guard let provider = provider else {
            installedSkills = []
            workflows = []
            return
        }
        
        isLoading = true
        
        // Load skills
        do {
            let allSkills = try repository.listSkills()
            let states = try installer.scanProvider(provider: provider)
            let installedIds = Set(states.filter { $0.state == .installed }.map(\.skillName))
            installedSkills = allSkills.filter { installedIds.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        // Load workflows
        loadWorkflows(for: provider)
        
        isLoading = false
    }
    
    private func loadWorkflows(for provider: Provider) {
        let workflowPath = provider.workflowPath
        let url = URL(fileURLWithPath: workflowPath)
        
        guard FileManager.default.fileExists(atPath: workflowPath) else {
            workflows = []
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            workflows = contents
                .filter { $0.pathExtension == "md" }
                .compactMap { WorkflowInfo.parse(from: $0) }
                .sorted { $0.name < $1.name }
            
            workflowIds = Set(workflows.map(\.id))
        } catch {
            workflows = []
        }
    }
    
    // MARK: - Actions
    
    func revealSkillInFinder(_ skill: Skill) {
        guard let provider = provider else { return }
        let path = (provider.skillsPath as NSString).appendingPathComponent(skill.id)
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    
    func uninstallSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        do {
            try installer.uninstall(skill: skill, from: provider)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func linkSkillToWorkflow(_ skill: Skill) {
        guard let provider = provider else { return }
        
        let workflowDir = provider.workflowPath
        let workflowPath = (workflowDir as NSString).appendingPathComponent("\(skill.id).md")
        
        do {
            // Create workflow directory if needed
            if !FileManager.default.fileExists(atPath: workflowDir) {
                try FileManager.default.createDirectory(atPath: workflowDir, withIntermediateDirectories: true)
            }
            
            // Create workflow file
            let content = """
            ---
            description: \(skill.description)
            ---
            
            # \(skill.name)
            
            [Open Skill](nolon://skill/\(skill.id))
            
            """
            try content.write(toFile: workflowPath, atomically: true, encoding: .utf8)
            
            // Reload workflows
            loadWorkflows(for: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func revealWorkflowInFinder(_ workflow: WorkflowInfo) {
        NSWorkspace.shared.selectFile(workflow.path, inFileViewerRootedAtPath: "")
    }
    
    func deleteWorkflow(_ workflow: WorkflowInfo) async {
        do {
            try FileManager.default.removeItem(atPath: workflow.path)
            if let provider = provider {
                loadWorkflows(for: provider)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

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
                .frame(minWidth: 1080, minHeight: 600)
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        ScrollView {
            switch selectedTab {
            case .skills:
                skillsGrid
            case .workflows:
                workflowsGrid
            case .none:
                EmptyView()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var skillsGrid: some View {
        if viewModel.installedSkills.isEmpty {
            ContentUnavailableView(
                NSLocalizedString("skills.empty", comment: "No Skills"),
                systemImage: "square.grid.2x2",
                description: Text(NSLocalizedString("skills.empty_desc", comment: "No skills installed in this provider"))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.installedSkills) { skill in
                    SkillCardView(
                        skill: skill,
                        provider: provider!,
                        hasWorkflow: viewModel.workflowIds.contains(skill.id),
                        onReveal: { viewModel.revealSkillInFinder(skill) },
                        onUninstall: { await viewModel.uninstallSkill(skill) },
                        onLinkWorkflow: { viewModel.linkSkillToWorkflow(skill) },
                        onTap: { viewModel.selectedSkillForDetail = skill }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var workflowsGrid: some View {
        if viewModel.workflows.isEmpty {
            ContentUnavailableView(
                NSLocalizedString("workflows.empty", comment: "No Workflows"),
                systemImage: "arrow.triangle.branch",
                description: Text(NSLocalizedString("workflows.empty_desc", comment: "No workflows in this provider"))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.workflows) { workflow in
                    WorkflowCardView(
                        workflow: workflow,
                        onReveal: { viewModel.revealWorkflowInFinder(workflow) },
                        onDelete: { await viewModel.deleteWorkflow(workflow) },
                        onTap: {
                            // Open workflow file in default editor
                            NSWorkspace.shared.open(URL(fileURLWithPath: workflow.path))
                        }
                    )
                }
            }
        }
    }
}
