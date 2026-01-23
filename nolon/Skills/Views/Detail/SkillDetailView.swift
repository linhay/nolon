import SwiftUI
import MarkdownUI
import Observation

/// Model representing a file in the skill directory
struct SkillFile: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
    let type: SkillFileType
    
    enum SkillFileType {
        case markdown
        case code
        case image
        case other
    }
}

@MainActor
@Observable
final class SkillDetailViewModel {
    // MARK: - State
    var skill: Skill
    var files: [SkillFile] = []
    var selectedFile: SkillFile?
    
    // Provider ID -> Is Installed
    var providerInstallationStates: [String: Bool] = [:]
    
    // Current Provider Workflow State
    var isWorkflowLinked: Bool = false
    
    // MARK: - Dependencies
    private let repository = SkillRepository()
    private let installer: SkillInstaller
    
    init(skill: Skill, settings: ProviderSettings) {
        self.skill = skill
        self.installer = SkillInstaller(repository: repository, settings: settings)
    }
    
    // MARK: - Loading
    
    func loadData(checkProviders: [Provider], currentProvider: Provider?) async {
        loadFiles()
        await checkInstallationStatus(providers: checkProviders)
        if let provider = currentProvider {
            checkWorkflowStatus(for: provider)
        }
    }
    
    private func loadFiles() {
        let rootURL = URL(fileURLWithPath: skill.globalPath)
        var loadedFiles: [SkillFile] = []
        
        // 1. SKILL.md
        let skillMdURL = rootURL.appendingPathComponent("SKILL.md")
        if FileManager.default.fileExists(atPath: skillMdURL.path) {
            loadedFiles.append(SkillFile(name: "SKILL.md", url: skillMdURL, type: .markdown))
        }
        
        // 2. Scan subdirectory
        func scanSubdir(_ name: String) {
            let dirURL = rootURL.appendingPathComponent(name)
            guard let contents = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
            
            for url in contents {
                if url.hasDirectoryPath { continue }
                loadedFiles.append(SkillFile(name: "\(name)/\(url.lastPathComponent)", url: url, type: determineType(url)))
            }
        }
        
        scanSubdir("references")
        scanSubdir("scripts")
        
        self.files = loadedFiles
        if selectedFile == nil {
            selectedFile = loadedFiles.first
        }
    }
    
    private func determineType(_ url: URL) -> SkillFile.SkillFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return .markdown
        case "png", "jpg", "jpeg", "gif": return .image
        case "swift", "js", "py", "sh", "json", "yaml", "yml": return .code
        default: return .other
        }
    }
    
    // MARK: - Installation Logic
    
    func checkInstallationStatus(providers: [Provider]) async {
        // If reloading all (or just checking specific ones), we should probably merge or be careful.
        // But for loadData we want fresh.
        // Let's split this:
        // loadData -> reloadAll
        // toggle -> updateOne
        
        for provider in providers {
            let path = "\(provider.skillsPath)/\(skill.id)"
            let exists = FileManager.default.fileExists(atPath: path)
            providerInstallationStates[provider.id] = exists
        }
    }
    
    func toggleInstallation(for provider: Provider) async {
        let isInstalled = providerInstallationStates[provider.id] ?? false
        
        do {
            if isInstalled {
                try installer.uninstall(skill: skill, from: provider)
            } else {
                try installer.install(skill: skill, to: provider)
            }
            // Update state safely
            await checkInstallationStatus(providers: [provider])
        } catch {
            print("Failed to toggle installation for \(provider.name): \(error)")
        }
    }
    
    // MARK: - Workflow Logic
    
    func checkWorkflowStatus(for provider: Provider) {
        let workflowPath = provider.workflowPath + "/" + skill.id + ".md"
        isWorkflowLinked = FileManager.default.fileExists(atPath: workflowPath)
    }
    
    func toggleWorkflow(for provider: Provider) {
        if isWorkflowLinked {
            deleteWorkflow(for: provider)
        } else {
            createWorkflow(for: provider)
        }
        checkWorkflowStatus(for: provider)
    }
    
    private func createWorkflow(for provider: Provider) {
        do {
            let workflowDir = provider.workflowPath
            if !FileManager.default.fileExists(atPath: workflowDir) {
                try FileManager.default.createDirectory(atPath: workflowDir, withIntermediateDirectories: true)
            }
            
            let content = """
            ---
            description: \(skill.description)
            ---
            
            # \(skill.name)
            
            [Open Skill](nolon://skill/\(skill.id))
            
            """
            let path = provider.workflowPath + "/" + skill.id + ".md"
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create workflow: \(error)")
        }
    }
    
    private func deleteWorkflow(for provider: Provider) {
        do {
            let path = provider.workflowPath + "/" + skill.id + ".md"
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        } catch {
            print("Failed to delete workflow: \(error)")
        }
    }
}


/// Detailed view for a single skill with 3-column layout
struct SkillDetailView: View {
    @ObservedObject var settings: ProviderSettings
    let provider: Provider? // Context provider
    
    @State private var viewModel: SkillDetailViewModel
    
    init(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: skill, settings: settings))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Column 1: Files Sidebar
            fileSidebar
                .frame(width: 180)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Column 2: Content Preview
            contentPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Column 3: Inspector / Actions
            inspectorPanel
                .frame(width: 220)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .task {
            await viewModel.loadData(checkProviders: settings.providers, currentProvider: provider)
        }
    }
    
    // MARK: - Components
    
    private var fileSidebar: some View {
        VStack(spacing: 0) {
            // New Information Header with "Liquid Glass" feel
            VStack(alignment: .leading, spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text(viewModel.skill.name.prefix(1).uppercased())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .frame(width: 56, height: 56)
                
                // Title info
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.skill.name)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("v" + viewModel.skill.version)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                            )
                        
                        Spacer()
                    }
                }
            }
            .padding(16)
            .padding(.top, 8)
            
            Divider()
            
            // File List
            List(selection: $viewModel.selectedFile) {
                ForEach(viewModel.files) { file in
                    Label {
                        Text(file.name)
                    } icon: {
                        icon(for: file.type)
                    }
                    .tag(file)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var contentPreview: some View {
        Group {
            if let file = viewModel.selectedFile {
                if let content = try? String(contentsOf: file.url) {
                    if file.name == "SKILL.md" && file.type == .markdown {
                        // Structured display for SKILL.md
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Metadata
                                let metadata = SkillParser.parseMetadata(from: content)
                                if !metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Metadata")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                        
                                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                            ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                                GridRow(alignment: .top) {
                                                    Text(key)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 80, alignment: .trailing)
                                                    
                                                    Text(value)
                                                        .font(.caption)
                                                        .monospaced()
                                                        .textSelection(.enabled)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                Divider()
                                
                                // Content
                                let body = SkillParser.stripFrontmatter(from: content)
                                Markdown(body)
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
                    } else {
                        // Standard preview
                        ScrollView {
                            if file.type == .markdown {
                                Markdown(content)
                                    .padding()
                                    .textSelection(.enabled)
                            } else {
                                Text(content)
                                    .font(.monospaced(.body)())
                                    .padding()
                                    .textSelection(.enabled)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Unable to read file", systemImage: "doc.question.mark")
                }
            } else {
                ContentUnavailableView("No file selected", systemImage: "doc")
            }
        }
    }
    
    private var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text(viewModel.skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Providers Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Installations")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(settings.providers) { provider in
                            let isInstalled = viewModel.providerInstallationStates[provider.id] ?? false
                            
                            Button {
                                Task {
                                    await viewModel.toggleInstallation(for: provider)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: provider.iconName)
                                            .font(.title2)
                                        
                                        if isInstalled {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14))
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                    
                                    Text(provider.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isInstalled ? Color.accentColor.opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isInstalled ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            // Highlight if installed
                            .foregroundStyle(isInstalled ? Color.accentColor : Color.secondary)
                            .opacity(isInstalled ? 1.0 : 0.7)
                        }
                    }
                }
                
                // Current Provider Workflow
                if let currentProvider = provider {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workflow")
                            .font(.headline)
                        
                        Text("Associate this skill with a workflow in **\(currentProvider.name)**.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Toggle(isOn: Binding(
                            get: { viewModel.isWorkflowLinked },
                            set: { _ in viewModel.toggleWorkflow(for: currentProvider) }
                        )) {
                            Label("Enable Workflow", systemImage: "arrow.triangle.branch")
                        }
                        .toggleStyle(.switch)
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Finder Button
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.skill.globalPath)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding()
        }
    }
    
    private func icon(for type: SkillFile.SkillFileType) -> Image {
        switch type {
        case .markdown: return Image(systemName: "doc.text")
        case .code: return Image(systemName: "curlybraces")
        case .image: return Image(systemName: "photo")
        case .other: return Image(systemName: "doc")
        }
    }
}
