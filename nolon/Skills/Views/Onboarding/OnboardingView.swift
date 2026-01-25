import SwiftUI

/// 引导页主容器视图
struct OnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var selectedProviders: Set<ProviderTemplate> = []
    @State private var detectedProviders: Set<ProviderTemplate> = []
    
    var body: some View {
        ZStack {
            // Background Layer
            LiquidBackgroundView()
            
            // Content Layer
            VStack(spacing: 0) {
                // Glass Container
                VStack(spacing: 0) {
                    TabView(selection: $currentStep) {
                        OnboardingWelcomeView(
                            onGetStarted: { withAnimation(.spring()) { currentStep = 1 } },
                            onSkip: onComplete
                        )
                        .tag(0)
                        
                        OnboardingProviderSelectionView(
                            selectedProviders: $selectedProviders,
                            detectedProviders: detectedProviders,
                            onBack: { withAnimation(.spring()) { currentStep = 0 } },
                            onContinue: { withAnimation(.spring()) { currentStep = 2 } }
                        )
                        .tag(1)
                        
                        OnboardingCompletionView(
                            selectedProviders: Array(selectedProviders),
                            onStart: finishOnboarding
                        )
                        .tag(2)
                    }
                    .tabViewStyle(.automatic)
                    
                    // Page indicator inside glass
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index == currentStep ? Color.accentColor : Color.primary.opacity(0.2))
                                .frame(width: index == currentStep ? 20 : 8, height: 8)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .frame(width: 800, height: 600)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(40)
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .onAppear {
            detectInstalledProviders()
        }
    }
    
    /// 检测已安装的 Provider 目录
    @MainActor
    private func detectInstalledProviders() {
        var detected: Set<ProviderTemplate> = []
        let fileManager = FileManager.default
        
        for template in ProviderTemplate.allCases {
            let skillsPath = template.defaultSkillsPath
            let workflowPath = template.defaultWorkflowPath
            
            // 检查是否存在 skills 或 workflow 目录
            if fileManager.fileExists(atPath: skillsPath.path) ||
               fileManager.fileExists(atPath: workflowPath.path) {
                detected.insert(template)
            }
        }
        
        detectedProviders = detected
        selectedProviders = detected
    }
    
    /// 完成引导流程
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

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
