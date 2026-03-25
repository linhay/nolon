import SwiftUI
import ProviderCatalog

/// 引导页 - 完成页面
struct OnboardingCompletionView: View {
    let selectedProviders: [ProviderTemplate]
    
    @State private var showCheckmark = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Success Icon
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.Status.success.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(DesignSystem.Colors.Status.success)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                }
                
                // Completion Text
                VStack(spacing: 12) {
                    Text("onboarding.completion.title")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    
                    Text("onboarding.completion.subtitle")
                        .font(.system(size: 16))
                        .dsSecondaryText(font: .system(size: 16))
                }
            }
            .padding(.bottom, 48)
            
            // Summary List
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("onboarding.completion.providers_configured \(selectedProviders.count)")
                        .font(.system(size: 14, weight: .bold))
                        .dsSecondaryText(font: .system(size: 14, weight: .bold))
                    Spacer()
                }
                
                HStack(spacing: -8) {
                    ForEach(selectedProviders.prefix(8)) { template in
                        ProviderLogoView(
                            name: template.displayName,
                            logoName: template.logoFile,
                            iconSize: 24
                        )
                        .padding(8)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.Background.elevated.opacity(0.8))
                                .overlay(Circle().stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 2))
                        )
                    }
                    
                    if selectedProviders.count > 8 {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.Background.elevated.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 2))
                            
                            Text("onboarding.completion.more_providers \(selectedProviders.count - 8)")
                                .font(.system(size: 10, weight: .bold))
                                .dsSecondaryText(font: .system(size: 10, weight: .bold))
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("onboarding.completion.tips_title")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    
                    TipRow(icon: "plus", text: "onboarding.completion.tip_add_provider")
                    TipRow(icon: "cloud", text: "onboarding.completion.tip_clawdhub")
                }
            }
            .padding(24)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.Background.surface.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )
            )
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

private struct TipRow: View {
    let icon: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 12))
                .dsSecondaryText(font: .system(size: 12))
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingCompletionView(
        selectedProviders: [.claudeCode, .gemini, .opencode]
    )
    .frame(width: 800, height: 600)
}
