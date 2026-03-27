import SwiftUI
import NolonUIFoundation

public struct ResourceDeleteTargetSheetView: View {
    let data: ResourceDeleteTargetSheetData
    let onConfirm: (_ deleteAll: Bool, _ providerID: String?) -> Void
    let onClose: () -> Void

    @State private var selectedProviderID: String?
    @State private var deleteAll = false
    @State private var showingConfirmDeleteAll = false

    public init(
        data: ResourceDeleteTargetSheetData,
        onConfirm: @escaping (_ deleteAll: Bool, _ providerID: String?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.data = data
        self.onConfirm = onConfirm
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            NolonUI.SheetHeaderView(
                title: NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"),
                subtitle: "\(data.resourceTypeName): \(data.resourceName)"
            ) {
                onClose()
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
                        ForEach(data.providers) { provider in
                            Button {
                                selectedProviderID = provider.id
                            } label: {
                                HStack(spacing: 10) {
                                    if let iconName = provider.iconName, !iconName.isEmpty {
                                        Image(iconName)
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
                    onClose()
                }
                .dsLinkButton()
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)

                Button(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), role: .destructive) {
                    if deleteAll {
                        showingConfirmDeleteAll = true
                    } else if let selectedProviderID {
                        onConfirm(false, selectedProviderID)
                        onClose()
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
            selectedProviderID = data.preferredProviderID ?? data.providers.first?.id
            deleteAll = selectedProviderID == nil
        }
        .onChange(of: deleteAll) { _, isDeletingAll in
            guard !isDeletingAll, selectedProviderID == nil else { return }
            selectedProviderID = data.preferredProviderID ?? data.providers.first?.id
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
                onConfirm(true, nil)
                onClose()
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
}
