import SwiftUI
import Observation


struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    @State private var viewModel: AddRepositoryViewModel

    init(isPresented: Binding<Bool>, settings: ProviderSettings, repositoryToEdit: RemoteRepository? = nil, onDirectoryCandidatesFound: @escaping (RemoteRepository, [GitRepositoryService.SkillsDirectoryCandidate]) -> Void) {
        self._isPresented = isPresented
        
        let vm = AddRepositoryViewModel(settings: settings, repositoryToEdit: repositoryToEdit)
        vm.onDirectoryCandidatesFound = onDirectoryCandidatesFound
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            templateSection
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                formContent
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            footerView
        }
        .frame(width: 500, height: 480)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
        .overlay {
            if viewModel.isAddingRepository {
                loadingOverlay
            }
        }
        .onAppear {
            viewModel.onDismiss = {
                isPresented = false
            }
        }
    }

    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text(viewModel.isEditing ? "Edit Repository" : "Add Repository")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isAddingRepository)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            if let error = viewModel.validationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .disabled(viewModel.isAddingRepository)
                
                Button(viewModel.isEditing ? "Save" : "Add") {
                    Task { await viewModel.saveRepository() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(viewModel.canAddRepository ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(viewModel.canAddRepository ? .white : .secondary)
                .cornerRadius(16)
                .disabled(!viewModel.canAddRepository || viewModel.isAddingRepository)
            }
        }
        .padding(20)
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Name Section
            nameSection
            
            // Type-Specific Section
            typeSpecificSection
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repository Type")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                ForEach(viewModel.availableTemplates) { template in
                    templateButton(for: template)
                }
            }
        }
    }
    
    private func templateButton(for template: RepositoryTemplate) -> some View {
        let isSelected = viewModel.selectedTemplate == template
        
        return Button {
            if !viewModel.isEditing {
                viewModel.selectedTemplate = template
            }
        } label: {
            HStack(spacing: 8) {
                if let logoName = template.logoName {
                    ProviderLogoView(name: template.displayName, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: template.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                
                Text(template.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isEditing)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Group {
            if viewModel.selectedTemplate != .git && viewModel.selectedTemplate != .localFolder {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Name")
                        .font(.system(size: 13, weight: .semibold))
                    
                    nameContent
                }
            }
        }
    }

    @ViewBuilder
    private var nameContent: some View {
        switch viewModel.selectedTemplate {
        case .localFolder:
            textInputField(placeholder: "Repository Name", text: $viewModel.newRepoName)
        case .git, .globalSkills:
            readOnlyField(value: viewModel.newRepoName.isEmpty ? "Auto-detected from URL" : viewModel.newRepoName)
        }
    }

    // MARK: - Type-Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch viewModel.selectedTemplate {
        case .localFolder:
            localFolderSection
        case .git:
            gitSection
        case .globalSkills:
            EmptyView()
        }
    }


    private var localFolderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills Folder")
                .font(.system(size: 13, weight: .semibold))
            
            HStack(spacing: 12) {
                HStack {
                    Text(viewModel.newLocalPath.isEmpty ? "No folder selected" : viewModel.newLocalPath)
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.newLocalPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Button {
                    viewModel.selectLocalFolder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Choose...")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Text("Select a folder containing skill directories (each with a SKILL.md file).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
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
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                Text("Supports GitHub, GitLab, Bitbucket and other Git hosting services.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
    }

    // MARK: - Skills Paths Section

    @ViewBuilder
    private var skillsPathsSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.newSkillsPaths.enumerated()), id: \.offset) { index, path in
                HStack {
                    Text(path)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button {
                        viewModel.removeSkillsPath(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
            
            HStack(spacing: 8) {
                HStack {
                    TextField("Path (e.g., skills, .agent)", text: $viewModel.newSkillsPathInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Button {
                    viewModel.addSkillsPath()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newSkillsPathInput.isEmpty)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func textInputField(placeholder: String, text: Binding<String>) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func readOnlyField(value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .cornerRadius(24)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Adding repository...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}


#Preview {
    AddRepositorySheet(
        isPresented: .constant(true),
        settings: .preview,
        onDirectoryCandidatesFound: { _, _ in }
    )
}
