import SwiftUI

/// 引导页 - 完成页面
struct OnboardingCompletionView: View {
    let selectedProviders: [ProviderTemplate]
    let onStart: () -> Void
    
    @State private var showCheckmark = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Success Icon
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                }
                
                // Completion Text
                VStack(spacing: 12) {
                    Text("onboarding.completion.title")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    
                    Text("onboarding.completion.subtitle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 48)
            
            // Summary List
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(String(format: NSLocalizedString("onboarding.completion.providers_configured %d", comment: "Configured count"), selectedProviders.count))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
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
                                .fill(Color.primary.opacity(0.05))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                        )
                    }
                    
                    if selectedProviders.count > 8 {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                            
                            Text("+\(selectedProviders.count - 8)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Start Button
            Button(action: onStart) {
                Text("onboarding.button.start")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 320, height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 60)
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
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingCompletionView(
        selectedProviders: [.claude, .gemini, .opencode],
        onStart: {}
    )
    .frame(width: 800, height: 600)
}
