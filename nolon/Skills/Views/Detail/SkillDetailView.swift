import SwiftUI
import ProviderCatalog
import NolonResourceKit

struct SkillDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel
    private let providers: [Provider]
    private let currentProvider: Provider?

    init(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        self.currentProvider = provider
        self.providers = settings.providers
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: skill, settings: settings))
    }

    init(
        remoteSkill: RemoteSkill,
        providers: [Provider],
        targetProvider: Provider? = nil,
        onInstall: @escaping (Provider) -> Void
    ) {
        self.currentProvider = nil
        self.providers = targetProvider.map { [$0] } ?? providers
        self._viewModel = State(
            initialValue: SkillDetailViewModel(
                remoteSkill: remoteSkill,
                onInstall: { _, provider in
                    onInstall(provider)
                }
            )
        )
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1. Two-Column Layout
            HStack(spacing: 0) {
                // Left Sidebar
                SkillDetailSidebar(
                    viewModel: viewModel,
                    providers: providers,
                    currentProvider: currentProvider
                )
                
                // Right Content Area
                SkillDetailContent(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 2. Floating Close Button
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .background(DesignSystem.Colors.Background.canvas)
        .ignoresSafeArea()
        .task {
            await viewModel.loadData(checkProviders: providers, currentProvider: currentProvider)
        }
    }
}
