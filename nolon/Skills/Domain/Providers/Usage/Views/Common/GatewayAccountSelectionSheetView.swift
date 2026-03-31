import SwiftUI
import NolonUI
import NolonUIFoundation

struct GatewayAccountSelectionSheetView: View, DebugPageLocatable {
    let title: String
    let listSections: [NolonUI.AccountListModeSection]
    @Binding var selections: Set<IDBox<UUID>>
    let cancelTitle: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let debugPageMarkerItems: [PageMarkerItem]

    private var selectedCountText: String {
        String(
            format: NSLocalizedString(
                "codex.accounts.selection.count",
                value: "已选 %d",
                comment: "Selected Codex account count"
            ),
            selections.count
        )
    }

    private var displayedListSections: [NolonUI.AccountListModeSection] {
        listSections.map { section in
            NolonUI.AccountListModeSection(
                id: section.id,
                title: section.title,
                items: section.items.map { item in
                    guard let itemUUID = UUID(uuidString: item.id) else { return item }
                    let isSelected = selections.contains(IDBox(itemUUID))
                    return NolonUI.AccountListModeItem(
                        id: item.id,
                        presentation: isSelected ? .selected : .neutral,
                        header: item.header,
                        usageWindows: item.usageWindows,
                        menuActions: item.menuActions,
                        isLoadingPlaceholder: item.isLoadingPlaceholder
                    )
                }
            )
        }
    }

    private func toggleSelection(for itemID: String) {
        guard let uuid = UUID(uuidString: itemID) else { return }
        let boxed = IDBox(uuid)
        if selections.contains(boxed) {
            selections.remove(boxed)
        } else {
            selections.insert(boxed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView

            NolonUI.ProviderEmptyStateScaffold(
                isEmpty: displayedListSections.flatMap(\.items).isEmpty,
                preset: .gatewayPickerEmpty
            ) {
                NolonUI.AccountListModeModule(
                    sections: displayedListSections,
                    accountColumnTitle: NSLocalizedString(
                        "codex.accounts.list.header.account",
                        value: "Account",
                        comment: "Codex account list table account column"
                    ),
                    planColumnTitle: "",
                    usageColumnTitle: NSLocalizedString(
                        "codex.accounts.list.header.usage",
                        value: "Usage",
                        comment: "Codex account list table usage column"
                    ),
                    planColumnWidth: 0,
                    usageColumnWidth: 232,
                    onTap: toggleSelection(for:)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NolonUI.DesignSystem.Colors.Component.border.opacity(0.5), lineWidth: 1)
            )

            Divider()
            HStack {
                Button(cancelTitle) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button(confirmTitle) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selections.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 620, height: 560)
        .debugCardLocator(debugPageMarkerItems)
    }

    private var headerView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NolonUI.DesignSystem.Colors.primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(NolonUI.DesignSystem.Colors.primary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(selectedCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NolonUI.DesignSystem.Colors.Text.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NolonUI.DesignSystem.Colors.Background.canvas)
                    )
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("Gateway Picker - Normal") {
    GatewayAccountSelectionSheetPreviewHost(
        title: "为主网关卡片选择账号",
        listSections: [
            .init(
                id: "openai",
                title: "OpenAI Official",
                items: [
                    .init(
                        id: "00000000-0000-0000-0000-000000000001",
                        presentation: .neutral,
                        header: .init(eyebrow: nil, title: "team-alpha@example.com", subtitle: "Plus", meta: "OpenAI", badge: nil),
                        usageWindows: [
                            .init(id: "session", title: "Session", progress: 0.76, percentText: "76%"),
                            .init(id: "weekly", title: "Weekly", progress: 0.64, percentText: "64%")
                        ]
                    ),
                    .init(
                        id: "00000000-0000-0000-0000-000000000002",
                        presentation: .neutral,
                        header: .init(eyebrow: nil, title: "team-beta@example.com", subtitle: "Pro", meta: "OpenAI", badge: nil),
                        usageWindows: [
                            .init(id: "session", title: "Session", progress: 0.42, percentText: "42%"),
                            .init(id: "weekly", title: "Weekly", progress: 0.58, percentText: "58%")
                        ]
                    )
                ]
            ),
            .init(
                id: "relay",
                title: "Relay",
                items: [
                    .init(
                        id: "00000000-0000-0000-0000-000000000003",
                        presentation: .neutral,
                        header: .init(eyebrow: nil, title: "relay-us-01", subtitle: "Relay", meta: "https://relay.example.com", badge: nil),
                        usageWindows: [
                            .init(id: "session", title: "Session", progress: 0.88, percentText: "88%")
                        ]
                    )
                ]
            )
        ],
        initialSelectionIDs: []
    )
    .frame(width: 660, height: 620)
    .padding()
}

#Preview("Gateway Picker - Multi Selected") {
    GatewayAccountSelectionSheetPreviewHost(
        title: "为高可用网关选择账号",
        listSections: [
            .init(
                id: "premium",
                title: "Premium",
                items: [
                    .init(
                        id: "00000000-0000-0000-0000-000000000011",
                        presentation: .neutral,
                        header: .init(eyebrow: nil, title: "ops-primary@example.com", subtitle: "Pro", meta: nil, badge: nil),
                        usageWindows: [.init(id: "session", title: "Session", progress: 0.91, percentText: "91%")]
                    ),
                    .init(
                        id: "00000000-0000-0000-0000-000000000012",
                        presentation: .neutral,
                        header: .init(eyebrow: nil, title: "ops-backup@example.com", subtitle: "Pro", meta: nil, badge: nil),
                        usageWindows: [.init(id: "session", title: "Session", progress: 0.73, percentText: "73%")]
                    ),
                    .init(
                        id: "00000000-0000-0000-0000-000000000013",
                        presentation: .neutral,
                        header: .init(eyebrow: nil, title: "ops-dr@example.com", subtitle: "Plus", meta: nil, badge: nil),
                        usageWindows: [.init(id: "session", title: "Session", progress: 0.35, percentText: "35%")]
                    )
                ]
            )
        ],
        initialSelectionIDs: [
            UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        ]
    )
    .frame(width: 660, height: 620)
    .padding()
}

#Preview("Gateway Picker - Empty") {
    GatewayAccountSelectionSheetPreviewHost(
        title: "为空网关选择账号",
        listSections: [],
        initialSelectionIDs: []
    )
    .frame(width: 660, height: 620)
    .padding()
}

private struct GatewayAccountSelectionSheetPreviewHost: View {
    let title: String
    let listSections: [NolonUI.AccountListModeSection]
    let initialSelectionIDs: [UUID]

    @State private var selections: Set<IDBox<UUID>>

    init(
        title: String,
        listSections: [NolonUI.AccountListModeSection],
        initialSelectionIDs: [UUID]
    ) {
        self.title = title
        self.listSections = listSections
        self.initialSelectionIDs = initialSelectionIDs
        _selections = State(
            initialValue: Set(initialSelectionIDs.map { IDBox($0) })
        )
    }

    var body: some View {
        GatewayAccountSelectionSheetView(
            title: title,
            listSections: listSections,
            selections: $selections,
            cancelTitle: "取消",
            confirmTitle: "加入网关",
            onCancel: {},
            onConfirm: {},
            debugPageMarkerItems: []
        )
    }
}
