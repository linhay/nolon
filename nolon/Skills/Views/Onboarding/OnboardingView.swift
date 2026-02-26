import SwiftUI
import ProviderCatalog
import NolonResourceKit

/// 引导页主容器视图
struct OnboardingView: View {
    let onComplete: () -> Void
    private let discoveryService = ProviderDiscoveryService()
    
    @State private var step: Step = .welcome
    @State private var selectedProviders: Set<ProviderTemplate> = []
    @State private var detectedProviders: Set<ProviderTemplate> = []
    private let recommendedDefaults: Set<ProviderTemplate> = [.codex, .claudeCode]
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
            onboardingCard
        }
        .frame(minWidth: 900, minHeight: 700)
        .onAppear {
            detectInstalledProviders()
        }
    }
    
    /// 检测已安装的 Provider 目录
    @MainActor
    private func detectInstalledProviders() {
        let detected = discoveryService.detectInstalledProviders()
        detectedProviders = detected
        selectedProviders = detected.isEmpty ? recommendedDefaults : detected
    }
    
    /// 完成引导流程
    @MainActor
    private func finishOnboarding() {
        // 创建选中的 Providers
        let settings = ProviderSettings.shared
        
        // 清除现有的默认 providers
        settings.providers.removeAll()
        
        // 添加用户选择的 providers
        for template in selectedProviders {
            let provider = template.createProvider()
            settings.addProvider(provider)
        }
        
        onComplete()
    }
}

// MARK: - Subviews

private extension OnboardingView {
    var onboardingCard: some View {
        VStack(spacing: 0) {
            header
            
            ZStack {
                switch step {
                case .welcome:
                    OnboardingWelcomeView()
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                case .providerSelection:
                    OnboardingProviderSelectionView(
                        selectedProviders: $selectedProviders,
                        detectedProviders: detectedProviders
                    )
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                case .completion:
                    OnboardingCompletionView(selectedProviders: Array(selectedProviders).sorted { $0.rawValue < $1.rawValue })
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            footer
        }
        .frame(width: 840, height: 620)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                )
        )
        .shadow(color: DesignSystem.Colors.Text.primary.opacity(0.10), radius: 40, x: 0, y: 20)
        .padding(40)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
    }
    
    var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
            
            progressIndicator
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }
    
    var progressIndicator: some View {
        HStack(spacing: 10) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s == step ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35))
                    .frame(width: s == step ? 20 : 8, height: 8)
            }
        }
    }
    
    var footer: some View {
        HStack(spacing: 12) {
            switch step {
            case .welcome:
                Button(action: onComplete) {
                    Text("onboarding.button.skip")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
                
                Spacer()
                
                Button(action: { go(to: .providerSelection) }) {
                    Text("onboarding.button.get_started")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                
            case .providerSelection:
                Button(action: { go(to: .welcome) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("onboarding.button.back")
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
                
                Spacer()

                if selectedProviders.isEmpty {
                    Text(
                        NSLocalizedString(
                            "onboarding.provider.select_at_least_one",
                            value: "Select at least one provider.",
                            comment: "Onboarding provider minimum selection hint"
                        )
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
                } else {
                    Text("onboarding.provider.selected_count \(selectedProviders.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
                
                Spacer()
                
                Button(action: { go(to: .completion) }) {
                    HStack(spacing: 8) {
                        Text("onboarding.button.continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: !selectedProviders.isEmpty))
                .disabled(selectedProviders.isEmpty)
                
            case .completion:
                Button(action: { go(to: .providerSelection) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("onboarding.button.back")
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
                
                Spacer()
                
                Button(action: finishOnboarding) {
                    Text("onboarding.button.start")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.55))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(DesignSystem.Colors.Component.separator.opacity(0.25)),
                    alignment: .top
                )
        )
    }
    
    func go(to newStep: Step) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = newStep
        }
    }
}

// MARK: - Types

private enum Step: Int, CaseIterable, Hashable {
    case welcome
    case providerSelection
    case completion
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DesignSystem.Colors.Background.surface)
            .frame(height: 44)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                    .fill(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.35))
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsSecondaryText(font: .body)
            .frame(height: 44)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.Component.border.opacity(0.20), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    OnboardingView {
    }
}
