import SwiftUI
import Sparkle

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case display = "Display"
    case about = "About"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general: NSLocalizedString("settings.category.general", value: "General", comment: "Category")
        case .display: NSLocalizedString("settings.category.display", value: "Display", comment: "Category")
        case .about: NSLocalizedString("settings.category.about", value: "About", comment: "Category")
        }
    }
}

struct AppSettingsView: View {
    @State private var appSettings = AppSettings.shared
    @State private var selectedCategory: SettingsCategory = .general
    
    var body: some View {
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
            .background(Color.primary.opacity(0.02))
            
            Divider()
                .opacity(0.1)
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(NSLocalizedString("settings.title", value: "Settings", comment: "Title"))
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        contentForSelectedCategory
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 480)
    }
    
    private func categoryRow(category: SettingsCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button(action: { selectedCategory = category }) {
            Text(category.displayName)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var contentForSelectedCategory: some View {
        switch selectedCategory {
        case .general:
            GeneralSettingsView(settings: $appSettings)
        case .display:
            DisplaySettingsView(settings: $appSettings)
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - Subviews

private struct GeneralSettingsView: View {
    @Binding var settings: AppSettings
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Renamed from Workspace to Project Configuration (项目配置)
            settingsSection(title: NSLocalizedString("settings.project_configuration.title", value: "Project Configuration", comment: "Section title")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.workspace.current", value: "Current Workspace", comment: "Label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(settings.workspacePath)
                            .font(.system(size: 13, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            
            settingsSection(title: NSLocalizedString("settings.importing.title", value: "Importing", comment: "Section title")) {
                Button(action: {
                    withAnimation(.spring()) {
                        hasCompletedOnboarding = false
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(NSLocalizedString("settings.onboarding.rerun", value: "Run onboarding again", comment: "Button"))
                        Spacer()
                        Text(NSLocalizedString("settings.onboarding.description", value: "Refresh agents & project picks", comment: "Description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DisplaySettingsView: View {
    @Binding var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsSection(title: NSLocalizedString("settings.appearance", value: "Appearance", comment: "Section title")) {
                VStack(spacing: 0) {
                    ForEach(AppSettings.Appearance.allCases) { appearance in
                        appearanceRow(appearance: appearance)
                    }
                }
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
            }
            
            settingsSection(title: NSLocalizedString("settings.language", value: "Language", comment: "Section title")) {
                VStack(spacing: 0) {
                    ForEach(AppSettings.Language.allCases) { language in
                        languageRow(language: language)
                    }
                }
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
    
    private func appearanceRow(appearance: AppSettings.Appearance) -> some View {
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
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                            .background(Color.accentColor.opacity(0.05))
                            .shadow(color: Color.accentColor.opacity(0.2), radius: 8)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
    
    private func languageRow(language: AppSettings.Language) -> some View {
        let isSelected = settings.language == language
        
        return Button(action: { settings.language = language }) {
            HStack(spacing: 16) {
                Text(language.displayName)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                            .background(Color.accentColor.opacity(0.05))
                    }
                }
            )
        }
        .buttonStyle(.plain)
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
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(NSLocalizedString("settings.about.description", value: "Desktop workspace for managing agent assets and distributing skills, memory docs, and sync rules.", comment: "About text"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(12)
            
            // Integrated update check
            Button(action: { 
                // Sparkle check for updates
                nolonApp.updaterController?.updater.checkForUpdates()
            }) {
                HStack {
                    Text(NSLocalizedString("settings.about.check_updates", value: "Check for updates", comment: "Button"))
                    Spacer()
                    Image(systemName: "arrow.up.circle")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
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
