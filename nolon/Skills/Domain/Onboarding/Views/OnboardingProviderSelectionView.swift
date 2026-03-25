import SwiftUI
import ProviderCatalog
import NolonResourceKit

/// 引导页 - Provider 选择页面
struct OnboardingProviderSelectionView: View {
    @Binding var selectedProviders: Set<ProviderTemplate>
    let detectedProviders: Set<ProviderTemplate>
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    private var templateSections: [ProviderPresentationSections.TemplateSection] {
        ProviderPresentationSections.templateSections()
    }
    
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
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(templateSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(
                                NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Template section title")
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.templates) { template in
                                    GenericSelectionControl(
                                        value: template,
                                        selections: $selectedProviders
                                    ) { isSelected in
                                        ProviderSelectionCard(
                                            template: template,
                                            isSelected: isSelected,
                                            isDetected: detectedProviders.contains(template)
                                        )
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                                    }
                                    .dsLinkButton()
                                }
                            }
                        }
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
    
    var body: some View {
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
}

#Preview {
    OnboardingProviderSelectionView(
        selectedProviders: .constant([.claudeCode, .gemini]),
        detectedProviders: [.claudeCode, .gemini, .opencode]
    )
    .frame(width: 600, height: 500)
}
