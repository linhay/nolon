import SwiftUI

/// 引导页 - Provider 选择页面
struct OnboardingProviderSelectionView: View {
    @Binding var selectedProviders: Set<ProviderTemplate>
    let detectedProviders: Set<ProviderTemplate>
    let onBack: () -> Void
    let onContinue: () -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("onboarding.provider.title")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text(detectedProviders.isEmpty 
                     ? "onboarding.provider.subtitle"
                     : "onboarding.provider.subtitle_detected")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
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
            
            Spacer(minLength: 20)
            
            Divider()
                .background(Color.primary.opacity(0.05))
            
            // Bottom Bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("onboarding.button.back")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("onboarding.provider.selected_count \(selectedProviders.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedProviders.isEmpty ? .secondary : Color.accentColor)
                
                Spacer()
                
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("onboarding.button.continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 40)
                    .background(
                        selectedProviders.isEmpty 
                        ? Color.primary.opacity(0.1)
                        : Color.accentColor
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(selectedProviders.isEmpty)
            }
            .padding(24)
            .background(.ultraThinMaterial)
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
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    
                    if isDetected {
                        Text("onboarding.provider.detected")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.05) : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingProviderSelectionView(
        selectedProviders: .constant([.claude, .gemini]),
        detectedProviders: [.claude, .gemini, .opencode],
        onBack: {},
        onContinue: {}
    )
    .frame(width: 600, height: 500)
}
