import SwiftUI
import ProviderCatalog
import MarkdownUI
import Observation
import NolonResourceKit

/// Detailed view for a single skill with 3-column layout
struct SkillDetailView: View {
    @ObservedObject var settings: ProviderSettings
    let provider: Provider? // Context provider
    
    @State private var viewModel: SkillDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: skill, settings: settings))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: viewModel.skill.name) {
                dismiss()
            }

            SheetDivider()

            HStack(spacing: 0) {
                // Column 1: Files Sidebar
                SkillDetailSidebar(viewModel: viewModel)
                    .frame(width: 180)
                    .background(DesignSystem.Colors.Background.elevated)

                Divider()

                // Column 2: Content Preview
                SkillDetailContent(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Colors.Background.surface)

                Divider()

                // Column 3: Inspector / Actions
                SkillDetailInspector(viewModel: viewModel, settings: settings, provider: provider)
                    .frame(width: 220)
                    .background(DesignSystem.Colors.Background.elevated)
            }
        }
        .task {
            await viewModel.loadData(checkProviders: settings.providers, currentProvider: provider)
        }
    }
}
