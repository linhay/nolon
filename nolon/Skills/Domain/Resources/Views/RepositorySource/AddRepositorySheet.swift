import SwiftUI
import UniformTypeIdentifiers
import NolonResourceKit

struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    @State private var viewModel: AddRepositoryViewModel
    @State private var isLocalFolderDropTargeted = false

    init(
        isPresented: Binding<Bool>,
        settings: ProviderSettings,
        repositoryToEdit: RemoteRepository? = nil,
        onDirectoryCandidatesFound: @escaping (RemoteRepository, [GitRepository.SkillsDirectoryCandidate]) -> Void,
        onRepositorySaved: ((RemoteRepository) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        
        let vm = AddRepositoryViewModel(settings: settings, repositoryToEdit: repositoryToEdit)
        vm.onDirectoryCandidatesFound = onDirectoryCandidatesFound
        vm.onRepositorySaved = onRepositorySaved
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                formContent
                    .padding(.horizontal, SheetLayout.horizontalPadding)
                    .padding(.top, SheetLayout.contentVerticalPadding)
                    .padding(.bottom, SheetLayout.contentBottomPadding)
            }
            
            SheetDivider()
            
            footerView
        }
        .frame(width: 640, height: 600)
        .textSelection(.enabled)
        .dsGlassPanel()
        .overlay {
            if viewModel.isAddingRepository {
                loadingOverlay
            }
        }
        .onAppear {
            viewModel.onDismiss = {
                isPresented = false
            }
            // Check for pending URL on appear (handles @State caching issue)
            viewModel.checkPendingImportURL()
        }
    }

    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            if let error = viewModel.validationError {
                Text(error)
                    .dsErrorText(font: .system(size: 12))
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .dsLinkButton()
                .font(.system(size: 13, weight: .medium))
                .dsBadge(
                    foreground: DesignSystem.Colors.Text.primary,
                    background: DesignSystem.Colors.Component.controlFill,
                    horizontalPadding: 16,
                    verticalPadding: 8
                )
                .disabled(viewModel.isAddingRepository)
                
                Button(viewModel.isEditing ? "Save" : "Add") {
                    Task { await viewModel.saveRepository() }
                }
                .dsLinkButton()
                .font(.system(size: 13, weight: .bold))
                .dsBadge(
                    foreground: viewModel.canAddRepository ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.tertiary,
                    background: viewModel.canAddRepository ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.disabledFill,
                    horizontalPadding: 24,
                    verticalPadding: 8
                )
                .disabled(!viewModel.canAddRepository || viewModel.isAddingRepository)
            }
        }
        .padding(.horizontal, SheetLayout.footerHorizontalPadding)
        .padding(.vertical, SheetLayout.footerVerticalPadding)
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Repository Type Section
            templateSection

            // Type-Specific Section
            typeSpecificSection
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repository Type")
                .font(.system(size: 13, weight: .semibold))
            
            HStack(spacing: 10) {
                ForEach(viewModel.availableTemplates) { template in
                    templateButton(for: template)
                }
            }
        }
    }
    
    private func templateButton(for template: RepositoryTemplate) -> some View {
        GenericSelectionControl(
            value: template,
            selection: $viewModel.selectedTemplate,
            disabled: viewModel.isEditing
        ) { isSelected in
            HStack(spacing: 8) {
                if let logoName = template.logoName {
                    ProviderLogoView(name: template.displayName, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: template.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.secondary)
                }
                
                Text(template.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .dsBadgeBorder(
                foreground: isSelected ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.primary,
                background: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.controlFill,
                borderColor: isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.25),
                borderWidth: 1,
                horizontalPadding: 12,
                    verticalPadding: 5
                )
        }
        .dsLinkButton()
    }

    // MARK: - Type-Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch viewModel.selectedTemplate {
        case .clawdhub:
            clawdhubSection
        case .localFolder:
            localFolderSection
        case .git:
            gitSection
        case .globalSkills:
            EmptyView()
        }
    }

    private var clawdhubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 13, weight: .semibold))
            
            readOnlyField(value: viewModel.selectedTemplate.defaultBaseURL)
            
            Text("Clawdhub is the official skill marketplace.")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
        }
    }

    private var localFolderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills Folder")
                .font(.system(size: 13, weight: .semibold))

            Button {
                viewModel.selectLocalFolder()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    Text(viewModel.newLocalPath.isEmpty ? "拖拽本地 skills 文件夹到这里" : viewModel.newLocalPath)
                        .font(.system(size: 13))
                        .foregroundStyle(
                            viewModel.newLocalPath.isEmpty
                                ? DesignSystem.Colors.Text.secondary
                                : DesignSystem.Colors.Text.primary
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .truncationMode(.middle)
                    Text("或点击选择文件夹")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 136)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isLocalFolderDropTargeted
                                ? DesignSystem.Colors.primary.opacity(0.16)
                                : DesignSystem.Colors.Component.controlFillSubtle.opacity(0.92)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isLocalFolderDropTargeted
                                ? DesignSystem.Colors.primary
                                : DesignSystem.Colors.Text.primary.opacity(0.45),
                            style: StrokeStyle(lineWidth: isLocalFolderDropTargeted ? 3 : 2)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .inset(by: 4)
                        .strokeBorder(
                            isLocalFolderDropTargeted
                                ? DesignSystem.Colors.primary.opacity(0.95)
                                : DesignSystem.Colors.Text.secondary.opacity(0.95),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                        )
                )
                .shadow(
                    color: isLocalFolderDropTargeted
                        ? DesignSystem.Colors.primary.opacity(0.45)
                        : DesignSystem.Colors.Text.secondary.opacity(0.2),
                    radius: isLocalFolderDropTargeted ? 10 : 4
                )
            }
            .buttonStyle(.plain)
            .dropDestination(for: URL.self) { items, _ in
                viewModel.applyDroppedFolderURLs(items)
            } isTargeted: { targeted in
                isLocalFolderDropTargeted = targeted
            }
            
            Text("Select a folder containing skill directories (each with a SKILL.md file).")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
        }
    }

    private var gitSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Git URL
            VStack(alignment: .leading, spacing: 12) {
                Text("Git Repository")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack(spacing: 12) {
                    HStack {
                        TextField("https://github.com/...", text: $viewModel.newGitURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .textContentType(.URL)
                        
                        if !viewModel.newGitURL.isEmpty {
                            let provider = RemoteRepository.detectProvider(from: viewModel.newGitURL) ?? .github
                            if let logoName = provider.logoName {
                                ProviderLogoView(name: provider.displayName, logoName: logoName, iconSize: 18)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .dsField(cornerRadius: DesignSystem.Metrics.cornerRadiusM)

                    Button {
                        _ = viewModel.applyGitURL(NSPasteboard.general.string(forType: .string))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .dsBadgeBorder(
                            foreground: DesignSystem.Colors.Text.primary,
                            background: DesignSystem.Colors.Component.controlFill,
                            borderColor: DesignSystem.Colors.Component.border.opacity(0.25),
                            borderWidth: 1,
                            horizontalPadding: 12,
                            verticalPadding: 8
                        )
                    }
                    .dsLinkButton()
                }
                
                Text("Supports GitHub, GitLab, Bitbucket and other Git hosting services.")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
            }

            Text("Sync 后将自动扫描仓库中的技能目录，下一步可多选确认。")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.Text.secondary.opacity(0.8))
        }
    }
    
    // MARK: - Helper Views
    
    private func readOnlyField(value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 13))
                .dsSecondaryText(font: .system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Component.controlFillSubtle,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.20)
        )
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            DesignSystem.Colors.Overlay.scrim
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusXL, style: .continuous))
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Adding repository...")
                    .font(.system(size: 14, weight: .medium))
                    .dsSecondaryText(font: .system(size: 14, weight: .medium))
            }
            .padding(32)
            .dsGlassPanel(cornerRadius: DesignSystem.Metrics.cornerRadiusL)
        }
    }
}
