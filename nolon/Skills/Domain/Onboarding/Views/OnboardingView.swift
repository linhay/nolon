import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// 引导页主容器视图
struct OnboardingView: View {
    let onComplete: () -> Void
    private let discoveryService = ProviderDiscoveryService()
    
    @State private var step: Step = .welcome
    @State private var selectedProviders: Set<ProviderTemplate> = []
    @State private var detectedProviders: Set<ProviderTemplate> = []
    private let recommendedDefaults: Set<ProviderTemplate> = [.codex, .claudeCode]

    private var templateSections: [ProviderPresentationSections.TemplateSection] {
        ProviderPresentationSections.templateSections()
    }
    
    var body: some View {
        ZStack {
            NolonUI.LiquidBackgroundView()
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
        NolonUI.OnboardingCardScaffold(
            currentStepIndex: step.rawValue,
            totalSteps: Step.allCases.count
        ) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
        } content: {
            stepContent
        } footer: {
            footerContent
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
    }

    @ViewBuilder
    var stepContent: some View {
        switch step {
        case .welcome:
            NolonUI.OnboardingWelcomeView(
                viewModel: NolonUI.OnboardingWelcomeViewViewModel(
                    appIcon: Image(nsImage: NSApp.applicationIconImage)
                )
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
        case .providerSelection:
            NolonUI.OnboardingProviderSelectionView(
                viewModel: NolonUI.OnboardingProviderSelectionViewViewModel(
                    subtitleKey: detectedProviders.isEmpty ? "onboarding.provider.subtitle" : "onboarding.provider.subtitle_detected",
                    sections: templateSections.map { section in
                        .init(
                            id: section.id,
                            title: NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Template section title"),
                            providers: section.templates.map { template in
                                .init(
                                    id: template.rawValue,
                                    name: template.displayName,
                                    logoName: template.logoFile
                                )
                            }
                        )
                    },
                    selectedProviderIDs: Set(selectedProviders.map(\.rawValue)),
                    detectedProviderIDs: Set(detectedProviders.map(\.rawValue)),
                    onToggleProvider: { providerID in
                        guard let template = ProviderTemplate(rawValue: providerID) else { return }
                        if selectedProviders.contains(template) {
                            selectedProviders.remove(template)
                        } else {
                            selectedProviders.insert(template)
                        }
                    }
                )
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
        case .completion:
            NolonUI.OnboardingCompletionView(
                viewModel: NolonUI.OnboardingCompletionViewViewModel(
                    providers: Array(selectedProviders)
                        .sorted { $0.rawValue < $1.rawValue }
                        .map { template in
                            .init(
                                id: template.rawValue,
                                name: template.displayName,
                                logoName: template.logoFile
                            )
                        }
                )
            )
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
        }
    }

    var footerContent: some View {
        NolonUI.OnboardingStepFooterView(
            data: footerData,
            onSkip: onComplete,
            onBack: {
                switch step {
                case .providerSelection:
                    go(to: .welcome)
                case .completion:
                    go(to: .providerSelection)
                case .welcome:
                    break
                }
            },
            onNext: {
                switch step {
                case .welcome:
                    go(to: .providerSelection)
                case .providerSelection:
                    guard !selectedProviders.isEmpty else { return }
                    go(to: .completion)
                case .completion:
                    break
                }
            },
            onStart: finishOnboarding
        )
    }

    private var footerData: OnboardingFooterData {
        OnboardingFooterData(
            step: onboardingStepKind,
            centerHintText: footerCenterHintText,
            centerHintTone: footerCenterHintTone,
            isContinueEnabled: !selectedProviders.isEmpty
        )
    }

    private var onboardingStepKind: OnboardingStepKind {
        switch step {
        case .welcome:
            return .welcome
        case .providerSelection:
            return .providerSelection
        case .completion:
            return .completion
        }
    }

    private var footerCenterHintText: String? {
        guard step == .providerSelection else { return nil }
        if selectedProviders.isEmpty {
            return NSLocalizedString(
                "onboarding.provider.select_at_least_one",
                value: "Select at least one provider.",
                comment: "Onboarding provider minimum selection hint"
            )
        }
        return String.localizedStringWithFormat(
            NSLocalizedString(
                "onboarding.provider.selected_count %d",
                value: "%d selected",
                comment: "Selected provider count"
            ),
            selectedProviders.count
        )
    }

    private var footerCenterHintTone: OnboardingFooterTextTone {
        selectedProviders.isEmpty ? .warning : .primary
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

#Preview {
    OnboardingView {
    }
}
