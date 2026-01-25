import SwiftUI

/// 引导页 - 欢迎页面
struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App Icon Section
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.03))
                        .frame(width: 140, height: 140)
                    
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.1), radius: 15, y: 10)
                }
                
                VStack(spacing: 8) {
                    Text("onboarding.welcome.title")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    
                    Text("onboarding.welcome.subtitle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
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
                    color: .primary
                )
                
                FeatureCard(
                    icon: "link.circle.fill",
                    title: "onboarding.feature.github.title",
                    description: "onboarding.feature.github.description",
                    color: .primary
                )
                
                FeatureCard(
                    icon: "cloud.fill",
                    title: "onboarding.feature.clawdhub.title",
                    description: "onboarding.feature.clawdhub.description",
                    color: .primary
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Buttons
            HStack(spacing: 20) {
                Button(action: onSkip) {
                    Text("onboarding.button.skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, height: 44)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: onGetStarted) {
                    Text("onboarding.button.get_started")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 44)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 60)
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
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingWelcomeView(
        onGetStarted: {},
        onSkip: {}
    )
    .frame(width: 600, height: 500)
}
