import SwiftUI
import ProviderCatalog
import NolonResourceKit

struct SkillSyncSection: View {
    @Bindable var viewModel: SkillDetailViewModel
    let currentProvider: Provider?
    
    var body: some View {
        Group {
            if let provider = currentProvider {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Synchronization".uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                        .tracking(0.8)
                    
                    HStack {
                        Text("Enable Sync")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { viewModel.isWorkflowLinked },
                            set: { _ in viewModel.toggleWorkflow(for: provider) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    Text("AI will use this skill in \(provider.name)'s workflow.")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}
