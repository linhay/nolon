import SwiftUI

/// 引导页 - 欢迎页面
struct OnboardingWelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App Icon Section
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.Background.elevated.opacity(0.8))
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.Colors.Component.border.opacity(0.25), lineWidth: 1)
                        )
                    
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .shadow(color: DesignSystem.Colors.Text.primary.opacity(0.10), radius: 15, y: 10)
                }
                
                VStack(spacing: 8) {
                    Text("onboarding.welcome.title")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    
                    Text("onboarding.welcome.subtitle")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.bottom, 60)
            
            // Feature Cards
            VStack(spacing: 12) {
                FeatureCard(
                    icon: "brain.head.profile",
                    title: "onboarding.feature.unified.title",
                    description: "onboarding.feature.unified.description",
                    color: DesignSystem.Colors.primary
                )
                
                FeatureCard(
                    icon: "link.circle.fill",
                    title: "onboarding.feature.github.title",
                    description: "onboarding.feature.github.description",
                    color: DesignSystem.Colors.primary
                )
                
                FeatureCard(
                    icon: "cloud.fill",
                    title: "onboarding.feature.clawdhub.title",
                    description: "onboarding.feature.clawdhub.description",
                    color: DesignSystem.Colors.primary
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingWelcomeView()
    .frame(width: 600, height: 500)
}
