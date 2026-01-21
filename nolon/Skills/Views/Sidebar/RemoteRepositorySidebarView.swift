import SwiftUI

/// Left column 1: Repository sidebar with list and add button
struct RemoteRepositorySidebarView: View {
    @Binding var selectedRepository: RemoteRepository?
    @ObservedObject var settings: ProviderSettings

    @State private var showingAddRepository = false
    @State private var selectedTemplate: RepositoryTemplate = .clawdhub
    @State private var newRepoName = ""
    @State private var newRepoURL = ""

    var body: some View {
        List(selection: $selectedRepository) {
            Section {
                ForEach(settings.remoteRepositories) { repo in
                    repositoryRow(repo)
                        .tag(repo)
                }
                .onDelete(perform: deleteRepository)
            } header: {
                Text("Repositories")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            addRepositoryButton
        }
        .navigationTitle("Sources")
        .sheet(isPresented: $showingAddRepository) {
            addRepositorySheet
        }
        .onAppear {
            if selectedRepository == nil {
                selectedRepository = settings.remoteRepositories.first
            }
        }
    }

    private func repositoryRow(_ repo: RemoteRepository) -> some View {
        HStack {
            Label(repo.name, systemImage: repo.iconName)
            Spacer()
            if repo.isBuiltIn {
                Text("Built-in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .contextMenu {
            if !repo.isBuiltIn {
                Button(role: .destructive) {
                    settings.removeRemoteRepository(repo)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var addRepositoryButton: some View {
        Button {
            resetAddForm()
            showingAddRepository = true
        } label: {
            Label("Add Repository", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var addRepositorySheet: some View {
        NavigationStack {
            Form {
                // Template Selection
                Section {
                    Picker("Type", selection: $selectedTemplate) {
                        ForEach(RepositoryTemplate.allCases) { template in
                            Label(template.displayName, systemImage: template.iconName)
                                .tag(template)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Repository Type")
                }

                // Repository Details
                Section {
                    TextField("Repository Name", text: $newRepoName)
                        .disabled(selectedTemplate == .clawdhub)

                    if selectedTemplate.isURLEditable {
                        TextField("Base URL", text: $newRepoURL)
                            .textContentType(.URL)
                    } else {
                        HStack {
                            Text("Base URL")
                            Spacer()
                            Text(selectedTemplate.defaultBaseURL)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Details")
                } footer: {
                    if selectedTemplate == .clawdhub {
                        Text("Clawdhub is the official skill marketplace.")
                    } else {
                        Text("Enter the base URL of the skill repository API.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Repository")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddRepository = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRepository()
                    }
                    .disabled(!canAddRepository)
                }
            }
            .onChange(of: selectedTemplate) { _, newTemplate in
                // Pre-fill values when template changes
                newRepoName = newTemplate.defaultName
                newRepoURL = newTemplate.defaultBaseURL
            }
        }
        .frame(width: 400, height: 320)
    }

    private var canAddRepository: Bool {
        switch selectedTemplate {
        case .clawdhub:
            // Check if Clawdhub already exists
            return !settings.remoteRepositories.contains { $0.templateType == .clawdhub }
        case .custom:
            return !newRepoName.isEmpty && !newRepoURL.isEmpty
        }
    }

    private func addRepository() {
        let repo = selectedTemplate.createRepository(
            name: selectedTemplate == .custom ? newRepoName : nil,
            baseURL: selectedTemplate == .custom ? newRepoURL : nil
        )
        settings.addRemoteRepository(repo)
        showingAddRepository = false
    }

    private func resetAddForm() {
        // Choose default template based on whether Clawdhub already exists
        if settings.remoteRepositories.contains(where: { $0.templateType == .clawdhub }) {
            selectedTemplate = .custom
        } else {
            selectedTemplate = .clawdhub
        }
        newRepoName = selectedTemplate.defaultName
        newRepoURL = selectedTemplate.defaultBaseURL
    }

    private func deleteRepository(at offsets: IndexSet) {
        for index in offsets {
            let repo = settings.remoteRepositories[index]
            if !repo.isBuiltIn {
                settings.removeRemoteRepository(repo)
            }
        }
    }
}
