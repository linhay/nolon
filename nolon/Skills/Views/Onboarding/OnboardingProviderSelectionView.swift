import SwiftUI
import ProviderCatalog

/// 引导页 - Provider 选择页面
struct OnboardingProviderSelectionView: View {
    @Binding var selectedProviders: Set<ProviderTemplate>
    let detectedProviders: Set<ProviderTemplate>
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("onboarding.provider.title")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                
                Text(detectedProviders.isEmpty 
                     ? "onboarding.provider.subtitle"
                     : "onboarding.provider.subtitle_detected")
                    .font(.system(size: 14))
                    .dsSecondaryText(font: .system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)
            
            // Provider Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ProviderTemplate.allCases) { template in
                        ProviderSelectionCard(
                            template: template,
                            isSelected: selectedProviders.contains(template),
                            isDetected: detectedProviders.contains(template),
                            onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedProviders.contains(template) {
                                        selectedProviders.remove(template)
                                    } else {
                                        selectedProviders.insert(template)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

private struct ProviderSelectionCard: View {
    let template: ProviderTemplate
    let isSelected: Bool
    let isDetected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 12) {
                // Logo Container
                ProviderLogoView(
                    name: template.displayName,
                    logoName: template.logoFile,
                    iconSize: 32
                )
                .grayscale(isSelected ? 0 : 1)
                .opacity(isSelected ? 1 : 0.6)
                
                // Name & Status
                VStack(spacing: 4) {
                    Text(template.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                        .lineLimit(1)
                    
                    if isDetected {
                        Text("onboarding.provider.detected")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.primary.opacity(0.12))
                            .foregroundStyle(DesignSystem.Colors.primary)
                            .cornerRadius(DesignSystem.Metrics.cornerRadiusXS)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.10) : DesignSystem.Colors.Background.surface.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? DesignSystem.Colors.primary.opacity(0.35) : DesignSystem.Colors.Component.border.opacity(0.22), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .dsLinkButton()
    }
}

#Preview {
    OnboardingProviderSelectionView(
        selectedProviders: .constant([.claudeCode, .gemini]),
        detectedProviders: [.claudeCode, .gemini, .opencode]
    )
    .frame(width: 600, height: 500)
}
