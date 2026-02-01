import SwiftUI
import Observation
import UniformTypeIdentifiers
import OSLog

@MainActor
@Observable
final class CodexAccountsViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexAccountsViewModel")

    var accounts: [CodexAccountInfo] = []
    var activeAccountId: String?
    var currentAuthSummary: CodexAuthSummary = .init(email: nil, chatgptPlanType: nil, apiKeyLast4: nil)

    var isLoading = false
    var errorMessage: String?

    var showingAddSheet = false
    var accountToDelete: CodexAccountInfo?

    private let codexHomeURL: URL
    private let store: CodexAccountsStore

    init(codexHomeURL: URL, store: CodexAccountsStore = CodexAccountsStore()) {
        self.codexHomeURL = codexHomeURL
        self.store = store
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let state = store.load()
        accounts = state.accounts.sorted { $0.createdAt > $1.createdAt }

        // Current auth summary + active account detection.
        let currentAuthURL = CodexPaths.authJsonURL(codexHomeURL: codexHomeURL)
        if let currentAuth = try? CodexAuthDotJsonReader.readAuth(at: currentAuthURL) {
            currentAuthSummary = CodexAuthDotJsonReader.summarize(currentAuth)
        } else {
            currentAuthSummary = .init(email: nil, chatgptPlanType: nil, apiKeyLast4: nil)
        }

        let currentHash = store.hashOfAuthFile(at: currentAuthURL)
        activeAccountId = accounts.first(where: { store.hashOfAuthFile(at: store.accountAuthURL(accountId: $0.id)) == currentHash })?.id
    }

    func activate(account: CodexAccountInfo) async {
        errorMessage = nil
        do {
            let source = store.accountAuthURL(accountId: account.id)
            let dest = CodexPaths.authJsonURL(codexHomeURL: codexHomeURL)

            let data = try Data(contentsOf: source)
            try FileManager.default.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
            try data.write(to: dest, options: [.atomic])

            var state = store.load()
            state.lastActivatedAccountId = account.id
            store.save(state)
            await reload()
        } catch {
            Self.logger.error("Failed to activate Codex account: \(error.localizedDescription)")
            errorMessage = NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        }
    }

    func delete(account: CodexAccountInfo) async {
        errorMessage = nil
        do {
            var state = store.load()
            state.accounts.removeAll { $0.id == account.id }
            if state.lastActivatedAccountId == account.id {
                state.lastActivatedAccountId = nil
            }
            store.save(state)
            try store.deleteAccountFiles(accountId: account.id)
            await reload()
        } catch {
            Self.logger.error("Failed to delete Codex account: \(error.localizedDescription)")
            errorMessage = NSLocalizedString("codex.accounts.error.delete", value: "Failed to delete this account.", comment: "Error message")
        }
    }

    func addAccount(name: String, source: CodexAddAccountSheet.Source) async {
        errorMessage = nil
        do {
            let authData: Data
            switch source {
            case .currentAuth:
                let authURL = CodexPaths.authJsonURL(codexHomeURL: codexHomeURL)
                authData = try Data(contentsOf: authURL)
            case .file(let url):
                authData = try Data(contentsOf: url)
            }

            // Validate it looks like Codex auth.json.
            _ = try CodexAuthDotJsonReader.decodeAuthData(authData)

            let account = CodexAccountInfo(id: UUID().uuidString, name: name, createdAt: Date())
            try store.writeAccountAuth(accountId: account.id, authData: authData)

            var state = store.load()
            state.accounts.append(account)
            store.save(state)

            await reload()
        } catch {
            Self.logger.error("Failed to add Codex account: \(error.localizedDescription)")
            errorMessage = NSLocalizedString("codex.accounts.error.add", value: "Failed to add this account.", comment: "Error message")
        }
    }
}

struct CodexAccountsView: View {
    let provider: Provider
    @State private var viewModel: CodexAccountsViewModel

    init(provider: Provider) {
        self.provider = provider
        let codexHomeURL = CodexPaths.codexHomeURL(for: provider) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
        self._viewModel = State(initialValue: CodexAccountsViewModel(codexHomeURL: codexHomeURL))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                accountsList
            }
        }
        .navigationTitle(NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingAddSheet = true
                } label: {
                    Label(NSLocalizedString("codex.accounts.action.add", value: "Add Account", comment: "Add account"), systemImage: "plus")
                }
            }
        }
        .task(id: provider.id) {
            await viewModel.reload()
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            CodexAddAccountSheet(
                codexHomeURL: CodexPaths.codexHomeURL(for: provider),
                onAdd: { name, source in
                    Task { await viewModel.addAccount(name: name, source: source) }
                }
            )
            .frame(minWidth: 520, minHeight: 360)
        }
        .alert(item: $viewModel.accountToDelete) { account in
            Alert(
                title: Text(NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title")),
                message: Text(String(format: NSLocalizedString("codex.accounts.delete.message", value: "Delete \"%@\"? This will not log you out of Codex, it only removes the saved snapshot in Nolon.", comment: "Delete account message"), account.name)),
                primaryButton: .destructive(Text(NSLocalizedString("action.delete", comment: "Delete"))) {
                    Task { await viewModel.delete(account: account) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let last4 = viewModel.currentAuthSummary.apiKeyLast4 {
                Text(String(format: NSLocalizedString("codex.accounts.current.api_key", value: "Current: API key ••••%@.", comment: "Current auth summary"), last4))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let email = viewModel.currentAuthSummary.email {
                Text(String(format: NSLocalizedString("codex.accounts.current.email", value: "Current: %@.", comment: "Current auth summary"), email))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(NSLocalizedString("codex.accounts.current.none", value: "Current: No auth.json found.", comment: "Current auth summary"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let plan = viewModel.currentAuthSummary.chatgptPlanType, !plan.isEmpty {
                Text(String(format: NSLocalizedString("codex.accounts.current.plan", value: "Plan: %@.", comment: "Current plan"), plan))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private var accountsList: some View {
        List {
            if viewModel.accounts.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("codex.accounts.empty.title", value: "No accounts", comment: "Empty state title"),
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text(NSLocalizedString("codex.accounts.empty.desc", value: "Add a snapshot of Codex auth.json to quickly switch accounts.", comment: "Empty state description"))
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.accounts) { account in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(account.name)
                                    .font(.body)
                                if viewModel.activeAccountId == account.id {
                                    Text(NSLocalizedString("codex.accounts.badge.active", value: "Active", comment: "Active badge"))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(account.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account")) {
                            Task { await viewModel.activate(account: account) }
                        }
                        .disabled(viewModel.activeAccountId == account.id)
                    }
                    .contextMenu {
                        Button(NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account")) {
                            Task { await viewModel.activate(account: account) }
                        }
                        .disabled(viewModel.activeAccountId == account.id)

                        Divider()

                        Button(role: .destructive) {
                            viewModel.accountToDelete = account
                        } label: {
                            Text(NSLocalizedString("action.delete", comment: "Delete"))
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

struct CodexAddAccountSheet: View {
    enum Source: Sendable, Hashable {
        case currentAuth
        case file(URL)
    }

    let codexHomeURL: URL?
    let onAdd: (String, Source) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var sourceSelection: SourceSelection = .current
    @State private var showingImporter = false
    @State private var selectedFileURL: URL?
    @State private var validationError: String?

    enum SourceSelection: String, CaseIterable, Identifiable {
        case current
        case file

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(NSLocalizedString("codex.accounts.add.name", value: "Account name", comment: "Account name"), text: $name)
                }

                Section {
                    Picker(NSLocalizedString("codex.accounts.add.source", value: "Source", comment: "Account source"), selection: $sourceSelection) {
                        Text(NSLocalizedString("codex.accounts.add.source.current", value: "Current auth.json", comment: "Current auth.json")).tag(SourceSelection.current)
                        Text(NSLocalizedString("codex.accounts.add.source.file", value: "Import auth.json file", comment: "Import file")).tag(SourceSelection.file)
                    }

                    if sourceSelection == .file {
                        HStack {
                            Text(selectedFileURL?.path ?? NSLocalizedString("codex.accounts.add.no_file", value: "No file selected", comment: "No file selected"))
                                .foregroundStyle(selectedFileURL == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button(NSLocalizedString("add_provider.choose", comment: "Choose...")) {
                                showingImporter = true
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if codexHomeURL == nil {
                        Text(NSLocalizedString("codex.accounts.add.no_codex_home", value: "Codex home path could not be resolved from this provider.", comment: "No Codex home"))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }

                if let validationError {
                    Section {
                        Text(validationError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("generic.cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("generic.add", comment: "Add")) { submit() }
                        .disabled(!canSubmit)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFileURL = urls.first
                    validationError = nil
                case .failure(let error):
                    validationError = error.localizedDescription
                }
            }
        }
    }

    private var canSubmit: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch sourceSelection {
        case .current:
            guard let codexHomeURL else { return false }
            return FileManager.default.fileExists(atPath: CodexPaths.authJsonURL(codexHomeURL: codexHomeURL).path)
        case .file:
            return selectedFileURL != nil
        }
    }

    private func submit() {
        validationError = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch sourceSelection {
        case .current:
            guard let codexHomeURL else {
                validationError = NSLocalizedString("codex.accounts.add.error.no_codex_home", value: "Codex home path is unavailable.", comment: "Error")
                return
            }
            onAdd(trimmed, .currentAuth)
            dismiss()
        case .file:
            guard let selectedFileURL else {
                validationError = NSLocalizedString("codex.accounts.add.error.no_file", value: "Select an auth.json file first.", comment: "Error")
                return
            }
            onAdd(trimmed, .file(selectedFileURL))
            dismiss()
        }
    }
}
