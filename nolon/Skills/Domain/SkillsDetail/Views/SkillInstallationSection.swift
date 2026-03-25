import SwiftUI
import ProviderCatalog
import NolonResourceKit

struct SkillInstallationSection: View {
    @Bindable var viewModel: SkillDetailViewModel
    let providers: [Provider]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installations".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 24)
            
            VStack(spacing: 4) {
                ForEach(providers) { provider in
                    let isInstalled = viewModel.providerInstallationStates[provider.id] ?? false

                    ProviderRow(
                        provider: provider,
                        isInstalled: isInstalled,
                        allowsAction: viewModel.detailMode == .local || !isInstalled
                    ) {
                        Task { await viewModel.performInstallationAction(for: provider) }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct ProviderRow: View {
    let provider: Provider
    let isInstalled: Bool
    let allowsAction: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ProviderLogoView(provider: provider, style: .iconOnly, iconSize: 24)
                    .grayscale(isInstalled ? 0 : 1.0)
                    .opacity(isInstalled ? 1.0 : 0.5)
                    .cornerRadius(5)
                
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isInstalled ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isInstalled ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isInstalled ? DesignSystem.Colors.primary.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isInstalled ? DesignSystem.Colors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!allowsAction)
        .onHover { hovering in
            isHovered = hovering && allowsAction
        }
    }
}
