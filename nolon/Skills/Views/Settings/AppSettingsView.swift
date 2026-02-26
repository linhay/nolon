import Foundation
import SwiftUI
import Sparkle
import NolonResourceKit

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case display = "Display"
    case advanced = "Advanced"
    case about = "About"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general: NSLocalizedString("settings.category.general", value: "General", comment: "Category")
        case .display: NSLocalizedString("settings.category.display", value: "Display", comment: "Category")
        case .advanced: NSLocalizedString("settings.category.advanced", value: "Advanced", comment: "Category")
        case .about: NSLocalizedString("settings.category.about", value: "About", comment: "Category")
        }
    }
}

struct AppSettingsView: View {
    @State private var settingsStore = AppSettingsStore.shared
    @State private var selectedCategory: SettingsCategory = .general
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: NSLocalizedString("settings.title", value: "Settings", comment: "Title")) {
                dismiss()
            }

            SheetDivider()

            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsCategory.allCases) { category in
                        categoryRow(category: category)
                    }
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.horizontal, 12)
                .frame(width: 180)
                .background(DesignSystem.Colors.Component.controlFillSubtle.opacity(0.6))

                Divider()
                    .opacity(0.1)

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            contentForSelectedCategory
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
                .background(DesignSystem.Colors.Background.surface)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private func categoryRow(category: SettingsCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button(action: { selectedCategory = category }) {
            Text(category.displayName)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS)
                        .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : Color.clear)
                )
        }
        .dsLinkButton()
    }
    
    @ViewBuilder
    private var contentForSelectedCategory: some View {
        switch selectedCategory {
        case .general:
            GeneralSettingsView(settings: settingsStore)
        case .display:
            DisplaySettingsView(settings: settingsStore)
        case .advanced:
            AdvancedSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - Subviews

private struct GeneralSettingsView: View {
    let settings: AppSettingsStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showingOnboardingResetConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Renamed from Workspace to Project Configuration (项目配置)
            settingsSection(title: NSLocalizedString("settings.project_configuration.title", value: "Project Configuration", comment: "Section title")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.workspace.current", value: "Current Workspace", comment: "Label"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .dsSecondaryText(font: .body)
                        Text(settings.workspacePath)
                            .font(.system(size: 13, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard()
                }
            }
            
            settingsSection(title: NSLocalizedString("settings.importing.title", value: "Importing", comment: "Section title")) {
                Button(action: {
                    showingOnboardingResetConfirm = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(NSLocalizedString("settings.onboarding.rerun", value: "Run onboarding again", comment: "Button"))
                        Spacer()
                        Text(NSLocalizedString("settings.onboarding.description", value: "Refresh agents & project picks", comment: "Description"))
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }
                    .padding(16)
                    .dsCard()
                }
                .dsLinkButton()
                .confirmationDialog(
                    NSLocalizedString(
                        "settings.onboarding.reset.confirm_title",
                        value: "Run onboarding again?",
                        comment: "Onboarding reset confirmation title"
                    ),
                    isPresented: $showingOnboardingResetConfirm
                ) {
                    Button(
                        NSLocalizedString(
                            "settings.onboarding.reset.confirm_action",
                            value: "Run",
                            comment: "Onboarding reset confirmation action"
                        )
                    ) {
                        withAnimation(.spring()) {
                            hasCompletedOnboarding = false
                        }
                    }
                    Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {}
                } message: {
                    Text(
                        NSLocalizedString(
                            "settings.onboarding.reset.confirm_message",
                            value: "This will show onboarding again the next time the main window appears.",
                            comment: "Onboarding reset confirmation message"
                        )
                    )
                }
            }
        }
    }
}

private struct DisplaySettingsView: View {
    let settings: AppSettingsStore
    
    private let supportedLanguages: [AppLanguage] = [
        .simplifiedChinese,
        .english,
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsSection(title: NSLocalizedString("settings.appearance", value: "Appearance", comment: "Section title")) {
                VStack(spacing: 0) {
                    ForEach(AppAppearance.allCases) { appearance in
                        appearanceRow(appearance: appearance)
                    }
                }
                .dsCard()
            }
            
            settingsSection(title: NSLocalizedString("settings.language", value: "Language", comment: "Section title")) {
                VStack(spacing: 0) {
                    ForEach(supportedLanguages) { language in
                        languageRow(language: language)
                    }
                }
                .dsCard()
            }
        }
        .onAppear {
            guard !supportedLanguages.contains(settings.language) else { return }
            
            let preferred = Locale.preferredLanguages.first ?? ""
            if preferred.hasPrefix("zh") {
                settings.language = .simplifiedChinese
            } else {
                settings.language = .english
            }
        }
    }
    
    private func appearanceRow(appearance: AppAppearance) -> some View {
        let isSelected = settings.appearance == appearance
        let icon: String = {
            switch appearance {
            case .light: return "sun.max"
            case .dark: return "moon"
            case .system: return "desktopcomputer"
            }
        }()
        
        return Button(action: { settings.appearance = appearance }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                Text(appearance.displayName)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.primary.opacity(0.5), lineWidth: 2)
                            .background(DesignSystem.Colors.primary.opacity(0.05))
                            .shadow(color: DesignSystem.Colors.primary.opacity(0.2), radius: 8)
                    }
                }
            )
        }
        .dsLinkButton()
    }
    
    private func languageRow(language: AppLanguage) -> some View {
        let isSelected = settings.language == language
        
        return Button(action: { settings.language = language }) {
            HStack(spacing: 16) {
                Text(language.displayName)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
                            .stroke(DesignSystem.Colors.primary.opacity(0.5), lineWidth: 2)
                            .background(DesignSystem.Colors.primary.opacity(0.05))
                    }
                }
            )
        }
        .dsLinkButton()
    }
}

private struct AdvancedSettingsView: View {
    @State private var overwriteExisting = false
    @State private var isRebuildingSkillLock = false
    @State private var rebuildResultMessage: String?
    @State private var rebuildErrorMessage: String?
    @State private var showingRebuildConfirmation = false
    @State private var showingUpdatesSheet = false
    @State private var updateCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsSection(
                title: NSLocalizedString(
                    "settings.advanced.skill_lock.title",
                    value: "Skill Lock",
                    comment: "Section title"
                )
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        NSLocalizedString(
                            "settings.advanced.skill_lock.description",
                            value: "Rebuild the .skill-lock.json file by scanning ~/.nolon/skills. This helps update checking work for existing installations.",
                            comment: "Description"
                        )
                    )
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                    
                    Toggle(
                        NSLocalizedString(
                            "settings.advanced.skill_lock.overwrite",
                            value: "Overwrite existing entries",
                            comment: "Overwrite toggle"
                        ),
                        isOn: $overwriteExisting
                    )
                    
                    Button {
                        showingRebuildConfirmation = true
                    } label: {
                        HStack {
                            if isRebuildingSkillLock {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(
                                NSLocalizedString(
                                    "settings.advanced.skill_lock.rebuild",
                                    value: "Rebuild .skill-lock.json",
                                    comment: "Rebuild action"
                                )
                            )
                            Spacer()
                    }
                    .padding(16)
                    .dsCard()
                }
                .dsLinkButton()
                .disabled(isRebuildingSkillLock)
                    .confirmationDialog(
                        NSLocalizedString(
                            "settings.advanced.skill_lock.confirm_title",
                            value: "Rebuild Skill Lock?",
                            comment: "Confirm title"
                        ),
                        isPresented: $showingRebuildConfirmation
                    ) {
                        Button(
                            NSLocalizedString(
                                "settings.advanced.skill_lock.confirm_action",
                                value: "Rebuild",
                                comment: "Confirm action"
                            )
                        ) {
                            Task { await rebuildSkillLock() }
                        }
                        Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) {}
                    } message: {
                        Text(
                            NSLocalizedString(
                                "settings.advanced.skill_lock.confirm_message",
                                value: "This will scan your global skills folder and write .skill-lock.json. You can keep existing entries or overwrite them.",
                                comment: "Confirm message"
                            )
                        )
                    }
                    
                    if let message = rebuildResultMessage {
                        Text(message)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }
                    
                    if let error = rebuildErrorMessage {
                        Text(error)
                            .dsErrorText(font: .caption)
                    }
                }
            }
            
            settingsSection(
                title: NSLocalizedString(
                    "settings.advanced.updates.title",
                    value: "Updates",
                    comment: "Section title"
                )
            ) {
                Button {
                    showingUpdatesSheet = true
                } label: {
                    HStack {
                        Image(systemName: updateCount > 0 ? "arrow.down.circle.fill" : "arrow.down.circle")
                        Text(
                            NSLocalizedString(
                                "settings.advanced.updates.open",
                                value: "Manage skill updates",
                                comment: "Open updates"
                            )
                        )
                        Spacer()
                        if updateCount > 0 {
                            Text("\(updateCount)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.Status.warning)
                        }
                    }
                    .padding(16)
                    .dsCard()
                }
                .dsLinkButton()
                .sheet(isPresented: $showingUpdatesSheet) {
                    UpdatesView()
                }
                .task {
                    let checker = SkillUpdateChecker()
                    updateCount = await checker.getUpdatableSkillsCount()
                }
            }
        }
    }
    
    @MainActor
    private func rebuildSkillLock() async {
        isRebuildingSkillLock = true
        rebuildResultMessage = NSLocalizedString(
            "settings.advanced.skill_lock.running",
            value: "Rebuilding .skill-lock.json...",
            comment: "Running"
        )
        rebuildErrorMessage = nil
        defer { isRebuildingSkillLock = false }
        
        do {
            let manager = SkillLockFileManager()
            let result = try await manager.rebuildFromGlobalSkills(overwriteExisting: overwriteExisting)
            rebuildResultMessage = String(
                format: NSLocalizedString(
                    "settings.advanced.skill_lock.success",
                    value: "Done. Processed %d, added %d, updated %d, skipped %d.",
                    comment: "Success"
                ),
                result.processedCount,
                result.addedCount,
                result.updatedCount,
                result.skippedCount
            )
        } catch {
            rebuildResultMessage = nil
            rebuildErrorMessage = String(
                format: NSLocalizedString(
                    "settings.advanced.skill_lock.failed",
                    value: "Failed to rebuild: %@",
                    comment: "Failure"
                ),
                error.localizedDescription
            )
        }
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("nolon")
                        .font(.system(size: 15, weight: .bold))
                    
                    // Bundle version
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text(version)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }
                }
                
                Text(NSLocalizedString("settings.about.description", value: "Desktop workspace for managing agent assets and distributing skills, memory docs, and sync rules.", comment: "About text"))
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
            
            // Integrated update check
            Button(action: { 
                // Sparkle check for updates
                nolonApp.updaterController?.updater.checkForUpdates()
            }) {
                HStack {
                    Text(NSLocalizedString("settings.about.check_updates", value: "Check for updates", comment: "Button"))
                    Spacer()
                    Image(systemName: "arrow.up.circle")
                        .dsSecondaryText(font: .body)
                }
                .padding(16)
                .dsCard()
            }
            .dsLinkButton()
        }
    }
}

@ViewBuilder
private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.system(size: 14, weight: .bold))
        content()
    }
}


#Preview {
    AppSettingsView()
}
