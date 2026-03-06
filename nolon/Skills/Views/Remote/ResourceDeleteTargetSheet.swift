import SwiftUI
import ProviderCatalog
import NolonResourceKit
import OSLog

struct ResourceDeleteTargetSheet: View {
    private static let logger = Logger(subsystem: "com.nolon", category: "ResourceDeleteTargetSheet")
    let resourceName: String
    let resourceType: RemoteContentType
    let providers: [Provider]
    let preferredProvider: Provider?
    let onConfirm: (ResourceDeleteTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProviderID: Provider.ID?
    @State private var deleteAll = false
    @State private var showingConfirmDeleteAll = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"),
                subtitle: "\(resourceTypeName): \(resourceName)"
            ) {
                dismiss()
            }

            SheetDivider()

            List {
                Section {
                    Toggle(isOn: $deleteAll) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                NSLocalizedString(
                                    "resource.delete.target.all",
                                    value: "All providers + global cache",
                                    comment: "Delete all target"
                                )
                            )
                            .font(.body.weight(.semibold))

                            Text(
                                NSLocalizedString(
                                    "resource.delete.target.all.desc",
                                    value: "Remove from every provider and delete global cache files.",
                                    comment: "Delete all target description"
                                )
                            )
                            .dsSecondaryText(font: .caption)
                        }
                    }
                }

                if !deleteAll {
                    Section(
                        NSLocalizedString(
                            "resource.delete.target.provider",
                            value: "Provider",
                            comment: "Delete provider selection title"
                        )
                    ) {
                        ForEach(providers) { provider in
                            Button {
                                selectedProviderID = provider.id
                            } label: {
                                HStack(spacing: 10) {
                                    if !provider.iconName.isEmpty {
                                        Image(provider.iconName)
                                            .resizable()
                                            .frame(width: 18, height: 18)
                                    } else {
                                        Image(systemName: "folder")
                                            .frame(width: 18, height: 18)
                                    }
                                    Text(provider.name)
                                    Spacer()
                                    if selectedProviderID == provider.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(DesignSystem.Colors.primary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .sheetScrollContentPadding()

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    dismiss()
                }
                .dsLinkButton()
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)

                Button(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), role: .destructive) {
                    if deleteAll {
                        Self.logger.info("Delete sheet primary action routed to delete-all confirmation. providers=\(self.providers.count, privacy: .public)")
                        showingConfirmDeleteAll = true
                    } else if let providerID = selectedProviderID {
                        Self.logger.info("Delete sheet primary action routed to single-provider delete. hasProviderSelection=\(providerID.isEmpty == false, privacy: .public)")
                        onConfirm(.provider(providerID))
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!deleteAll && selectedProviderID == nil)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 460, height: 540)
        .onAppear {
            let initialState = ResourceDeleteTargetSheetState.initial(
                preferredProvider: preferredProvider,
                providers: providers
            )
            selectedProviderID = initialState.selectedProviderID
            deleteAll = initialState.deleteAll
            Self.logger.info(
                "Delete sheet appeared. providers=\(self.providers.count, privacy: .public) hasPreferredProvider=\(self.preferredProvider != nil, privacy: .public) deleteAll=\(initialState.deleteAll, privacy: .public) hasSelectedProvider=\(initialState.selectedProviderID != nil, privacy: .public)"
            )
        }
        .onChange(of: deleteAll) { _, isDeletingAll in
            guard !isDeletingAll, selectedProviderID == nil else { return }
            selectedProviderID = ResourceDeleteTargetSheetState.providerSelection(
                preferredProvider: preferredProvider,
                providers: providers
            )
        }
        .confirmationDialog(
            NSLocalizedString(
                "resource.delete.confirm.title",
                value: "Delete from all providers?",
                comment: "Delete all confirmation title"
            ),
            isPresented: $showingConfirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), role: .destructive) {
                Self.logger.info("Delete sheet confirmed delete-all path.")
                onConfirm(.allProvidersAndGlobalCache)
                dismiss()
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "resource.delete.confirm.message",
                    value: "This will remove the resource from all providers and delete global cache files.",
                    comment: "Delete all confirmation message"
                )
            )
        }
    }

    private var resourceTypeName: String {
        switch resourceType {
        case .skill:
            return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflow:
            return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .mcp:
            return NSLocalizedString("tab.mcps", comment: "MCPs")
        }
    }
}
