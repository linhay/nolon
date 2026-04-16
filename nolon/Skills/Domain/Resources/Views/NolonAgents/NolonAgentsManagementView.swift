import SwiftUI
import NolonUI
import NolonUIFoundation

@MainActor
@Observable
final class NolonAgentsManagementViewModel {
    var profiles: [NolonAgentsProfile] = []
    var searchText = ""
    var errorMessage: String?

    private let service: NolonAgentsProfilesService

    init(service: NolonAgentsProfilesService) {
        self.service = service
    }

    init() {
        self.service = NolonAgentsProfilesService()
    }

    var filteredProfiles: [NolonAgentsProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return profiles }
        return profiles.filter {
            $0.fileName.localizedCaseInsensitiveContains(query)
            || $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredAgentDocs: [AgentDocInfo] {
        filteredProfiles.map { profile in
            AgentDocInfo(
                id: profile.id,
                fileName: profile.fileName,
                path: profile.path,
                preview: profile.preview,
                kind: profile.isPrimary ? .base : .override
            )
        }
    }

    func load() {
        do {
            profiles = try service.listProfiles()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProfile() {
        do {
            _ = try service.createProfile()
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activate(_ profile: NolonAgentsProfile) {
        do {
            try service.activateProfile(at: profile.path)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ profile: NolonAgentsProfile) {
        do {
            try service.deleteProfile(at: profile.path)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ profile: NolonAgentsProfile) {
        NSWorkspace.shared.selectFile(profile.path, inFileViewerRootedAtPath: "")
    }

    func openInEditor(_ profile: NolonAgentsProfile) {
        NSWorkspace.shared.open(URL(fileURLWithPath: profile.path))
    }
}

struct NolonAgentsManagementView: View {
    @State private var viewModel = NolonAgentsManagementViewModel()
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 300), alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField(
                    NSLocalizedString("detail.search_placeholder", value: "Search", comment: "Search placeholder"),
                    text: $viewModel.searchText
                )
                .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.createProfile()
                } label: {
                    Label(
                        NSLocalizedString("action.new", value: "New", comment: "New action"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            NolonUI.ProviderTabSectionView(warningMessage: viewModel.errorMessage) {
                NolonUI.ProviderResourceGridSectionView(
                    isEmpty: viewModel.filteredAgentDocs.isEmpty,
                    searchText: viewModel.searchText,
                    kind: .agents,
                    noResultsDescription: NSLocalizedString(
                        "remote.search.no_results_desc",
                        value: "No matching workflows found",
                        comment: "No search results description"
                    ),
                    columns: columns
                ) {
                    ForEach(viewModel.filteredProfiles) { profile in
                        NolonUI.AgentDocCardView(
                            doc: AgentDocInfo(
                                id: profile.id,
                                fileName: profile.fileName,
                                path: profile.path,
                                preview: profile.preview,
                                kind: profile.isPrimary ? .base : .override
                            ),
                            searchText: viewModel.searchText,
                            onReveal: { viewModel.revealInFinder(profile) },
                            onDelete: { viewModel.delete(profile) },
                            onTap: { viewModel.openInEditor(profile) }
                        ) { _ in
                            if !profile.isActive {
                                Button("Use") {
                                    viewModel.activate(profile)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            viewModel.load()
        }
    }
}
