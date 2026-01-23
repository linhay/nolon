import SwiftUI
import MarkdownUI
import Observation

/// Detailed view for a single skill with 3-column layout
struct SkillDetailView: View {
    @ObservedObject var settings: ProviderSettings
    let provider: Provider? // Context provider
    
    @State private var viewModel: SkillDetailViewModel
    
    init(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: skill, settings: settings))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Column 1: Files Sidebar
            SkillDetailSidebar(viewModel: viewModel)
                .frame(width: 180)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Column 2: Content Preview
            SkillDetailContent(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Column 3: Inspector / Actions
            SkillDetailInspector(viewModel: viewModel, settings: settings, provider: provider)
                .frame(width: 220)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .task {
            await viewModel.loadData(checkProviders: settings.providers, currentProvider: provider)
        }
    }
}
